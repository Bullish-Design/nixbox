# Refactoring Proposal: Split Cairn Orchestrator into Hexagonal Ports + Services

## Summary
`cairn/orchestrator.py` currently coordinates lifecycle, storage wiring, queue scheduling, workspace materialization, bin archival, and state persistence in one class. This is functional, but it forces contributors to understand many concerns simultaneously.

Refactor toward a ports-and-adapters shape:
- **Domain services**: pure lifecycle/use-case logic
- **Ports**: protocols for storage, execution, signaling, and state snapshots
- **Adapters**: AgentFS/Monty/filesystem implementations

## Why this helps
- Reduces mental load by separating business flow from infrastructure details.
- Makes behavior easier to unit test without AgentFS or filesystem setup.
- Enables alternative backends (e.g., different queue implementation) with less surgery.

## Proposed module structure
- `cairn/domain/agent_lifecycle.py`
- `cairn/domain/orchestration_service.py`
- `cairn/ports/storage.py`
- `cairn/ports/executor.py`
- `cairn/ports/state_store.py`
- `cairn/adapters/agentfs_storage.py`
- `cairn/adapters/monty_executor.py`
- `cairn/adapters/json_state_store.py`
- Keep `cairn/orchestrator.py` as composition root for backward compatibility.

## Migration sketch
1. Extract lifecycle methods (`spawn_agent`, `accept_agent`, `reject_agent`, `_run_agent`) into a domain service.
2. Replace direct references to `AgentFS`, filesystem paths, and JSON writes with port interfaces.
3. Implement existing behavior in adapters and inject into domain service.
4. Keep public CLI behavior unchanged while internals transition.

## Pros
- Better modularity and clearer dependency boundaries.
- Smaller files and less context switching during edits.
- Easier to mock/instrument individual adapters.

## Cons
- More files and abstractions initially.
- Short-term migration complexity for tests.
- Requires team alignment on architectural conventions.
