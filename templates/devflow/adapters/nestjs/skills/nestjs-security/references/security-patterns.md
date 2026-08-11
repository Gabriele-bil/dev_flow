# NestJS Security — Full Patterns

Source rules: `security-validate-all-input`, `security-use-guards`, `security-auth-jwt`, `security-rate-limiting`, `security-sanitize-output`.

## Validate All Input with DTOs and Pipes

**Incorrect:**

```typescript
@Controller('users')
export class UsersController {
  @Post()
  create(@Body() body: any) {
    return this.usersService.create(body); // could contain anything
  }

  @Get()
  findAll(@Query() query: any) {
    return this.usersService.findAll(query.limit); // "'; DROP TABLE users; --"
  }
}

export class CreateUserDto {
  name: string;    // no validation
  email: string;   // could be "not-an-email"
  age: number;      // could be "abc" or -999
}
```

**Correct:**

```typescript
// main.ts
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    transformOptions: { enableImplicitConversion: true },
  }),
);

export class CreateUserDto {
  @IsString() @IsNotEmpty() @MinLength(2) @MaxLength(100)
  @Transform(({ value }) => value?.trim())
  name: string;

  @IsEmail()
  @Transform(({ value }) => value?.toLowerCase().trim())
  email: string;

  @IsInt() @Min(0) @Max(150)
  age: number;

  @IsString() @MinLength(8) @MaxLength(100)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, { message: 'Password must contain uppercase, lowercase, and number' })
  password: string;
}

export class FindUsersQueryDto {
  @IsOptional() @IsString() @MaxLength(100)
  search?: string;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit: number = 20;

  @IsOptional() @Type(() => Number) @IsInt() @Min(0)
  offset: number = 0;
}

export class UserIdParamDto {
  @IsUUID('4')
  id: string;
}

@Controller('users')
export class UsersController {
  @Post()
  create(@Body() dto: CreateUserDto): Promise<User> { return this.usersService.create(dto); }

  @Get()
  findAll(@Query() query: FindUsersQueryDto): Promise<User[]> { return this.usersService.findAll(query); }

  @Get(':id')
  findOne(@Param() params: UserIdParamDto): Promise<User> { return this.usersService.findById(params.id); }
}
```

## Guards for Authentication/Authorization

**Incorrect:**

```typescript
@Controller('admin')
export class AdminController {
  @Get('users')
  async getUsers(@Request() req) {
    if (!req.user) throw new UnauthorizedException();
    if (!req.user.roles.includes('admin')) throw new ForbiddenException();
    return this.adminService.getUsers();
  }
  // repeated in every handler
}
```

**Correct:**

```typescript
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private jwtService: JwtService, private reflector: Reflector) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>('isPublic', [context.getHandler(), context.getClass()]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const token = this.extractToken(request);
    if (!token) throw new UnauthorizedException('No token provided');

    try {
      request.user = await this.jwtService.verifyAsync(token);
      return true;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }

  private extractToken(request: Request): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>('roles', [context.getHandler(), context.getClass()]);
    if (!requiredRoles) return true;
    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}

export const Public = () => SetMetadata('isPublic', true);
export const Roles = (...roles: Role[]) => SetMetadata('roles', roles);

@Module({
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}

@Controller('admin')
@Roles(Role.Admin)
export class AdminController {
  @Get('users')
  getUsers(): Promise<User[]> { return this.adminService.getUsers(); }

  @Public()
  @Get('health')
  health() { return { status: 'ok' }; }
}
```

## Secure JWT Authentication

**Incorrect:**

```typescript
@Module({
  imports: [JwtModule.register({ secret: 'my-secret-key', signOptions: { expiresIn: '7d' } })], // hardcoded, too long-lived
})
export class AuthModule {}

async login(user: User): Promise<{ accessToken: string }> {
  const payload = {
    sub: user.id,
    email: user.email,
    password: user.password, // NEVER include
    ssn: user.ssn,            // NEVER include
    isAdmin: user.isAdmin,
  };
  return { accessToken: this.jwtService.sign(payload) };
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({ jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(), secretOrKey: 'my-secret' });
  }
  async validate(payload: any): Promise<any> { return payload; } // no existence check
}
```

**Correct:**

