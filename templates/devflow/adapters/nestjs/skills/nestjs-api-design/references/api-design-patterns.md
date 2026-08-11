# NestJS API Design — Full Patterns

Source rules: `api-use-dto-serialization`, `api-use-interceptors`, `api-use-pipes`, `api-versioning`.

## DTOs and Serialization for Responses

**Incorrect:**

```typescript
@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<User> {
    return this.usersService.findById(id);
    // { id, email, passwordHash, ssn, internalNotes, ... } — exposes sensitive data!
  }
}

@Get(':id')
async findOne(@Param('id') id: string) {
  const user = await this.usersService.findById(id);
  return { id: user.id, email: user.email, name: user.name }; // easy to forget a field, hard to maintain
}
```

**Correct:**

```typescript
// main.ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));
  await app.listen(3000);
}

@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column() email: string;
  @Column() name: string;

  @Column() @Exclude() passwordHash: string;         // never in responses
  @Column({ nullable: true }) @Exclude() ssn: string;
  @Column({ default: false }) @Exclude({ toPlainOnly: true }) isAdmin: boolean; // excluded from response, allowed in requests
  @Column() @Exclude() internalNotes: string;

  @CreateDateColumn() createdAt: Date;
}

@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<User> {
    return this.usersService.findById(id); // safe now — sensitive fields auto-excluded
  }
}

// Explicit response DTOs for shapes that diverge from the entity
export class UserResponseDto {
  @Expose() id: string;
  @Expose() email: string;
  @Expose() name: string;

  @Expose()
  @Transform(({ obj }) => obj.posts?.length || 0)
  postCount: number;

  constructor(partial: Partial<User>) { Object.assign(this, partial); }
}

export class UserDetailResponseDto extends UserResponseDto {
  @Expose() createdAt: Date;
  @Expose() @Type(() => PostResponseDto) posts: PostResponseDto[];
}

@Controller('users')
export class UsersController {
  @Get()
  @SerializeOptions({ type: UserResponseDto })
  async findAll(): Promise<UserResponseDto[]> {
    const users = await this.usersService.findAll();
    return users.map((u) => plainToInstance(UserResponseDto, u));
  }

  @Get(':id')
  async findOne(@Param('id') id: string): Promise<UserDetailResponseDto> {
    const user = await this.usersService.findByIdWithPosts(id);
    return plainToInstance(UserDetailResponseDto, user, { excludeExtraneousValues: true });
  }
}

// Group-based conditional visibility (public vs admin vs owner)
export class UserDto {
  @Expose() id: string;
  @Expose() name: string;
  @Expose({ groups: ['admin'] }) email: string;
  @Expose({ groups: ['admin'] }) createdAt: Date;
  @Expose({ groups: ['admin', 'owner'] }) settings: UserSettings;
}

@Controller('users')
export class UsersController {
  @Get()
  @SerializeOptions({ groups: ['public'] })
  async findAllPublic(): Promise<UserDto[]> {} // { id, name }

  @Get('admin')
  @UseGuards(AdminGuard)
  @SerializeOptions({ groups: ['admin'] })
  async findAllAdmin(): Promise<UserDto[]> {} // { id, name, email, createdAt }

  @Get('me')
  @SerializeOptions({ groups: ['owner'] })
  async getProfile(@CurrentUser() user: User): Promise<UserDto> {} // { id, name, settings }
}
```

## Interceptors for Cross-Cutting Concerns

**Incorrect:**

```typescript
@Controller('users')
export class UsersController {
  @Get()
  async findAll(): Promise<User[]> {
    const start = Date.now();
    this.logger.log('findAll called');
    const users = await this.usersService.findAll();
    this.logger.log(`findAll completed in ${Date.now() - start}ms`); // repeated in every method!
    return users;
  }
}
```

**Correct:**

```typescript
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const { method, url } = request;
    const now = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          const response = context.switchToHttp().getResponse();
          this.logger.log(`${method} ${url} ${response.statusCode} - ${Date.now() - now}ms`);
        },
        error: (error) => {
          this.logger.error(`${method} ${url} ${error.status || 500} - ${Date.now() - now}ms`, error.stack);
        },
      }),
    );
  }
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    return next.handle().pipe(
      map((data) => ({ data, meta: { timestamp: new Date().toISOString(), path: context.switchToHttp().getRequest().url } })),
    );
  }
}

@Injectable()
export class TimeoutInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      timeout(5000),
      catchError((err) => { if (err instanceof TimeoutError) throw new RequestTimeoutException('Request timed out'); throw err; }),
    );
  }
}

@Module({
  providers: [
    { provide: APP_INTERCEPTOR, useClass: LoggingInterceptor },
    { provide: APP_INTERCEPTOR, useClass: TransformInterceptor },
  ],
})
export class AppModule {}

// HTTP cache interceptor, GET-only, TTL from metadata
@Injectable()
export class HttpCacheInterceptor implements NestInterceptor {
  constructor(private cacheManager: Cache, private reflector: Reflector) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<any>> {
    const request = context.switchToHttp().getRequest();
    if (request.method !== 'GET') return next.handle();

    const cacheKey = `cache:${request.url}:${JSON.stringify(request.query)}`;
    const ttl = this.reflector.get<number>('cacheTTL', context.getHandler()) || 300;

    const cached = await this.cacheManager.get(cacheKey);
    if (cached) return of(cached);

    return next.handle().pipe(tap((response) => this.cacheManager.set(cacheKey, response, ttl)));
  }
}

// Map ORM errors to HTTP exceptions in one place
@Injectable()
export class ErrorMappingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      catchError((error) => {
        if (error instanceof EntityNotFoundError) throw new NotFoundException(error.message);
        if (error instanceof QueryFailedError && error.message.includes('duplicate')) throw new ConflictException('Resource already exists');
        throw error;
      }),
    );
  }
}
```

