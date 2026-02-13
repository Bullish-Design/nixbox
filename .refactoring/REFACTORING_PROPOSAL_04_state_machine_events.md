# Refactoring Proposal: Introduce a First-Class Agent State Machine + Event Log

## Summary
Agent transitions are currently applied ad hoc via `AgentContext.transition(...)` calls in multiple places. Add a formal state machine with allowed transitions and event emission to reduce hidden lifecycle coupling.

## Proposed changes
- Add `cairn/lifecycle/state_machine.py` with:
  - transition table (`from_state -> allowed_to_states`)
  - transition validator
  - optional side-effect hooks
- Add `AgentEvent` model and append-only event list per agent (in memory + persisted snapshot).
- Replace direct transition calls in orchestrator/signal paths with `state_machine.transition(ctx, next_state, cause=...)`.

## Why this helps
- Prevents invalid transitions from creeping in as features grow.
- Makes debugging easier via clear event trails.
- Supports future UI timelines and analytics without reworking core flow.

## Pros
- Stronger correctness guarantees.
- Better observability and debuggability.
- Easier future extension for pause/resume/cancel semantics.

## Cons
- Added complexity compared to unconstrained enum assignment.
- Event persistence format needs versioning discipline.
- Upfront effort to migrate all transition call sites.
