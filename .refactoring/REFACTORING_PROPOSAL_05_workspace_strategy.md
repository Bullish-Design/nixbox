# Refactoring Proposal: Add Workspace Materialization Strategies

## Summary
`cairn/workspace.py` currently uses a full recursive copy approach for stable + overlay into `~/.cairn/workspaces/<agent_id>`. This is simple but tightly couples workspace behavior to one strategy.

Introduce strategy interfaces so materialization can evolve without touching orchestrator code.

## Candidate strategies
1. **FullCopyStrategy** (current behavior, default)
2. **IncrementalSyncStrategy** (copy only changed paths from overlay + manifest)
3. **HardlinkStableStrategy** (hardlink stable files where possible, copy overlay writes)

## Proposed structure
- `cairn/workspace/strategies.py`
- `cairn/workspace/materializer.py`
- `cairn/workspace/manifest.py` (track copied paths/checksums/timestamps)

Keep public method `materialize(agent_id, agent_fs)` intact while delegating internally by config.

## Why this helps
- Reduces coupling between orchestrator and filesystem implementation details.
- Makes performance tradeoffs configurable per environment.
- Simplifies experimentation with preview workspace behavior.

## Pros
- Better composability and future-proofing.
- Cleaner place to optimize I/O without cross-cutting edits.
- Supports different developer workflows and storage constraints.

## Cons
- More code surface and strategy testing burden.
- Hardlink/incremental modes add platform-specific edge cases.
- Requires clear fallback behavior when strategy assumptions fail.