## Pipes for Input Transformation

**Incorrect:**

```typescript
@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<User> {
    const uuid = id.trim();
    if (!isUUID(uuid)) throw new BadRequestException('Invalid UUID'); // manual validation in every handler
    return this.usersService.findOne(uuid);
  }

  @Get()
  async findAll(@Query('page') page: string, @Query('limit') limit: string): Promise<User[]> {
    const pageNum = parseInt(page) || 1;   // manual parsing and defaults
    const limitNum = parseInt(limit) || 10;
    return this.usersService.findAll(pageNum, limitNum);
  }
}
```

**Correct:**

```typescript
@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<User> { return this.usersService.findOne(id); }

  @Get()
  async findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ): Promise<User[]> { return this.usersService.findAll(page, limit); }

  @Get('by-status/:status')
  async findByStatus(@Param('status', new ParseEnumPipe(UserStatus)) status: UserStatus): Promise<User[]> {
    return this.usersService.findByStatus(status);
  }
}

@Injectable()
export class ParseDatePipe implements PipeTransform<string, Date> {
  transform(value: string): Date {
    const date = new Date(value);
    if (isNaN(date.getTime())) throw new BadRequestException('Invalid date format');
    return date;
  }
}

@Injectable()
export class ParseArrayPipe implements PipeTransform<string, string[]> {
  transform(value: string): string[] { return value ? value.split(',').map((v) => v.trim()).filter(Boolean) : []; }
}

// DTO-level transformation for whole query objects
export class FindProductsDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page?: number = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit?: number = 10;

  @IsOptional() @Transform(({ value }) => value?.split(',')) @IsArray() @IsString({ each: true })
  categories?: string[];
}

// Custom error message on a built-in pipe
@Injectable()
export class CustomParseIntPipe extends ParseIntPipe {
  constructor() {
    super({ exceptionFactory: (error) => new BadRequestException(`${error} must be a valid integer`) });
  }
}
```

## API Versioning

**Incorrect:**

```typescript
@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<User> {
    // response silently changed from { id, name, email } to { id, firstName, lastName, emailAddress } — old clients break
    return this.usersService.findOne(id);
  }
}

@Controller('v1/users') export class UsersV1Controller {}
@Controller('v2/users') export class UsersV2Controller {} // manual prefixing, inconsistent and error-prone
```

**Correct:**

```typescript
// main.ts — pick one strategy, apply consistently
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' }); // /v1/users, /v2/users
  // or: { type: VersioningType.HEADER, header: 'X-API-Version', defaultVersion: '1' }
  // or: { type: VersioningType.MEDIA_TYPE, key: 'v=', defaultVersion: '1' }
  await app.listen(3000);
}

@Controller('users')
@Version('1')
export class UsersV1Controller {
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<UserV1Response> {
    const user = await this.usersService.findOne(id);
    return { id: user.id, name: user.name, email: user.email };
  }
}

@Controller('users')
@Version('2')
export class UsersV2Controller {
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<UserV2Response> {
    const user = await this.usersService.findOne(id);
    return { id: user.id, firstName: user.firstName, lastName: user.lastName, emailAddress: user.email, createdAt: user.createdAt };
  }
}

// Per-route versioning within one controller
@Controller('users')
export class UsersController {
  @Get() @Version('1')
  findAllV1(): Promise<UserV1Response[]> { return this.usersService.findAllV1(); }

  @Get() @Version('2')
  findAllV2(): Promise<UserV2Response[]> { return this.usersService.findAllV2(); }

  @Get(':id') @Version(['1', '2']) // same handler serves multiple versions
  findOne(@Param('id') id: string): Promise<User> { return this.usersService.findOne(id); }

  @Post() @Version(VERSION_NEUTRAL) // unaffected by version bumps
  create(@Body() dto: CreateUserDto): Promise<User> { return this.usersService.create(dto); }
}

// Deprecation headers instead of silently dropping a version
@Controller('users')
@Version('1')
@UseInterceptors(DeprecationInterceptor)
export class UsersV1Controller {}

@Injectable()
export class DeprecationInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const response = context.switchToHttp().getResponse();
    response.setHeader('Deprecation', 'true');
    response.setHeader('Sunset', 'Sat, 1 Jan 2025 00:00:00 GMT');
    response.setHeader('Link', '</v2/users>; rel="successor-version"');
    return next.handle();
  }
}
```
