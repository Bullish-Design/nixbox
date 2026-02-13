# Example UX: Hexagonal Orchestrator Refactor

## Scenario
A developer needs to add a new persistence backend for orchestrator state snapshots.

## Current implementation UX (today)
1. Open `cairn/orchestrator.py`.
2. Search for `persist_state`.
3. Realize snapshot writing, queue metrics, agent transition logic, and lifecycle orchestration all live in one class.
4. Edit persistence logic in-place and thread the change through methods like `_run_agent`, `spawn_agent`, `trash_agent`, and transition helper closures.
5. Run through several integration paths because storage and lifecycle are tightly coupled.

### What this feels like
- Fast for tiny edits.
- High context switching: one file contains orchestration + storage + materialization wiring.
- Easy to accidentally impact unrelated flow (queue scheduling, state transitions, cleanup).

## Refactored implementation UX (after change)
1. Open composition root (`cairn/orchestrator.py`) to see dependency wiring.
2. Implement or modify a dedicated adapter in `cairn/adapters/json_state_store.py` (or a new backend adapter).
3. Keep orchestration behavior in `cairn/domain/orchestration_service.py` unchanged, because it talks to a `StateStorePort` interface.
4. Add focused tests for the adapter and focused tests for domain service behavior with a fake state store.

### What this feels like
- Slightly more setup (interfaces + adapter registration).
- Much lower risk when changing persistence details.
- Easier to reason about since domain logic and infrastructure are separated.

## Pros, cons, and implications
### Pros
- Better architectural clarity: core lifecycle rules stop depending on filesystem/AgentFS specifics.
- Testability improves because ports can be mocked without heavy initialization.
- Future backends (SQLite, remote state service) can be introduced with less invasive edits.

### Cons
- More abstractions to learn (ports/adapters/services).
- Initial migration cost is non-trivial: method extraction and dependency injection updates.
- Debugging may involve hopping across more files.

### Implications for the library
- Public API can stay stable while internals become more extensible.
- Team conventions matter more (where domain logic lives, naming for ports/adapters).
- Documentation should include architecture diagrams to prevent “too many layers” confusion.
