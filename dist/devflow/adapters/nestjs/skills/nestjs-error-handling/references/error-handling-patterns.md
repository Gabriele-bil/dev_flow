# NestJS Error Handling — Full Patterns

Source rules: `error-handle-async-errors`, `error-throw-http-exceptions`, `error-use-exception-filters`, `devops-use-logging`.

## Throw HTTP Exceptions from Services

**Incorrect — return error objects instead of throwing:**

```typescript
@Injectable()
export class UsersService {
  async findById(id: string): Promise<{ user?: User; error?: string }> {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) return { error: 'User not found' }; // controller must check this
    return { user };
  }
}

@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string) {
    const result = await this.usersService.findById(id);
    if (result.error) throw new NotFoundException(result.error);
    return result.user;
  }
}
```

**Correct — throw directly, controller stays thin:**

```typescript
@Injectable()
export class UsersService {
  constructor(private readonly repo: UserRepository) {}

  async findById(id: string): Promise<User> {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) throw new NotFoundException(`User #${id} not found`);
    return user;
  }

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.repo.findOne({ where: { email: dto.email } });
    if (existing) throw new ConflictException('Email already registered');
    return this.repo.save(dto);
  }
}

@Controller('users')
export class UsersController {
  @Get(':id')
  findOne(@Param('id') id: string): Promise<User> { return this.usersService.findById(id); }
}
```

Layer-agnostic domain exception mapped to HTTP in a filter:

```typescript
export class EntityNotFoundException extends Error {
  constructor(public readonly entity: string, public readonly id: string) {
    super(`${entity} with ID "${id}" not found`);
  }
}

@Catch(EntityNotFoundException)
export class EntityNotFoundFilter implements ExceptionFilter {
  catch(exception: EntityNotFoundException, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();
    response.status(404).json({ statusCode: 404, message: exception.message, entity: exception.entity, id: exception.id });
  }
}
```

## Exception Filters — Centralized Error Shape

**Incorrect — manual handling in controller:**

```typescript
@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string, @Res() res: Response) {
    try {
      const user = await this.usersService.findById(id);
      if (!user) return res.status(404).json({ statusCode: 404, message: 'User not found' });
      return res.json(user);
    } catch (error) {
      console.error(error);
      return res.status(500).json({ statusCode: 500, message: 'Internal server error' });
    }
  }
}
```

**Correct — global + domain filters:**

```typescript
export class UserNotFoundException extends NotFoundException {
  constructor(userId: string) {
    super({ statusCode: 404, error: 'Not Found', message: `User with ID "${userId}" not found`, code: 'USER_NOT_FOUND' });
  }
}

@Catch(DomainException)
export class DomainExceptionFilter implements ExceptionFilter {
  catch(exception: DomainException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus?.() || 400;
    response.status(status).json({ statusCode: status, code: exception.code, message: exception.message, timestamp: new Date().toISOString(), path: request.url });
  }
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(private readonly logger: Logger) {}

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const message = exception instanceof HttpException ? exception.message : 'Internal server error';

    this.logger.error(`${request.method} ${request.url}`, exception instanceof Error ? exception.stack : exception);
    response.status(status).json({ statusCode: status, message, timestamp: new Date().toISOString(), path: request.url });
  }
}

// main.ts
app.useGlobalFilters(new AllExceptionsFilter(app.get(Logger)), new DomainExceptionFilter());

// or module-scoped, DI-aware
@Module({ providers: [{ provide: APP_FILTER, useClass: AllExceptionsFilter }] })
export class AppModule {}
```

## Async Error Handling

**Incorrect:**

```typescript
@Injectable()
export class UsersService {
  async createUser(dto: CreateUserDto): Promise<User> {
    const user = await this.repo.save(dto);
    this.emailService.sendWelcome(user.email); // fire-and-forget, unhandled if it rejects
    return user;
  }
}

@Injectable()
export class OrdersService {
  @OnEvent('order.created')
  handleOrderCreated(event: OrderCreatedEvent) {
    this.processOrder(event); // returns a promise, not awaited — errors crash the process
  }
}

@Cron('0 0 * * *')
async dailyCleanup(): Promise<void> {
  await this.cleanupService.run(); // no try/catch
}
```

**Correct:**

```typescript
@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  async createUser(dto: CreateUserDto): Promise<User> {
    const user = await this.repo.save(dto);
    this.emailService.sendWelcome(user.email).catch((error) => {
      this.logger.error('Failed to send welcome email', error.stack);
    });
    return user;
  }
}

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  @OnEvent('order.created')
  async handleOrderCreated(event: OrderCreatedEvent): Promise<void> {
    try {
      await this.processOrder(event);
    } catch (error) {
      this.logger.error('Failed to process order', { event, error });
      await this.deadLetterQueue.add('order.created', event); // never rethrow — crashes process
    }
  }
}

@Injectable()
export class CleanupService {
  private readonly logger = new Logger(CleanupService.name);

  @Cron('0 0 * * *')
  async dailyCleanup(): Promise<void> {
    try {
      await this.cleanupService.run();
      this.logger.log('Daily cleanup completed');
    } catch (error) {
      this.logger.error('Daily cleanup failed', error.stack);
    }
  }
}

// main.ts safety net
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const logger = new Logger('Bootstrap');

  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  });
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', error);
    process.exit(1);
  });

  await app.listen(3000);
}
```

## Structured Logging

**Incorrect:**

```typescript
console.log('Creating user:', dto);                    // not structured, no levels
console.log('Login attempt:', { email, password });    // SECURITY RISK — logs secret
logger.log('User ' + userId + ' created at ' + new Date()); // unstructured concatenation
```

**Correct — NestJS Logger with context:**

```typescript
@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  async createUser(dto: CreateUserDto): Promise<User> {
    this.logger.log('Creating user', { email: dto.email });
    try {
      const user = await this.repo.save(dto);
      this.logger.log('User created', { userId: user.id });
      return user;
    } catch (error) {
      this.logger.error('Failed to create user', error.stack, { email: dto.email });
      throw error;
    }
  }
}
```

Request-scoped context via `nestjs-cls`:

```typescript
@Module({ imports: [ClsModule.forRoot({ global: true, middleware: { mount: true, generateId: true } })] })
export class AppModule {}

@Injectable()
export class RequestContextMiddleware implements NestMiddleware {
  constructor(private cls: ClsService) {}
  use(req: Request, res: Response, next: NextFunction): void {
    const requestId = req.headers['x-request-id'] || randomUUID();
    this.cls.set('requestId', requestId);
    this.cls.set('userId', req.user?.id);
    res.setHeader('x-request-id', requestId);
    next();
  }
}
```

High-performance JSON logging via Pino, with secret redaction:

```typescript
@Module({
  imports: [
    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
        transport: process.env.NODE_ENV !== 'production' ? { target: 'pino-pretty' } : undefined,
        redact: ['req.headers.authorization', 'req.body.password'],
      },
    }),
  ],
})
export class AppModule {}
```
