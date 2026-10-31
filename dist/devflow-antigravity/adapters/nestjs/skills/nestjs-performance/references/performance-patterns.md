# NestJS Performance — examples

One example per rule that needs one. Rules: `../SKILL.md`. Cache store packages (Keyv adapters) change often — check current docs with Context7 before wiring a store.

## Cache with explicit invalidation (rule 3)

```typescript
@Injectable()
export class ProductsService {
  constructor(@Inject(CACHE_MANAGER) private readonly cache: Cache, private readonly repo: ProductsRepository) {}

  async popular(): Promise<Product[]> {
    const hit = await this.cache.get<Product[]>('products:popular');
    if (hit) return hit;
    const fresh = await this.repo.findPopular();
    await this.cache.set('products:popular', fresh, 5 * 60_000); // ms
    return fresh;
  }

  @OnEvent('product.changed')
  async invalidate(e: ProductChanged) {
    await Promise.all([this.cache.del('products:popular'), this.cache.del(`product:${e.id}`)]);
  }
}
```

## Shutdown (rules 4–5)

```typescript
// main.ts
app.enableShutdownHooks();

// health.module.ts
@Module({ imports: [TerminusModule.forRoot({ gracefulShutdownTimeoutMs: 10_000 })], controllers: [HealthController] })
export class HealthModule {}

// any provider holding a connection
async onApplicationShutdown() { await this.client.quit(); }
```
