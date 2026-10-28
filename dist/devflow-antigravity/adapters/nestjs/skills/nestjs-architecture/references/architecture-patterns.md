# NestJS Architecture — Full Patterns

Source rules: `arch-feature-modules`, `arch-module-sharing`, `arch-avoid-circular-deps`, `arch-single-responsibility`, `arch-use-repository-pattern`, `arch-use-events`, `di-prefer-constructor-injection`, `di-avoid-service-locator`, `di-use-interfaces-tokens`, `di-interface-segregation`, `di-liskov-substitution`, `di-scope-awareness`, `devops-use-config-module`.

## Feature Modules vs Technical Layers

**Incorrect — technical layer organization:**

```text
src/
├── controllers/{users,orders,products}.controller.ts
├── services/{users,orders,products}.service.ts
├── entities/{user,order,product}.entity.ts
└── app.module.ts   // imports everything directly
```

**Correct — feature modules:**

```typescript
// users/users.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  exports: [UsersService], // export only what other modules need
})
export class UsersModule {}

// app.module.ts
@Module({
  imports: [ConfigModule.forRoot(), TypeOrmModule.forRoot(), UsersModule, OrdersModule, SharedModule],
})
export class AppModule {}
```

## Module Sharing — Singleton Instances

**Incorrect — service provided in multiple modules (two separate instances):**

```typescript
// app.module.ts
@Module({ providers: [StorageService] })  // instance #1
export class AppModule {}

// videos.module.ts
@Module({ providers: [StorageService] })  // instance #2 — different state!
export class VideosModule {}
```

**Correct — dedicated module, exported, imported where needed:**

```typescript
// storage/storage.module.ts
@Module({ providers: [StorageService], exports: [StorageService] })
export class StorageModule {}

// videos/videos.module.ts
@Module({ imports: [StorageModule], controllers: [VideosController], providers: [VideosService] })
export class VideosModule {}
```

`@Global()` only for true cross-cutting concerns (config, logging, DB connection) — imported once in `AppModule`, available everywhere without re-importing. Overuse hides the dependency graph.

## Circular Dependencies

**Incorrect:**

```typescript
// users.module.ts
@Module({ imports: [OrdersModule], providers: [UsersService], exports: [UsersService] })
export class UsersModule {}

// orders.module.ts
@Module({ imports: [UsersModule], providers: [OrdersService], exports: [OrdersService] })
export class OrdersModule {}
```

**Correct — extract shared logic, or decouple via events:**

```typescript
// users.service.ts
@Injectable()
export class UsersService {
  constructor(private eventEmitter: EventEmitter2) {}

  async createUser(data: CreateUserDto) {
    const user = await this.userRepo.save(data);
    this.eventEmitter.emit('user.created', user);
    return user;
  }
}

// orders.service.ts
@Injectable()
export class OrdersService {
  @OnEvent('user.created')
  handleUserCreated(user: User) {
    // react without a direct dependency on UsersModule
  }
}
```

## Single Responsibility

**Incorrect — god service:**

```typescript
@Injectable()
export class UserAndOrderService {
  constructor(
    private userRepo: UserRepository,
    private orderRepo: OrderRepository,
    private mailer: MailService,
    private payment: PaymentService,
  ) {}

  async createUser(dto: CreateUserDto) { /* ... */ }
  async createOrder(userId: string, dto: CreateOrderDto) { /* payment + mail mixed in */ }
  async calculateOrderStats(userId: string) { /* stats logic mixed in */ }
}
```

**Correct — one service, one responsibility; orchestration lives in the controller:**

```typescript
@Injectable()
export class UsersService {
  constructor(private userRepo: UserRepository) {}
  async create(dto: CreateUserDto): Promise<User> { return this.userRepo.save(dto); }
}

@Injectable()
export class OrdersService {
  constructor(private orderRepo: OrderRepository) {}
  async create(userId: string, dto: CreateOrderDto): Promise<Order> { return this.orderRepo.save({ userId, ...dto }); }
}

@Controller('orders')
export class OrdersController {
  constructor(
    private orders: OrdersService,
    private payment: PaymentService,
    private notifications: NotificationService,
  ) {}

  @Post()
  async create(@CurrentUser() user: User, @Body() dto: CreateOrderDto) {
    const order = await this.orders.create(user.id, dto);
    await this.payment.charge(order);
    await this.notifications.sendOrderConfirmation(order);
    return order;
  }
}
```

## Repository Pattern

```typescript
@Injectable()
export class UsersRepository {
  constructor(@InjectRepository(User) private repo: Repository<User>) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.repo.findOne({ where: { email } });
  }

  async findActiveWithMinOrders(minOrders: number): Promise<User[]> {
    return this.repo
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.orders', 'order')
      .where('user.isActive = :active', { active: true })
      .groupBy('user.id')
      .having('COUNT(order.id) >= :min', { min: minOrders })
      .getMany();
  }
}

@Injectable()
export class UsersService {
  constructor(private usersRepo: UsersRepository) {} // clean — no query logic here

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.usersRepo.findByEmail(dto.email);
    if (existing) throw new ConflictException('Email already registered');
    return this.usersRepo.save({ ...dto });
  }
}
```

## Constructor Injection

**Incorrect — property injection, hidden dependencies:**

```typescript
@Injectable()
export class UsersService {
  @Inject() private userRepo: UserRepository;
  @Inject('CONFIG') private config: ConfigType;
}
```

**Correct:**

```typescript
@Injectable()
export class UsersService {
  constructor(
    private readonly userRepo: UserRepository,
    @Inject('CONFIG') private readonly config: ConfigType,
  ) {}
}

// Trivially testable without the DI container
const service = new UsersService(mockRepo, { dbUrl: 'test' });
```

