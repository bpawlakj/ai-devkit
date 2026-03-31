---
applyTo: "**/*.ts,**/*.js,**/package.json,**/tsconfig.json"
---

# Node.js Backend Standards

## API Design
- RESTful resource-based URLs. Repository pattern for data, service layer for logic, thin controllers.

## Database
- Selective column queries (no `SELECT *`). Prevent N+1 with batch fetching. Connection pooling. Transactions for multi-step mutations.

## Caching
- Redis cache-aside pattern. TTL-based invalidation. Descriptive, versioned cache keys.

## Error Handling
- Centralized error handler middleware. Custom error classes with HTTP status codes.
- Retry with exponential backoff for transient failures. Never expose internals in responses.

## Security
- JWT verification middleware. Role-based access control. Rate limiting.
- Validate all input at API boundaries (Zod, Joi). Sanitize user input.

## Background Jobs
- Queue patterns (Bull/BullMQ). Never block request handlers. Idempotent handlers. Dead letter queues.

## Observability
- Structured JSON logging with request correlation IDs. Health check endpoint.
