# NestJS API Design — examples

One example per rule that needs one. Rules: `../SKILL.md`. Swagger options and converters change per minor — check current docs with Context7 before configuring `SwaggerModule`.

## Response shape (rule 1)

```typescript
// DTO classes
export class UserResponseDto {
  @Expose() id: string;
  @Expose() email: string;
  @Expose({ groups: ['admin'] }) createdAt: Date;
}

@Get(':id')
async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<UserResponseDto> {
  return plainToInstance(UserResponseDto, await this.users.findOne(id), { excludeExtraneousValues: true });
}

// Standard Schema — works with Prisma's plain objects
export const userResponseSchema = z.object({ id: z.uuid(), email: z.email() });

@Controller('users')
@UseInterceptors(StandardSchemaSerializerInterceptor)
export class UsersController {
  @Get()
  @SerializeOptions({ schema: userResponseSchema }) // item schema, applied to each element
  findAll() { return this.users.findAll(); }
}
```

## Deprecating a version (rule 4)

```typescript
@Injectable()
export class DeprecationInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler) {
    const res = ctx.switchToHttp().getResponse<Response>();
    res.setHeader('Deprecation', 'true');
    res.setHeader('Sunset', 'Wed, 30 Jun 2027 00:00:00 GMT');
    res.setHeader('Link', '</v2/users>; rel="successor-version"');
    return next.handle();
  }
}

@Controller({ path: 'users', version: '1' })
@UseInterceptors(DeprecationInterceptor)
export class UsersV1Controller {}
```
