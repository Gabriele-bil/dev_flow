# NestJS Performance — Full Patterns

Source rules: `perf-async-hooks`, `perf-lazy-loading`, `perf-optimize-database`, `perf-use-caching`, `devops-graceful-shutdown`.

## Async Lifecycle Hooks

**Incorrect:**

```typescript
@Injectable()
export class DatabaseService implements OnModuleInit {
  onModuleInit() {
    this.connect(); // not awaited — app starts before DB is ready!
  }
  private async connect() { await this.pool.connect(); }
}

@Injectable()
export class ConfigService {
  private config: Config;
  constructor() {
    this.config = fs.readFileSync('config.json'); // blocks module instantiation synchronously
  }
}
```

**Correct:**

```typescript
@Injectable()
export class DatabaseService implements OnModuleInit {
  private pool: Pool;

  async onModuleInit(): Promise<void> {
    await this.pool.connect(); // Nest waits for this before continuing boot
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}

@Injectable()
export class CacheWarmerService implements OnApplicationBootstrap {
  constructor(private cache: CacheService, private products: ProductsService) {}

  async onApplicationBootstrap(): Promise<void> {
    // all modules initialized — safe for cross-module work
    const products = await this.products.findPopular();
    await this.cache.warmup(products);
  }
}

@Injectable()
export class ConfigService implements OnModuleInit {
  private config: Config;
  constructor() {} // synchronous and fast

  async onModuleInit(): Promise<void> {
    this.config = await this.loadConfig();
  }

  private async loadConfig(): Promise<Config> {
    const file = await fs.promises.readFile('config.json');
    return JSON.parse(file.toString());
  }
}
```

## Lazy Loading

**Incorrect — everything eager:**

```typescript
@Module({
  imports: [UsersModule, OrdersModule, PaymentsModule, ReportsModule, AnalyticsModule, AdminModule, LegacyModule, BulkImportModule],
})
export class AppModule {} // all initialize at startup even if never used — slow cold starts
```

**Correct:**

```typescript
import { LazyModuleLoader } from '@nestjs/core';

@Injectable()
export class ReportsService {
  constructor(private lazyModuleLoader: LazyModuleLoader) {}

  async generateReport(type: string): Promise<Report> {
    const { ReportsModule } = await import('./reports/reports.module');
    const moduleRef = await this.lazyModuleLoader.load(() => ReportsModule);
    const reportsService = moduleRef.get(ReportsGeneratorService);
    return reportsService.generate(type);
  }
}

// Cache the loaded ModuleRef so repeat calls skip the import
@Injectable()
export class AdminService {
  private adminModule: ModuleRef | null = null;
  constructor(private lazyModuleLoader: LazyModuleLoader) {}

  private async getAdminModule(): Promise<ModuleRef> {
    if (!this.adminModule) {
      const { AdminModule } = await import('./admin/admin.module');
      this.adminModule = await this.lazyModuleLoader.load(() => AdminModule);
    }
    return this.adminModule;
  }
}

// Preload in background after startup, not blocking boot
@Injectable()
export class ModulePreloader implements OnApplicationBootstrap {
  constructor(private lazyModuleLoader: LazyModuleLoader) {}
  async onApplicationBootstrap(): Promise<void> {
    setTimeout(async () => {
      await this.preloadModule(() => import('./reports/reports.module'));
    }, 5000);
  }
  private async preloadModule(importFn: () => Promise<any>): Promise<void> {
    const module = await importFn();
    const moduleType = module.default || Object.values(module)[0];
    await this.lazyModuleLoader.load(() => moduleType);
  }
}
```

## Optimize Database Queries

**Incorrect:**

```typescript
@Injectable()
export class UsersService {
  async findAllEmails(): Promise<string[]> {
    const users = await this.repo.find(); // fetches ALL columns for ALL users
    return users.map((u) => u.email);
  }

  async getUserSummary(id: string): Promise<UserSummary> {
    const user = await this.repo.findOne({
      where: { id },
      relations: ['posts', 'posts.comments', 'posts.comments.author', 'followers'], // massive over-fetch
    });
    return { name: user.name, postCount: user.posts.length };
  }
}

@Entity()
export class Order {
  @Column() userId: string; // no index — full table scan on every lookup
  @Column() status: string; // no index — slow status filtering
}
```

**Correct:**

```typescript
@Injectable()
export class UsersService {
  async findAllEmails(): Promise<string[]> {
    const users = await this.repo.find({ select: ['email'] }); // only fetch what's needed
    return users.map((u) => u.email);
  }

  async getUserSummary(id: string): Promise<UserSummary> {
    return this.repo
      .createQueryBuilder('user')
      .select('user.name', 'name')
      .addSelect('COUNT(post.id)', 'postCount')
      .leftJoin('user.posts', 'post')
      .where('user.id = :id', { id })
      .groupBy('user.id')
      .getRawOne();
  }

  async getFullProfile(id: string): Promise<User> {
    return this.repo.findOne({
      where: { id },
      relations: ['posts'],
      select: { id: true, name: true, email: true, posts: { id: true, title: true } },
    });
  }
}

@Entity()
@Index(['userId'])
@Index(['status'])
@Index(['createdAt'])
@Index(['userId', 'status']) // composite index for common query pattern
export class Order {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column() userId: string;
  @Column() status: string;
  @CreateDateColumn() createdAt: Date;
}

@Injectable()
export class OrdersService {
  async findAll(page = 1, limit = 20): Promise<PaginatedResult<Order>> {
    const [items, total] = await this.repo.findAndCount({
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });
    return { items, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }
}
```