```typescript
@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: '15m', issuer: config.get('JWT_ISSUER'), audience: config.get('JWT_AUDIENCE') },
      }),
    }),
    PassportModule.register({ defaultStrategy: 'jwt' }),
  ],
})
export class AuthModule {}

@Injectable()
export class AuthService {
  async login(user: User): Promise<TokenResponse> {
    const payload: JwtPayload = { sub: user.id, email: user.email, roles: user.roles, iat: Math.floor(Date.now() / 1000) };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = await this.createRefreshToken(user.id);
    return { accessToken, refreshToken, expiresIn: 900 };
  }

  private async createRefreshToken(userId: string): Promise<string> {
    const token = randomBytes(32).toString('hex');
    const hashedToken = await bcrypt.hash(token, 10);
    await this.refreshTokenRepo.save({ userId, token: hashedToken, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) });
    return token;
  }
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private config: ConfigService, private usersService: UsersService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.get<string>('JWT_SECRET'),
      ignoreExpiration: false,
      issuer: config.get('JWT_ISSUER'),
      audience: config.get('JWT_AUDIENCE'),
    });
  }

  async validate(payload: JwtPayload): Promise<User> {
    const user = await this.usersService.findById(payload.sub);
    if (!user || !user.isActive) throw new UnauthorizedException('User not found or inactive');

    if (user.passwordChangedAt) {
      const tokenIssuedAt = new Date(payload.iat * 1000);
      if (tokenIssuedAt < user.passwordChangedAt) throw new UnauthorizedException('Token invalidated by password change');
    }
    return user;
  }
}
```

## Rate Limiting

**Incorrect:**

```typescript
@Controller('auth')
export class AuthController {
  @Post('login')
  async login(@Body() dto: LoginDto) { return this.authService.login(dto); } // brute-forceable

  @Post('forgot-password')
  async forgotPassword(@Body() dto: ForgotPasswordDto) { return this.authService.sendResetEmail(dto.email); } // spammable
}
```

**Correct:**

```typescript
@Module({
  imports: [
    ThrottlerModule.forRoot([
      { name: 'short', ttl: 1000, limit: 3 },
      { name: 'medium', ttl: 10000, limit: 20 },
      { name: 'long', ttl: 60000, limit: 100 },
    ]),
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}

@Controller('auth')
export class AuthController {
  @Post('login')
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  async login(@Body() dto: LoginDto): Promise<TokenResponse> { return this.authService.login(dto); }

  @Post('forgot-password')
  @Throttle({ short: { limit: 3, ttl: 3600000 } })
  async forgotPassword(@Body() dto: ForgotPasswordDto): Promise<void> { return this.authService.sendResetEmail(dto.email); }
}

@Controller('health')
export class HealthController {
  @Get()
  @SkipThrottle()
  check(): string { return 'OK'; }
}

// Per-user-type limits (e.g. premium vs anonymous), tracker by user id when authenticated
@Injectable()
export class CustomThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Request): Promise<string> { return req.user?.id || req.ip; }
  protected async getLimit(context: ExecutionContext): Promise<number> {
    const request = context.switchToHttp().getRequest();
    if (request.user) return request.user.isPremium ? 1000 : 200;
    return 50;
  }
}
```

## Sanitize Output / Prevent XSS

**Incorrect:**

```typescript
@Injectable()
export class CommentsService {
  async create(dto: CreateCommentDto): Promise<Comment> {
    return this.repo.save({ content: dto.content, authorId: dto.authorId }); // raw, unsanitized
  }
}

@Get(':slug')
@Header('Content-Type', 'text/html')
async getPage(@Param('slug') slug: string): Promise<string> {
  const page = await this.pagesService.findBySlug(slug);
  return `<html><body>${page.content}</body></html>`; // XSS if content has user input
}
```

**Correct:**

```typescript
import * as sanitizeHtml from 'sanitize-html';

@Injectable()
export class CommentsService {
  private readonly sanitizeOptions: sanitizeHtml.IOptions = {
    allowedTags: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
    allowedAttributes: { a: ['href', 'title'] },
    allowedSchemes: ['http', 'https', 'mailto'],
  };

  async create(dto: CreateCommentDto): Promise<Comment> {
    return this.repo.save({ content: sanitizeHtml(dto.content, this.sanitizeOptions), authorId: dto.authorId });
  }
}

export class CreatePostDto {
  @IsString() @MaxLength(1000)
  @Transform(({ value }) => sanitizeHtml(value, { allowedTags: [] }))
  title: string;

  @IsString()
  @Transform(({ value }) => sanitizeHtml(value, { allowedTags: ['p', 'br', 'b', 'i', 'a'], allowedAttributes: { a: ['href'] } }))
  content: string;
}

// UUID-validate path params before they can be echoed into error messages
@Get(':id')
async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<User> {
  const user = await this.repo.findOne({ where: { id } });
  if (!user) throw new NotFoundException('User not found');
  return user;
}

// Helmet CSP
import helmet from 'helmet';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(helmet({
    contentSecurityPolicy: {
      directives: { defaultSrc: ["'self'"], scriptSrc: ["'self'"], styleSrc: ["'self'", "'unsafe-inline'"], imgSrc: ["'self'", 'data:', 'https:'] },
    },
  }));
  await app.listen(3000);
}
```
