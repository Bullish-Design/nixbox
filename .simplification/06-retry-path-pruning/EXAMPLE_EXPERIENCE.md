# Example Experience: Retry Path Pruning Simplification

## Current implementation experience

### User perspective
- Retry behavior can be hard to predict from outside because multiple abstractions (sync/async/class-based strategies) may be involved.
- Error logs may reflect framework-level retry objects more than call-site intent.

### Developer perspective
- Retry logic is spread across class hierarchy and variants.
- Understanding "what retries here and why" requires tracing through generic abstractions.
- Tests may target retry internals instead of externally meaningful behavior.

## Simplified implementation experience

### User perspective
- Retries are more consistent across orchestration/execution paths.
- Logging can clearly show attempt count, delays, and final failure context.

### Developer perspective
- One primitive (`retry_async(...)`) handles common retry semantics.
- Domain-specific flows (e.g., code generation feedback loops) keep policy at call sites.
- Tests focus on behavior of public execution paths, not retry class plumbing.

## Pros, cons, and implications

### Pros
- Less indirection and easier debugging.
- Smaller API surface to maintain.
- Clearer ownership of retry policy decisions.

### Cons
- Reduced out-of-the-box extensibility for many heterogeneous retry strategies.
- Short-term churn where code/tests depend on existing retry classes.

### Other implications
- Better observability if standardized log fields are included in `retry_async`.
- Future complexity should be reintroduced only with concrete use cases.
