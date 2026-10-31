# NestJS Architecture — examples

One example per rule that needs one. Rules: `../SKILL.md`.

## Shared dynamic module (rule 3)

```typescript
// storage/storage.config.ts
export const storageModule = StorageModule.register({ bucket: 'uploads' });

// videos.module.ts and images.module.ts both import the SAME object
@Module({ imports: [storageModule], providers: [VideosService] })
export class VideosModule {}
```

## Interface token (rule 9)

```typescript
// payment.tokens.ts
export const PAYMENT_GATEWAY = Symbol('PAYMENT_GATEWAY');
export interface PaymentGateway { charge(amount: number): Promise<PaymentResult>; }

// payment.module.ts
@Module({
  providers: [{ provide: PAYMENT_GATEWAY, useClass: StripeGateway }],
  exports: [PAYMENT_GATEWAY],
})
export class PaymentModule {}

// orders.service.ts
constructor(@Inject(PAYMENT_GATEWAY) private readonly payment: PaymentGateway) {}
```

## Request context without request scope (rule 10)

```typescript
@Module({ imports: [ClsModule.forRoot({ global: true, middleware: { mount: true, generateId: true } })] })
export class AppModule {}

@Injectable() // stays a singleton
export class AuditService {
  constructor(private readonly cls: ClsService) {}
  record(action: string) { return this.repo.save({ action, requestId: this.cls.getId() }); }
}
```

## Validated, namespaced config (rule 11)

```typescript
export const dbConfig = registerAs('db', () => ({ url: process.env.DATABASE_URL! }));

ConfigModule.forRoot({
  isGlobal: true,
  load: [dbConfig],
  validationSchema: z.object({ DATABASE_URL: z.url(), PORT: z.coerce.number().default(3000) }),
});

constructor(@Inject(dbConfig.KEY) private readonly db: ConfigType<typeof dbConfig>) {}
```
