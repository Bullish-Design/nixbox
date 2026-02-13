# Simplification Proposal: Replace queue + auto-spawn polling with a single worker loop

## Summary
Cairn currently splits scheduling across `TaskQueue`, orchestrator state (`active_agents`), and the `_maybe_start_agents` / `auto_spawn_loop` behavior in `cairn/orchestrator.py`. This can be reduced to one explicit worker model:

- one bounded-concurrency worker loop
- one source of truth for "pending", "running", "done"
- one transition path for each agent lifecycle edge

## What to change
1. In `cairn/orchestrator.py`, replace polling-style spawn triggering with a long-lived worker task started in `initialize()`.
2. Keep `TaskQueue` as a plain priority queue (or fold it into orchestrator entirely).
3. Gate concurrency with `asyncio.Semaphore(max_concurrent_agents)` rather than hand-managed `active_count`.
4. Convert completion handling to a single `finally` path so slots are always released.
5. Remove duplicate accounting fields where they do not influence behavior (`completed_count`, parallel counters in orchestrator).

## Why this simplifies the mental model
- Developers reason about one scheduler loop instead of queue + ad-hoc triggers.
- Concurrency safety is delegated to a battle-tested primitive (`Semaphore`).
- Fewer state-sync bugs between queue internals and orchestrator bookkeeping.

## Pros
- Lower lifecycle complexity and fewer race-condition edges.
- Easier to test deterministically (enqueue N, assert at most K running).
- Less custom scheduling code to maintain.

## Cons
- Refactor risk around task-start timing and backward compatibility of internal APIs.
- May require updates to tests that currently rely on specific queue internals.

## Good acceptance criteria
- No behavior change in visible CLI workflow (`queue`, `accept`, `reject`).
- Existing orchestration tests pass with fewer mocks of queue internals.
- Code paths for "task started" and "task completed" are each represented once.
