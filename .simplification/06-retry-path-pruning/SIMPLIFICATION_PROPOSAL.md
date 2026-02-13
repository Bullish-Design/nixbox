# Simplification Proposal: Prune generic retry abstractions to one execution-focused utility

## Summary
`cairn/retry.py` contains broad retry abstractions (`RetryStrategy`, sync/async variants, `CodeGenerationRetry`) that appear more general than current needs. Replace with one focused async retry helper for orchestration/execution flows.

## What to change
1. Replace class-based generic retry hierarchy with a small function-level API:
   - `retry_async(operation, *, attempts, delay_policy, retry_on)`
2. Inline or remove sync retry path unless there is a real synchronous caller.
3. Keep code-generation-specific feedback retry as a thin caller-level loop in `cairn/code_generator.py` (not a subclass).
4. Update tests to assert behavior through public call sites, not retry internals.

## Why this simplifies the mental model
- One retry primitive is easier to reason about than multiple classes and modes.
- Avoids pseudo-framework patterns before they are needed.
- Keeps domain logic near call sites.

## Pros
- Less indirection.
- Lower API surface and fewer extension points to maintain.
- Clearer tracing/debugging of retries in logs.

## Cons
- Reduced extensibility if many heterogeneous retry policies are added later.
- Minor churn for tests built around class types.

## Good acceptance criteria
- Retries in execution/generation paths behave the same or better.
- No unused retry abstractions remain.
- Logging includes attempt count and final failure context.