Only use property injection for genuinely `@Optional()` dependencies:

```typescript
@Injectable()
export class LoggingService {
  @Optional() @Inject('ANALYTICS') private analytics?: AnalyticsService;
}
```

## Avoid Service Locator

**Incorrect:**

```typescript
@Injectable()
export class OrdersService {
  constructor(private moduleRef: ModuleRef) {}

  async createOrder(dto: CreateOrderDto) {
    const usersService = this.moduleRef.get(UsersService); // hidden dependency
    const paymentService = this.moduleRef.get(PaymentService);
  }
}
```

**Correct:**

```typescript
@Injectable()
export class OrdersService {
  constructor(
    private usersService: UsersService,
    private paymentService: PaymentService,
  ) {}
}
```

`ModuleRef` remains valid for genuine dynamic factory lookups:

```typescript
@Injectable()
export class HandlerFactory {
  constructor(private moduleRef: ModuleRef) {}

  getHandler(type: string): Handler {
    switch (type) {
      case 'email': return this.moduleRef.get(EmailHandler);
      case 'sms': return this.moduleRef.get(SmsHandler);
      default: return this.moduleRef.get(DefaultHandler);
    }
  }
}
```

## Injection Tokens for Interfaces

Interfaces are erased at compile time — cannot be used as a DI token directly.

```typescript
export const PAYMENT_GATEWAY = Symbol('PAYMENT_GATEWAY');

export interface PaymentGateway {
  charge(amount: number): Promise<PaymentResult>;
}

@Injectable()
export class StripeService implements PaymentGateway {
  async charge(amount: number): Promise<PaymentResult> { /* ... */ }
}

@Module({
  providers: [
    { provide: PAYMENT_GATEWAY, useClass: process.env.NODE_ENV === 'test' ? MockPaymentService : StripeService },
  ],
  exports: [PAYMENT_GATEWAY],
})
export class PaymentModule {}

@Injectable()
export class OrdersService {
  constructor(@Inject(PAYMENT_GATEWAY) private payment: PaymentGateway) {}
}
```

Alternative: an abstract class carries runtime type info, so no `@Inject()` token is needed:

```typescript
export abstract class PaymentGateway {
  abstract charge(amount: number): Promise<PaymentResult>;
}

@Injectable()
export class StripeService extends PaymentGateway { /* ... */ }

@Injectable()
export class OrdersService {
  constructor(private payment: PaymentGateway) {} // no @Inject needed
}
```

## Interface Segregation

Split fat interfaces by capability so consumers and their test mocks depend only on what they use:

```typescript
interface EmailSender { sendEmail(to: string, subject: string, body: string): Promise<void>; }
interface SmsSender { sendSms(phone: string, message: string): Promise<void>; }

@Injectable()
export class OrdersService {
  constructor(@Inject(EMAIL_SENDER) private emailSender: EmailSender) {} // depends on 1 method, not 8
}

const mockEmailSender: EmailSender = { sendEmail: jest.fn() }; // trivial mock
```

## Liskov Substitution for DI Implementations

Every implementation (including test mocks) of a token/interface must honor the same contract — same return shape, same thrown exception types:

```typescript
interface PaymentGateway {
  /** @throws PaymentFailedException on decline */
  charge(amount: number, currency: string): Promise<PaymentResult>;
}

// Mock that VIOLATES the contract
@Injectable()
export class BadMockPaymentService implements PaymentGateway {
  async charge(amount: number, currency: string): Promise<PaymentResult> {
    if (currency !== 'USD') return null as any; // real service converts/rejects — never returns null
    return { success: true } as PaymentResult;   // missing transactionId!
  }
}

// Mock that HONORS the contract
@Injectable()
export class MockPaymentService implements PaymentGateway {
  async charge(amount: number, currency: string): Promise<PaymentResult> {
    if (!['USD', 'EUR', 'GBP'].includes(currency)) throw new InvalidCurrencyException(currency);
    return { success: true, transactionId: `mock_${Date.now()}`, amount };
  }
}
```

Write one shared contract test suite and run it against every implementation (production + mock) to catch LSP violations mechanically.

## Provider Scopes

```typescript
// WRONG: singleton with per-request mutable state — leaks across concurrent requests
@Injectable()
export class RequestContextService {
  private userId: string; // shared across ALL requests
  setUser(userId: string) { this.userId = userId; } // overwritten by next request
}

// Request-scoped ONLY when request context is genuinely needed — has a perf cost (bubbles up the injection tree)
@Injectable({ scope: Scope.REQUEST })
export class AuditService {
  constructor(@Inject(REQUEST) private request: Request) {}
  log(action: string) { console.log(`User ${this.request.user?.id} did ${action}`); }
}

// Best for request-scoped data at scale: async-context library, service stays a singleton
@Injectable()
export class AuditService {
  constructor(private cls: ClsService) {} // nestjs-cls
  log(action: string) { console.log(`User ${this.cls.get('userId')} did ${action}`); }
}
```

## ConfigModule

```typescript
// WRONG — process.env read ad hoc, no validation, fails at first use not at startup
const dbUrl = process.env.DATABASE_URL;

// RIGHT — validated at boot, namespaced, typed
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: Joi.object({ DATABASE_URL: Joi.string().required() }),
      load: [databaseConfig], // registerAs('database', () => ({...}))
    }),
  ],
})
export class AppModule {}

@Injectable()
export class DatabaseService {
  constructor(@Inject(databaseConfig.KEY) private config: ConfigType<typeof databaseConfig>) {}
}
```
