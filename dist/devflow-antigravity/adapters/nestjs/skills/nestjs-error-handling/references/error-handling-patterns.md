# NestJS Error Handling — examples

One example per rule that needs one. Rules: `../SKILL.md`.

## Global filter (rules 2–3)

```typescript
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const isHttp = exception instanceof HttpException;
    const status = isHttp ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    if (!isHttp) this.logger.error({ path: req.url }, exception instanceof Error ? exception.stack : String(exception));
    ctx.getResponse<Response>().status(status).json({
      statusCode: status,
      message: isHttp ? exception.message : 'Internal server error',
      timestamp: new Date().toISOString(),
      path: req.url,
    });
  }
}

// app.module.ts — DI-aware registration
providers: [{ provide: APP_FILTER, useClass: AllExceptionsFilter }]
```

## Event handler that cannot crash the process (rule 4)

```typescript
@OnEvent('order.created')
async onOrderCreated(event: OrderCreatedEvent): Promise<void> {
  try {
    await this.fulfilment.start(event.orderId);
  } catch (error) {
    this.logger.error({ orderId: event.orderId }, (error as Error).stack);
    await this.deadLetter.add('order.created', event); // never rethrow
  }
}
```
