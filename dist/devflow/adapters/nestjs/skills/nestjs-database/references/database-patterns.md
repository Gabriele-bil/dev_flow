# NestJS Database — TypeORM 1 vs Prisma 7

Rules: `../SKILL.md`. Use only the column of the project ORM (`ADAPTER.md` → Project choices). Anything not listed: check current docs with Context7.

| Concern | TypeORM 1 (`@nestjs/typeorm`) | Prisma 7 |
| --- | --- | --- |
| Schema source | `*.entity.ts` (`@Entity`, `@Index`) | `prisma/schema.prisma` |
| Client in DI | `TypeOrmModule.forFeature([User])` + `@InjectRepository(User)` | `PrismaService extends PrismaClient` in a `@Global()` `PrismaModule` |
| Relations in one query | `find({ relations: { items: { product: true } } })` or `leftJoinAndSelect` | `findMany({ include: { items: { include: { product: true } } } })` |
| Column subset | `find({ select: { id: true, total: true } })` | `findMany({ select: { id: true, total: true } })` |
| Null match | `where: { deletedAt: IsNull() }` | `where: { deletedAt: null }` |
| Transaction | `dataSource.transaction(async (manager) => …)` | `prisma.$transaction(async (tx) => …, { timeout })` |
| Manual control | `createQueryRunner()` → `startTransaction` / `commitTransaction` / `rollbackTransaction` / `release` in `finally` | not needed — callback form only |
| New migration | `typeorm migration:generate -d <data-source> <name>` | `prisma migrate dev --name <name>` |
| Deploy migrations | `typeorm migration:run -d <data-source>` | `prisma migrate deploy` |
| Never outside local | `synchronize: true` | `prisma db push` |
| Health check | `TypeOrmHealthIndicator.pingCheck('db').withTimeout(1000)` | `` healthIndicatorService.check('db').attempt(() => prisma.$queryRaw`SELECT 1`).withTimeout(1000) `` |
| Unit-test mock | `{ provide: getRepositoryToken(User), useValue: mockRepo }` | `{ provide: PrismaService, useValue: { user: { findUnique: vi.fn() } } }` (`jest.fn()` on Jest) |
| Hide fields in responses | `@Exclude()` on entity + `ClassSerializerInterceptor` | records are plain objects — response schema / DTO (`nestjs-api-design`) |

## PrismaService (Prisma 7)

```typescript
// prisma/schema.prisma → generator client { provider = "prisma-client"  output = "../src/generated/prisma" }
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor(config: ConfigService) {
    super({ adapter: new PrismaPg({ connectionString: config.getOrThrow('DATABASE_URL') }) });
  }
  async onModuleInit() { await this.$connect(); }
  async onModuleDestroy() { await this.$disconnect(); }
}
```

## Atomic write (both ORMs)

```typescript
// TypeORM
return this.dataSource.transaction(async (manager) => {
  const order = await manager.save(Order, { userId, status: 'pending' });
  await manager.decrement(Inventory, { productId }, 'stock', qty);
  return order;
});

// Prisma
return this.prisma.$transaction(async (tx) => {
  const order = await tx.order.create({ data: { userId, status: 'pending' } });
  await tx.inventory.update({ where: { productId }, data: { stock: { decrement: qty } } });
  return order;
});
```
