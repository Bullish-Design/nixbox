# Example UX: Workspace Materialization Strategy Refactor

## Scenario
A team with large repositories wants faster workspace previews and less disk usage.

## Current implementation UX (today)
1. Use `WorkspaceMaterializer.materialize(agent_id, agent_fs)` in `cairn/workspace.py`.
2. Every run does a full recursive copy of stable layer, then overlay layer.
3. If performance is poor, optimization requires editing the same concrete implementation that orchestrator depends on directly.

### What this feels like
- Predictable behavior and simple mental model.
- Expensive on large trees.
- Hard to experiment with alternative copy strategies safely.

## Refactored implementation UX (after change)
1. Keep calling `materialize(agent_id, agent_fs)` from orchestrator.
2. Configure strategy (`FullCopyStrategy`, `IncrementalSyncStrategy`, or `HardlinkStableStrategy`) in `cairn/workspace/materializer.py`.
3. Use `cairn/workspace/manifest.py` to track copied paths/checksums for incremental decisions.
4. Fall back to full copy automatically when strategy assumptions fail.

### What this feels like
- Same top-level API for callers.
- Better performance tuning options per environment.
- Slightly more complexity to understand strategy behavior and fallbacks.

## Pros, cons, and implications
### Pros
- Configurable I/O tradeoffs for different repository sizes and filesystems.
- Cleaner experimentation path without changing orchestration logic.
- Better long-term performance evolution.

### Cons
- Strategy matrix increases testing burden.
- Hardlink behavior can be platform/FS dependent.
- Incremental sync correctness depends on robust manifests and invalidation rules.

### Implications for the library
- Opens path for policy-based workspace behavior (speed vs compatibility).
- Requires strong defaults and diagnostics to avoid confusing users.
- Needs explicit documentation about strategy guarantees and fallback semantics.
