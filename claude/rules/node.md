---
paths:
  - "**/*.ts"
  - "**/*.js"
  - "**/package.json"
  - "**/tsconfig.json"
---
# Node.js Backend Standards

## API Design

- RESTful resource-based URLs: `/api/v1/orders`, `/api/v1/orders/:id`
- Repository pattern for data access abstraction
- Service layer for business logic — keep controllers/handlers thin
- Middleware for cross-cutting concerns (auth, logging, rate limiting)

```typescript
// Layered structure
router.get("/orders/:id", authenticate, async (req, res, next) => {
    try {
        const order = await orderService.findById(req.params.id);
        res.json({ success: true, data: order });
    } catch (error) {
        next(error);
    }
});
```

## Database

- Selective column queries — never `SELECT *`
- Prevent N+1: use batch fetching, `JOIN`, or DataLoader pattern
- Connection pooling (pg Pool, Prisma, Drizzle) — never create connections per request
- Wrap multi-step mutations in transactions

```typescript
// BAD — N+1
const orders = await db.query("SELECT * FROM orders");
for (const order of orders) {
    order.items = await db.query("SELECT * FROM items WHERE order_id = $1", [order.id]);
}

// GOOD — batch fetch
const orders = await db.query("SELECT * FROM orders");
const items = await db.query("SELECT * FROM items WHERE order_id = ANY($1)", [orders.map(o => o.id)]);
```

## Caching

- Redis cache-aside pattern: check cache -> miss -> query DB -> store in cache
- TTL-based invalidation — choose TTL based on data freshness requirements
- Cache keys: descriptive, versioned (`v1:orders:${id}`)

## Error Handling

- Centralized error handler middleware — single place for error formatting
- Custom error classes with HTTP status codes:

```typescript
class AppError extends Error {
    constructor(public message: string, public statusCode: number = 500) {
        super(message);
    }
}
class NotFoundError extends AppError {
    constructor(resource: string, id: string) {
        super(`${resource} not found: ${id}`, 404);
    }
}
```

- Retry with exponential backoff for transient external failures
- Never expose internal error details in API responses

## Security

- JWT verification middleware on protected routes
- Role-based access control with permission checks
- Rate limiting: `express-rate-limit`, or token bucket per user/IP
- Validate all input at API boundaries (Zod, Joi, class-validator)
- Sanitize user input before database queries and HTML rendering

## Background Jobs

- Queue patterns (Bull/BullMQ with Redis) for async tasks
- Never block request handlers with long-running work
- Idempotent job handlers — safe to retry on failure
- Dead letter queues for failed jobs

## Observability

- Structured JSON logging with context (request ID, user ID, operation)
- Request correlation IDs propagated through the call chain
- Health check endpoint: `/health` or `/api/health`
- Metrics: response times, error rates, queue depths
