# NestJS Microservices — Full Patterns

Source rules: `micro-use-patterns`, `micro-use-queues`, `micro-use-health-checks`.

## Message and Event Patterns

**Incorrect:**

```typescript
@Controller()
export class NotificationsController {
  @MessagePattern('user.created')
  async handleUserCreated(data: UserCreatedEvent) {
    await this.emailService.sendWelcome(data.email); // WAITS for response, blocks sender — if email fails, sender gets an error (coupling!)
  }
}

@Controller()
export class OrdersController {
  @EventPattern('inventory.check')
  async checkInventory(data: CheckInventoryDto) {
    const available = await this.inventory.check(data);
    return available; // IGNORED with @EventPattern!
  }
}

@Injectable()
export class UsersService {
  async createUser(dto: CreateUserDto): Promise<User> {
    const user = await this.repo.save(dto);
    await this.client.send('user.created', user).toPromise(); // blocks; if notification service is down, user creation fails!
    return user;
  }
}
```

**Correct:**

```typescript
// MessagePattern: request-response, use when caller NEEDS the result
@Controller()
export class InventoryController {
  @MessagePattern({ cmd: 'check_inventory' })
  async checkInventory(data: CheckInventoryDto): Promise<InventoryResult> {
    return this.inventoryService.check(data.productId, data.quantity);
  }
}

@Injectable()
export class OrdersService {
  async createOrder(dto: CreateOrderDto): Promise<Order> {
    const inventory = await firstValueFrom(
      this.inventoryClient.send<InventoryResult>({ cmd: 'check_inventory' }, { productId: dto.productId, quantity: dto.quantity }),
    );
    if (!inventory.available) throw new BadRequestException('Insufficient inventory');
    return this.repo.save(dto);
  }
}

// EventPattern: fire-and-forget, for notifications/side effects
@Controller()
export class NotificationsController {
  @EventPattern('user.created')
  async handleUserCreated(data: UserCreatedEvent): Promise<void> {
    await this.emailService.sendWelcome(data.email);
    await this.analyticsService.track('user_signup', data);
    // failure here does not affect the sender
  }
}

@Injectable()
export class UsersService {
  async createUser(dto: CreateUserDto): Promise<User> {
    const user = await this.repo.save(dto);
    this.eventClient.emit('user.created', { userId: user.id, email: user.email, timestamp: new Date() }); // doesn't block, doesn't wait
    return user;
  }
}

// Hybrid: critical path via MessagePattern, side effect via EventPattern
@Injectable()
export class OrdersService {
  async createOrder(dto: CreateOrderDto): Promise<Order> {
    const order = await this.repo.save(dto);

    const reserved = await firstValueFrom(this.inventoryClient.send({ cmd: 'reserve_inventory' }, { orderId: order.id, items: dto.items }));
    if (!reserved.success) {
      await this.repo.delete(order.id);
      throw new BadRequestException('Could not reserve inventory');
    }

    this.eventClient.emit('order.created', { orderId: order.id, userId: dto.userId, total: dto.total }); // non-critical
    return order;
  }
}

// Error handling: MessagePattern errors propagate; EventPattern errors handled locally
@MessagePattern({ cmd: 'get_user' })
async getUser(userId: string): Promise<User> {
  const user = await this.repo.findOne({ where: { id: userId } });
  if (!user) throw new RpcException('User not found'); // received by caller
  return user;
}

@EventPattern('order.created')
async handleOrderCreated(data: OrderCreatedEvent): Promise<void> {
  try {
    await this.processOrder(data);
  } catch (error) {
    this.logger.error('Failed to process order event', error); // never rethrow — nothing is listening
    await this.deadLetterQueue.add(data);
  }
}
```

## Message Queues for Background Jobs

**Incorrect:**

```typescript
@Controller('reports')
export class ReportsController {
  @Post()
  async generate(@Body() dto: GenerateReportDto): Promise<Report> {
    const data = await this.fetchLargeDataset(dto);   // blocks request for potentially minutes
    const report = await this.processData(data);
    await this.sendEmail(dto.email, report);            // can fail
    return report;                                       // client times out
  }
}

@Injectable()
export class EmailService {
  async sendWelcome(email: string): Promise<void> {
    await this.mailer.send({ to: email, template: 'welcome' }); // no retry, no tracking, no visibility if it fails
  }
}

setInterval(async () => { await cleanupOldRecords(); }, 60000); // no error handling, memory leaks
```

**Correct:**

