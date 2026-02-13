# Example Experience: Single Agent Worker Simplification

## Current implementation experience

### User perspective (CLI)
1. User queues 10 tasks with `cairn queue ...`.
2. Some tasks start quickly, others remain pending longer than expected.
3. Running `cairn status` may briefly show counts that feel inconsistent during handoff windows (queue updated, worker-start bookkeeping catches up slightly later).
4. If a task errors at startup, users may see delayed slot reuse because lifecycle updates and spawn triggers are spread across multiple paths.

### Developer perspective
- To debug "why didn't this task start?", developer checks:
  - `TaskQueue` internals
  - orchestrator `active_agents` state
  - `_maybe_start_agents`
  - `auto_spawn_loop`
- Task transitions (`pending -> running -> done`) are represented in several locations, so race-condition debugging involves multiple call chains.

## Simplified implementation experience

### User perspective (CLI)
1. User queues 10 tasks.
2. Exactly up to `max_concurrent_agents` start immediately.
3. As each task completes, the next task starts predictably.
4. `status` output reflects one canonical transition path, reducing transient confusion.

### Developer perspective
- There is one long-lived worker loop and one concurrency gate (`asyncio.Semaphore`).
- Debugging starts in one place: worker dequeue/start/finally-release flow.
- Completion guarantees are simpler because slot release happens in one `finally` block.

## Pros, cons, and implications

### Pros
- Lower scheduler complexity and fewer lifecycle edge cases.
- Easier deterministic tests around queue depth and concurrency limits.
- Faster incident debugging because task startup/completion logic is centralized.

### Cons
- Refactor touches timing-sensitive orchestration code.
- Existing tests that mock internal spawn triggers may need rewrites.

### Other implications
- Metrics/telemetry names may change as duplicate counters are removed.
- Internal extension points for custom spawn behavior become narrower (usually good, but notable).
