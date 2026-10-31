# NestJS Security — examples

One example per rule that needs one. Rules: `../SKILL.md`. Header and CSRF options change between minors — check current docs with Context7 before tuning them.

## Bootstrap (rules 1–2)

```typescript
// main.ts
const app = await NestFactory.create(AppModule);
app.useSecurityHeaders();                                        // before any app.use()
app.enableCsrfProtection({ trustedOrigins: ['https://app.example.com'] }); // cookie auth only
app.useGlobalPipes(
  new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }), // DTO classes
  new StandardSchemaValidationPipe(),                                                   // @Body({ schema })
);
app.enableShutdownHooks();                                       // see nestjs-performance
await app.listen(process.env.PORT ?? 3000);
```

## Standard Schema input (rule 2)

```typescript
export const createUserSchema = z.object({ email: z.email(), password: z.string().min(12) });
export type CreateUserDto = z.infer<typeof createUserSchema>;

@Post()
create(@Body({ schema: createUserSchema }) dto: CreateUserDto) { return this.users.create(dto); }

@Get(':id')
findOne(@Param('id', { schema: z.uuid() }) id: string) { return this.users.findOne(id); }
```

## Global guards with opt-out (rule 3)

```typescript
export const IS_PUBLIC = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC, true);

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) { super(); }
  canActivate(ctx: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()]);
    return isPublic || super.canActivate(ctx);
  }
}

// app.module.ts — order matters: auth, then roles, then throttling
providers: [
  { provide: APP_GUARD, useClass: JwtAuthGuard },
  { provide: APP_GUARD, useClass: RolesGuard },
  { provide: APP_GUARD, useClass: ThrottlerGuard },
]
```

## Rate-limit tiers (rule 5)

```typescript
ThrottlerModule.forRoot([
  { name: 'short', ttl: 1000, limit: 3 },
  { name: 'long', ttl: 60_000, limit: 100 },
]);

@Post('login')
@Throttle({ short: { limit: 5, ttl: 60_000 } })
login(@Body() dto: LoginDto) { return this.auth.login(dto); }
```
