# Simplification Proposal: Merge agent lifecycle metadata into one storage mechanism

## Summary
Agent lifecycle data is currently spread across runtime memory (`active_agents`), state files, bin DB metadata, and overlay DB files. Collapse lifecycle metadata into one durable index and keep overlay DBs as pure content storage.

## What to change
1. Introduce one lifecycle store (JSONL file or one AgentFS KV namespace) used by orchestrator for queued/running/completed/rejected/accepted states.
2. Remove duplicate lifecycle writes across `persist_state()`, `bin.kv.set(...)`, and ad-hoc filesystem copies in `trash_agent`.
3. Treat `.agentfs/agent-*.db` as disposable execution artifacts with minimal metadata coupling.
4. Keep retention policy in one place (e.g., `cairn/workspace.py` or new `cairn/lifecycle.py`).

## Why this simplifies the mental model
- Developers can answer "where is agent state?" with one answer.
- Recovery logic after restart is clearer and easier to validate.
- Fewer multi-step cleanup branches.

## Pros
- Lower chance of stale/contradictory state between stores.
- Easier observability and tooling around agent history.
- Simpler restart and garbage collection behavior.

## Cons
- Migration work for existing persisted state formats.
- Need to preserve any workflow expectations around bin/history visibility.

## Good acceptance criteria
- Exactly one canonical lifecycle record per agent id.
- Restart path reconstructs runtime state only from that canonical record.
- Cleanup code path is linear and idempotent.
