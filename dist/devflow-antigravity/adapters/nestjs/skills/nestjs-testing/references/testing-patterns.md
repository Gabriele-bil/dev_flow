# NestJS Testing — Full Patterns

Source rules: `test-use-testing-module`, `test-e2e-supertest`, `test-mock-external-services`.

## TestingModule for Unit Tests

**Incorrect:**

```typescript
describe('UsersService', () => {
  it('should create user', async () => {
    const repo = new UserRepository(); // real repo, bypasses DI!
    const service = new UsersService(repo);
    const user = await service.create({ name: 'Test' }); // hits real database
  });
});

describe('UsersController', () => {
  it('should call service', async () => {
    const service = { create: jest.fn() };
    const controller = new UsersController(service as any);
    await controller.create({ name: 'Test' });
    expect(service.create).toHaveBeenCalled(); // tests implementation, not behavior
  });
});
```

**Correct:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';

describe('UsersService', () => {
  let service: UsersService;
  let repo: jest.Mocked<UserRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: UserRepository, useValue: { save: jest.fn(), findOne: jest.fn(), find: jest.fn() } },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repo = module.get(UserRepository);
  });

  afterEach(() => { jest.clearAllMocks(); });

  describe('create', () => {
    it('should save and return user', async () => {
      const dto = { name: 'John', email: 'john@test.com' };
      const expectedUser = { id: '1', ...dto };
      repo.save.mockResolvedValue(expectedUser);

      const result = await service.create(dto);

      expect(result).toEqual(expectedUser);
      expect(repo.save).toHaveBeenCalledWith(dto);
    });

    it('should throw on duplicate email', async () => {
      repo.findOne.mockResolvedValue({ id: '1', email: 'test@test.com' });
      await expect(service.create({ name: 'Test', email: 'test@test.com' })).rejects.toThrow(ConflictException);
    });
  });

  describe('findById', () => {
    it('should throw NotFoundException when not found', async () => {
      repo.findOne.mockResolvedValue(null);
      await expect(service.findById('999')).rejects.toThrow(NotFoundException);
    });
  });
});

// Guards/interceptors get the same treatment
describe('RolesGuard', () => {
  let guard: RolesGuard;
  let reflector: Reflector;

  beforeEach(async () => {
    const module = await Test.createTestingModule({ providers: [RolesGuard, Reflector] }).compile();
    guard = module.get<RolesGuard>(RolesGuard);
    reflector = module.get<Reflector>(Reflector);
  });

  it('should allow admin for admin-only route', () => {
    const context = createMockExecutionContext({ user: { roles: ['admin'] } });
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    expect(guard.canActivate(context)).toBe(true);
  });
});

function createMockExecutionContext(request: Partial<Request>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => jest.fn(),
    getClass: () => jest.fn(),
  } as ExecutionContext;
}
```

## Supertest for E2E Testing

**Incorrect:**

```typescript
describe('UsersController', () => {
  it('should return users', async () => {
    const service = { findAll: jest.fn().mockResolvedValue([]) };
    const controller = new UsersController(service as any);
    const result = await controller.findAll();
    expect(result).toEqual([]);
    // doesn't test routes, guards, pipes, serialization
  });
});

describe('Users API', () => {
  it('should create user', async () => {
    const app = await NestFactory.create(AppModule); // no init/global config, no cleanup, hits real DB
  });
});
```

**Correct:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';

describe('UsersController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication();

    // apply the SAME config as main.ts — otherwise this doesn't validate the real request path
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));

    await app.init();
  });

  afterAll(async () => { await app.close(); });

  describe('/users (POST)', () => {
    it('should create a user', () => {
      return request(app.getHttpServer())
        .post('/users')
        .send({ name: 'John', email: 'john@test.com' })
        .expect(201)
        .expect((res) => {
          expect(res.body).toHaveProperty('id');
          expect(res.body.email).toBe('john@test.com');
        });
    });

    it('should return 400 for invalid email', () => {
      return request(app.getHttpServer())
        .post('/users')
        .send({ name: 'John', email: 'invalid-email' })
        .expect(400)
        .expect((res) => { expect(res.body.message).toContain('email'); });
    });
  });

  describe('/users/:id (GET)', () => {
    it('should return 404 for non-existent user', () => {
      return request(app.getHttpServer()).get('/users/non-existent-id').expect(404);
    });
  });
});

// Auth-protected routes
describe('Protected Routes (e2e)', () => {
  let app: INestApplication;
  let authToken: string;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();

    const loginResponse = await request(app.getHttpServer()).post('/auth/login').send({ email: 'test@test.com', password: 'password' });
    authToken = loginResponse.body.accessToken;
  });

  it('should return 401 without token', () => {
    return request(app.getHttpServer()).get('/users/me').expect(401);
  });

  it('should return user profile with valid token', () => {
    return request(app.getHttpServer()).get('/users/me').set('Authorization', `Bearer ${authToken}`).expect(200);
  });
});

// Database isolation — dedicated test datasource, reset between tests, never dev/prod DB
describe('Orders API (e2e)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ envFilePath: '.env.test' }), AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    dataSource = moduleFixture.get(DataSource);
    await app.init();
  });

  beforeEach(async () => { await dataSource.synchronize(true); }); // clean slate between tests

  afterAll(async () => {
    await dataSource.destroy();
    await app.close();
  });
});
```