## Strategic Caching

**Incorrect:**

```typescript
@Injectable()
export class ProductsService {
  async getPopular(): Promise<Product[]> {
    // complex aggregation query runs EVERY request, no cache
    return this.productsRepo.createQueryBuilder('p').leftJoin('p.orders', 'o')
      .select('p.*, COUNT(o.id) as orderCount').groupBy('p.id').orderBy('orderCount', 'DESC').limit(20).getMany();
  }
}

@Injectable()
export class UsersService {
  @CacheKey('users')
  @CacheTTL(3600) // caching a frequently-changing list for 1h is wrong
  @UseInterceptors(CacheInterceptor)
  async findAll(): Promise<User[]> { return this.usersRepo.find(); }
}
```

**Correct:**

```typescript
@Module({
  imports: [
    CacheModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        stores: [new KeyvRedis(config.get('REDIS_URL'))],
        ttl: 60 * 1000,
      }),
    }),
  ],
})
export class AppModule {}

@Injectable()
export class ProductsService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache, private productsRepo: ProductRepository) {}

  async getPopular(): Promise<Product[]> {
    const cacheKey = 'products:popular';
    const cached = await this.cache.get<Product[]>(cacheKey);
    if (cached) return cached;

    const products = await this.fetchPopularProducts();
    await this.cache.set(cacheKey, products, 5 * 60 * 1000);
    return products;
  }

  async updateProduct(id: string, dto: UpdateProductDto): Promise<Product> {
    const product = await this.productsRepo.save({ id, ...dto });
    await this.cache.del('products:popular'); // invalidate explicitly on write
    return product;
  }
}

@Controller('categories')
@UseInterceptors(CacheInterceptor)
export class CategoriesController {
  @Get()
  @CacheTTL(30 * 60 * 1000) // categories rarely change
  findAll(): Promise<Category[]> { return this.categoriesService.findAll(); }
}

// Event-driven invalidation, centralized rather than scattered across every mutation
@Injectable()
export class CacheInvalidationService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  @OnEvent('product.created')
  @OnEvent('product.updated')
  @OnEvent('product.deleted')
  async invalidateProductCaches(event: ProductEvent) {
    await Promise.all([this.cache.del('products:popular'), this.cache.del(`product:${event.productId}`)]);
  }
}
```

## Graceful Shutdown

**Incorrect:**

```typescript
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
  // app crashes immediately on SIGTERM, in-flight requests fail, connections abruptly closed
}
```

**Correct:**

```typescript
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks(); // mandatory — without this OnApplicationShutdown never fires

  const server = await app.listen(3000);
  server.setTimeout(30000);

  const signals = ['SIGTERM', 'SIGINT'];
  signals.forEach((signal) => {
    process.on(signal, async () => {
      server.close(async () => {
        await app.close();
        process.exit(0);
      });
      setTimeout(() => process.exit(1), 30000); // forced exit after timeout
    });
  });
}

@Injectable()
export class DatabaseService implements OnApplicationShutdown {
  private readonly connections: Connection[] = [];
  async onApplicationShutdown(signal?: string): Promise<void> {
    await Promise.all(this.connections.map((conn) => conn.close()));
  }
}

@Injectable()
export class QueueService implements OnApplicationShutdown, OnModuleDestroy {
  private isShuttingDown = false;
  onModuleDestroy(): void { this.isShuttingDown = true; }
  async onApplicationShutdown(): Promise<void> { await this.queue.close(); }
  async processJob(job: Job): Promise<void> {
    if (this.isShuttingDown) throw new Error('Service is shutting down');
    await this.doWork(job);
  }
}

// Readiness probe returns 503 during shutdown so k8s stops routing traffic
@Injectable()
export class ShutdownService {
  private isShuttingDown = false;
  startShutdown(): void { this.isShuttingDown = true; }
  isShutdown(): boolean { return this.isShuttingDown; }
}

@Controller('health')
export class HealthController {
  constructor(private shutdownService: ShutdownService) {}

  @Get('ready')
  @HealthCheck()
  readiness(): Promise<HealthCheckResult> {
    if (this.shutdownService.isShutdown()) throw new ServiceUnavailableException('Shutting down');
    return this.health.check([() => this.db.pingCheck('database')]);
  }
}

// Drain in-flight requests before closing
@Injectable()
export class RequestTracker implements NestMiddleware, OnApplicationShutdown {
  private activeRequests = 0;
  private isShuttingDown = false;
  private resolveShutdown: (() => void) | null = null;

  use(req: Request, res: Response, next: NextFunction): void {
    if (this.isShuttingDown) { res.status(503).send('Service Unavailable'); return; }
    this.activeRequests++;
    res.on('finish', () => {
      this.activeRequests--;
      if (this.isShuttingDown && this.activeRequests === 0 && this.resolveShutdown) this.resolveShutdown();
    });
    next();
  }

  async onApplicationShutdown(): Promise<void> {
    this.isShuttingDown = true;
    if (this.activeRequests > 0) {
      const shutdownPromise = new Promise<void>((resolve) => { this.resolveShutdown = resolve; });
      await Promise.race([shutdownPromise, new Promise((resolve) => setTimeout(resolve, 30000))]);
    }
  }
}
```