```typescript
import { BullModule } from '@nestjs/bullmq';

@Module({
  imports: [
    BullModule.forRoot({
      connection: { host: 'localhost', port: 6379 },
      defaultJobOptions: {
        removeOnComplete: 1000,
        removeOnFail: 5000,
        attempts: 3,
        backoff: { type: 'exponential', delay: 1000 },
      },
    }),
    BullModule.registerQueue({ name: 'email' }, { name: 'reports' }, { name: 'notifications' }),
  ],
})
export class QueueModule {}

// Producer — returns immediately, work happens in background
@Injectable()
export class ReportsService {
  constructor(@InjectQueue('reports') private reportsQueue: Queue) {}

  async requestReport(dto: GenerateReportDto): Promise<{ jobId: string }> {
    const job = await this.reportsQueue.add('generate', dto, {
      priority: dto.urgent ? 1 : 10,
      delay: dto.scheduledFor ? Date.parse(dto.scheduledFor) - Date.now() : 0,
    });
    return { jobId: job.id };
  }

  async getJobStatus(jobId: string): Promise<JobStatus> {
    const job = await this.reportsQueue.getJob(jobId);
    return { status: await job.getState(), progress: job.progress, result: job.returnvalue };
  }
}

// Consumer — reports progress for client polling
@Processor('reports')
export class ReportsProcessor {
  private readonly logger = new Logger(ReportsProcessor.name);

  @Process('generate')
  async generateReport(job: Job<GenerateReportDto>): Promise<Report> {
    await job.updateProgress(10);
    const data = await this.fetchData(job.data);
    await job.updateProgress(50);
    const report = await this.processData(data);
    await job.updateProgress(90);
    await this.saveReport(report);
    await job.updateProgress(100);
    return report;
  }

  @OnQueueFailed()
  onFailed(job: Job, error: Error) {
    this.logger.error(`Job ${job.id} failed: ${error.message}`);
  }
}

// Retry configured per job
@Injectable()
export class NotificationService {
  constructor(@InjectQueue('email') private emailQueue: Queue) {}

  async sendWelcome(user: User): Promise<void> {
    await this.emailQueue.add(
      'send',
      { to: user.email, template: 'welcome', data: { name: user.name } },
      { attempts: 5, backoff: { type: 'exponential', delay: 5000 } },
    );
  }
}

// Scheduled/repeating jobs — stable jobId prevents duplicate registration on restart
@Injectable()
export class ScheduledJobsService implements OnModuleInit {
  constructor(@InjectQueue('maintenance') private queue: Queue) {}

  async onModuleInit(): Promise<void> {
    await this.queue.add('cleanup', {}, { repeat: { cron: '0 0 * * *' }, jobId: 'daily-cleanup' });
    await this.queue.add('digest', {}, { repeat: { every: 60 * 60 * 1000 }, jobId: 'hourly-digest' });
  }
}

@Processor('maintenance')
export class MaintenanceProcessor {
  @Process('cleanup')
  async cleanup(): Promise<void> {
    await this.cleanupOldReports();
    await this.cleanupExpiredSessions();
  }
}
```

## Health Checks

**Incorrect:**

```typescript
@Controller('health')
export class HealthController {
  @Get()
  check(): string {
    return 'OK'; // service might be unhealthy but always returns OK
  }
}

@Controller('health')
export class HealthController {
  @Get()
  async check(): Promise<string> {
    await this.userRepo.findOne({ where: { id: '1' } }); // if DB is slow, health check itself times out
    await this.redis.ping();
    await this.externalApi.healthCheck();
    return 'OK';
  }
}
```

**Correct — separate liveness (process) from readiness (dependencies):**

```typescript
import { HealthCheckService, HttpHealthIndicator, TypeOrmHealthIndicator, HealthCheck, DiskHealthIndicator, MemoryHealthIndicator } from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private http: HttpHealthIndicator,
    private db: TypeOrmHealthIndicator,
    private disk: DiskHealthIndicator,
    private memory: MemoryHealthIndicator,
  ) {}

  // Liveness — is the process alive? cheap, local checks only
  @Get('live')
  @HealthCheck()
  liveness() {
    return this.health.check([() => this.memory.checkHeap('memory_heap', 200 * 1024 * 1024)]);
  }

  // Readiness — can this instance accept traffic? checks real dependencies, short timeouts
  @Get('ready')
  @HealthCheck()
  readiness() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.http.pingCheck('redis', 'http://redis:6379', { timeout: 1000 }),
      () => this.disk.checkStorage('disk', { path: '/', thresholdPercent: 0.9 }),
    ]);
  }
}

// Custom business-specific indicator
@Injectable()
export class QueueHealthIndicator extends HealthIndicator {
  constructor(private queueService: QueueService) { super(); }

  async isHealthy(key: string): Promise<HealthIndicatorResult> {
    const stats = await this.queueService.getStats();
    const isHealthy = stats.failedCount < 100;
    const result = this.getStatus(key, isHealthy, { waiting: stats.waitingCount, active: stats.activeCount, failed: stats.failedCount });
    if (!isHealthy) throw new HealthCheckError('Queue unhealthy', result);
    return result;
  }
}

// Readiness respects graceful shutdown state — pairs with nestjs-performance §5
@Get('ready')
@HealthCheck()
readiness() {
  if (this.shutdownService.isShutdown()) throw new ServiceUnavailableException('Shutting down');
  return this.health.check([() => this.db.pingCheck('database')]);
}
```

```yaml
# Kubernetes probes pointed at the two distinct endpoints
livenessProbe:
  httpGet: { path: /health/live, port: 3000 }
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
readinessProbe:
  httpGet: { path: /health/ready, port: 3000 }
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```