## Mock External Services

**Incorrect:**

```typescript
describe('PaymentService', () => {
  it('should process payment', async () => {
    const service = new PaymentService(new StripeClient(realApiKey));
    const result = await service.charge('tok_visa', 1000); // hits real Stripe API — slow, costs money, flaky
  });
});

describe('UsersService', () => {
  beforeEach(async () => {
    await connection.query('DELETE FROM users'); // modifies real DB, side effects on shared database
  });
});

const mockHttpService = {
  get: jest.fn().mockResolvedValue({ data: {} }), // missing error scenarios, missing other methods
};
```

**Correct:**

```typescript
describe('WeatherService', () => {
  let service: WeatherService;
  let httpService: jest.Mocked<HttpService>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [WeatherService, { provide: HttpService, useValue: { get: jest.fn(), post: jest.fn() } }],
    }).compile();

    service = module.get(WeatherService);
    httpService = module.get(HttpService);
  });

  it('should return weather data', async () => {
    const mockResponse = { data: { temperature: 72, humidity: 45 }, status: 200, statusText: 'OK', headers: {}, config: {} };
    httpService.get.mockReturnValue(of(mockResponse));

    const result = await service.getWeather('NYC');
    expect(result).toEqual({ temperature: 72, humidity: 45 });
  });

  it('should handle API timeout', async () => {
    httpService.get.mockReturnValue(throwError(() => new Error('ETIMEDOUT')));
    await expect(service.getWeather('NYC')).rejects.toThrow('Weather service unavailable');
  });

  it('should handle rate limiting', async () => {
    httpService.get.mockReturnValue(throwError(() => ({ response: { status: 429, data: { message: 'Rate limited' } } })));
    await expect(service.getWeather('NYC')).rejects.toThrow(TooManyRequestsException);
  });
});

// Mock repository instead of database
describe('UsersService', () => {
  let service: UsersService;
  let repo: jest.Mocked<Repository<User>>;

  beforeEach(async () => {
    const mockRepo = { find: jest.fn(), findOne: jest.fn(), save: jest.fn(), delete: jest.fn(), createQueryBuilder: jest.fn() };
    const module = await Test.createTestingModule({
      providers: [UsersService, { provide: getRepositoryToken(User), useValue: mockRepo }],
    }).compile();

    service = module.get(UsersService);
    repo = module.get(getRepositoryToken(User));
  });

  it('should find user by id', async () => {
    const mockUser = { id: '1', name: 'John', email: 'john@test.com' };
    repo.findOne.mockResolvedValue(mockUser);
    const result = await service.findById('1');
    expect(result).toEqual(mockUser);
    expect(repo.findOne).toHaveBeenCalledWith({ where: { id: '1' } });
  });
});

// Shared mock factory for complex SDKs, reused across test files
function createMockStripe(): jest.Mocked<Stripe> {
  return {
    paymentIntents: { create: jest.fn(), retrieve: jest.fn(), confirm: jest.fn(), cancel: jest.fn() },
    customers: { create: jest.fn(), retrieve: jest.fn() },
  } as any;
}

// Mock time instead of real setTimeout waits
describe('TokenService', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15'));
  });
  afterEach(() => { jest.useRealTimers(); });

  it('should expire token after 1 hour', async () => {
    const token = await service.createToken();
    jest.advanceTimersByTime(61 * 60 * 1000);
    expect(await service.isValid(token)).toBe(false);
  });
});
```
