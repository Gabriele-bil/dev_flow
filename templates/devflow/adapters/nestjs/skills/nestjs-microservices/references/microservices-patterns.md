# NestJS Microservices — examples

One example per rule that needs one. Rules: `../SKILL.md`. Transport options (Redis, NATS, Kafka, gRPC) differ per transport — check current docs with Context7 before configuring one.

## Queue: producer, consumer, scheduler (rules 3–6)

```typescript
// queue.module.ts
BullModule.forRootAsync({
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    connection: { host: config.getOrThrow('REDIS_HOST'), port: config.getOrThrow<number>('REDIS_PORT') },
    defaultJobOptions: { attempts: 3, backoff: { type: 'exponential', delay: 1000 }, removeOnComplete: 1000, removeOnFail: 5000 },
  }),
}),
BullModule.registerQueue({ name: 'reports' }),

// reports.service.ts — producer returns immediately
async request(dto: ReportRequest) {
  const job = await this.reports.add('generate', dto);
  return { jobId: job.id };
}

// reports.processor.ts
@Processor('reports')
export class ReportsProcessor extends WorkerHost {
  private readonly logger = new Logger(ReportsProcessor.name);

  async process(job: Job<ReportRequest>) {
    switch (job.name) {
      case 'generate': return this.generator.run(job.data, (p) => job.updateProgress(p));
      case 'cleanup': return this.generator.purgeOld();
    }
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error) { this.logger.error({ jobId: job.id }, error.stack); }
}

// on boot — idempotent
await this.reports.upsertJobScheduler('nightly-cleanup', { pattern: '0 3 * * *' }, { name: 'cleanup' });
```

## Health (rules 7–8)

```typescript
@Controller('health')
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly memory: MemoryHealthIndicator,
    private readonly db: TypeOrmHealthIndicator, // Prisma: see nestjs-database reference table
    private readonly queue: QueueHealthIndicator,
  ) {}

  @Get('live') @HealthCheck()
  live() { return this.health.check([() => this.memory.checkHeap('heap', 300 * 1024 * 1024)]); }

  @Get('ready') @HealthCheck()
  ready() {
    return this.health.check([
      () => this.db.pingCheck('database').withTimeout(1000),
      () => this.queue.isHealthy('reports-queue'),
    ]);
  }
}

@Injectable()
export class QueueHealthIndicator {
  constructor(@InjectQueue('reports') private readonly reports: Queue, private readonly indicators: HealthIndicatorService) {}

  async isHealthy(key: string) {
    const indicator = this.indicators.check(key);
    const { failed } = await this.reports.getJobCounts('failed');
    return failed < 100 ? indicator.up({ failed }) : indicator.down({ failed });
  }
}
```
