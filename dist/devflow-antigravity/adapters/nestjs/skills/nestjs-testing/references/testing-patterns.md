# NestJS Testing — examples

One example per rule that needs one. Rules: `../SKILL.md`. Shown with Vitest; on Jest replace `vi` with `jest`. Vitest/SWC config keys move between majors — check current docs with Context7 before editing `vitest.config.ts`.

## Unit test with mocked boundary (rules 2–3, 7)

```typescript
describe('UsersService', () => {
  let service: UsersService;
  const repo = { findByEmail: vi.fn(), save: vi.fn() };

  beforeEach(async () => {
    vi.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [UsersService, { provide: UsersRepository, useValue: repo }],
    }).compile();
    service = module.get(UsersService);
  });

  it('rejects a duplicate email', async () => {
    repo.findByEmail.mockResolvedValue({ id: '1' });
    await expect(service.create({ email: 'a@b.co', password: 'x'.repeat(12) })).rejects.toThrow(ConflictException);
  });
});
```

## E2E with the production bootstrap (rules 4–5)

```typescript
// src/configure-app.ts — called by main.ts and by every e2e suite
export function configureApp(app: INestApplication) {
  app.useSecurityHeaders();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  return app;
}

// test/users.e2e-spec.ts
let app: INestApplication;

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(MailService).useValue({ send: vi.fn() })
    .compile();
  app = configureApp(moduleRef.createNestApplication());
  await app.init();
});

afterAll(() => app.close());

it('POST /users rejects an invalid email', () =>
  request(app.getHttpServer()).post('/users').send({ email: 'nope' }).expect(400));
```
