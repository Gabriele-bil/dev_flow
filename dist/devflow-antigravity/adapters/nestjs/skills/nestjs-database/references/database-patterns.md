# NestJS Database — Full Patterns

Source rules: `db-avoid-n-plus-one`, `db-use-migrations`, `db-use-transactions`.

## Avoid N+1 Query Problems

**Incorrect:**

```typescript
@Injectable()
export class OrdersService {
  async getOrdersWithItems(userId: string): Promise<Order[]> {
    const orders = await this.orderRepo.find({ where: { userId } }); // 1 query
    for (const order of orders) {
      order.items = await this.itemRepo.find({ where: { orderId: order.id } }); // N additional queries
    }
    return orders;
  }
}

@Controller('users')
export class UsersController {
  @Get()
  async findAll(): Promise<User[]> {
    const users = await this.userRepo.find();
    return users; // if User.posts is lazy-loaded, serializing triggers N queries
  }
}
```

**Correct:**

```typescript
@Injectable()
export class OrdersService {
  async getOrdersWithItems(userId: string): Promise<Order[]> {
    return this.orderRepo.find({ where: { userId }, relations: ['items', 'items.product'] }); // single JOIN query
  }
}

@Injectable()
export class UsersService {
  async getUsersWithPostCounts(): Promise<UserWithPostCount[]> {
    return this.userRepo
      .createQueryBuilder('user')
      .leftJoin('user.posts', 'post')
      .select('user.id', 'id')
      .addSelect('user.name', 'name')
      .addSelect('COUNT(post.id)', 'postCount')
      .groupBy('user.id')
      .getRawMany();
  }

  async getActiveUsersWithPosts(): Promise<User[]> {
    return this.userRepo
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.posts', 'post')
      .leftJoinAndSelect('post.comments', 'comment')
      .where('user.isActive = :active', { active: true })
      .andWhere('post.status = :status', { status: 'published' })
      .getMany();
  }
}

// Shape fields explicitly to avoid over-fetching while still joining
async getOrderSummaries(userId: string): Promise<OrderSummary[]> {
  return this.orderRepo.find({
    where: { userId },
    relations: ['items'],
    select: { id: true, total: true, status: true, items: { id: true, quantity: true, price: true } },
  });
}

// DataLoader for GraphQL — batches per-tick, request-scoped
import DataLoader from 'dataloader';

@Injectable({ scope: Scope.REQUEST })
export class PostsLoader {
  constructor(private postsService: PostsService) {}

  readonly batchPosts = new DataLoader<string, Post[]>(async (userIds) => {
    const posts = await this.postsService.findByUserIds([...userIds]); // single query for all users
    const postsMap = new Map<string, Post[]>();
    for (const post of posts) {
      const userPosts = postsMap.get(post.userId) || [];
      userPosts.push(post);
      postsMap.set(post.userId, userPosts);
    }
    return userIds.map((id) => postsMap.get(id) || []);
  });
}

@ResolveField()
async posts(@Parent() user: User): Promise<Post[]> {
  return this.postsLoader.batchPosts.load(user.id);
}

// Catch N+1 patterns during development
TypeOrmModule.forRoot({ logging: ['query', 'error'], logger: 'advanced-console' });
```

## Use Database Migrations

**Incorrect:**

```typescript
TypeOrmModule.forRoot({
  type: 'postgres',
  synchronize: true, // DANGEROUS in production — can drop columns, tables, or data
});

@Injectable()
export class DatabaseService {
  async addColumn(): Promise<void> {
    await this.dataSource.query('ALTER TABLE users ADD COLUMN age INT'); // no version control, no rollback
  }
}
```

**Correct:**

```typescript
// data-source.ts
export const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST,
  entities: ['dist/**/*.entity.js'],
  migrations: ['dist/migrations/*.js'],
  synchronize: false, // always false in production
  migrationsRun: true,
});

// app.module.ts
TypeOrmModule.forRootAsync({
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    type: 'postgres',
    synchronize: config.get('NODE_ENV') === 'development', // only in dev
    migrations: ['dist/migrations/*.js'],
    migrationsRun: true,
  }),
});

// migrations/1705312800000-AddUserAge.ts
export class AddUserAge1705312800000 implements MigrationInterface {
  name = 'AddUserAge1705312800000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" ADD "age" integer DEFAULT 0`);
    await queryRunner.query(`CREATE INDEX "IDX_users_age" ON "users" ("age")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_users_age"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "age"`);
  }
}

// Safe column rename — additive, never a direct rename
export class RenameNameToFullName1705312900000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" ADD "full_name" varchar(255)`);      // 1. add new column
    await queryRunner.query(`UPDATE "users" SET "full_name" = "name"`);                // 2. backfill
    await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "full_name" SET NOT NULL`); // 3. constrain
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "name"`);                 // 4. drop old (after verifying app works)
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" ADD "name" varchar(255)`);
    await queryRunner.query(`UPDATE "users" SET "name" = "full_name"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "full_name"`);
  }
}
```

## Use Transactions for Multi-Step Operations

**Incorrect:**

```typescript
@Injectable()
export class OrdersService {
  async createOrder(userId: string, items: OrderItem[]): Promise<Order> {
    const order = await this.orderRepo.save({ userId, status: 'pending' });
    for (const item of items) {
      await this.orderItemRepo.save({ orderId: order.id, ...item });
      await this.inventoryRepo.decrement({ productId: item.productId }, 'stock', item.quantity);
    }
    await this.paymentService.charge(order.id);
    // if payment fails, order and inventory are already modified — inconsistent state
    return order;
  }
}
```

**Correct:**

```typescript
@Injectable()
export class OrdersService {
  constructor(private dataSource: DataSource) {}

  async createOrder(userId: string, items: OrderItem[]): Promise<Order> {
    return this.dataSource.transaction(async (manager) => {
      const order = await manager.save(Order, { userId, status: 'pending' });
      for (const item of items) {
        await manager.save(OrderItem, { orderId: order.id, ...item });
        await manager.decrement(Inventory, { productId: item.productId }, 'stock', item.quantity);
      }
      await this.paymentService.chargeWithManager(manager, order.id); // if this throws, everything rolls back
      return order;
    });
  }
}

// QueryRunner for manual transaction control (e.g. validation between steps)
@Injectable()
export class TransferService {
  constructor(private dataSource: DataSource) {}

  async transfer(fromId: string, toId: string, amount: number): Promise<void> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      await queryRunner.manager.decrement(Account, { id: fromId }, 'balance', amount);

      const source = await queryRunner.manager.findOne(Account, { where: { id: fromId } });
      if (source.balance < 0) throw new BadRequestException('Insufficient funds');

      await queryRunner.manager.increment(Account, { id: toId }, 'balance', amount);
      await queryRunner.manager.save(TransactionLog, { fromId, toId, amount, timestamp: new Date() });

      await queryRunner.commitTransaction();
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }
}

// Repository method with transaction support
@Injectable()
export class UsersRepository {
  constructor(@InjectRepository(User) private repo: Repository<User>, private dataSource: DataSource) {}

  async createWithProfile(userData: CreateUserDto, profileData: CreateProfileDto): Promise<User> {
    return this.dataSource.transaction(async (manager) => {
      const user = await manager.save(User, userData);
      await manager.save(Profile, { ...profileData, userId: user.id });
      return user;
    });
  }
}
```
