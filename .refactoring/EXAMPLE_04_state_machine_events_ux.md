# Example UX: State Machine + Event Log Refactor

## Scenario
A maintainer investigates why an agent ended in `ERRORED` and whether transition ordering was valid.

## Current implementation UX (today)
1. Inspect `cairn/orchestrator.py` and signal handlers for scattered `ctx.transition(...)` calls.
2. Reconstruct timeline from persisted snapshot plus logs/print output.
3. Infer whether an illegal transition occurred (e.g., skipping an expected state) by reading code paths manually.

### What this feels like
- Lightweight implementation with minimal ceremony.
- Debugging is forensic and manual.
- Hard to enforce lifecycle correctness as more transitions are added.

## Refactored implementation UX (after change)
1. Open `cairn/lifecycle/state_machine.py` transition table.
2. Use `state_machine.transition(ctx, next_state, cause=...)` everywhere.
3. Inspect append-only `AgentEvent` history to see exact transition timeline with causes.
4. Immediately detect invalid transitions via validator errors instead of latent bugs.

### What this feels like
- More structured and explicit lifecycle behavior.
- Easier operational debugging and postmortem analysis.
- Slightly higher upfront complexity for simple flows.

## Pros, cons, and implications
### Pros
- Strong correctness guarantees around legal transitions.
- Event history supports auditability, timeline UIs, and analytics.
- Transition side effects can be centralized and consistently applied.

### Cons
- Additional moving parts (validator, event schemas, persistence format).
- Versioning burden for event format over time.
- Migration may temporarily duplicate transition logic while call sites are updated.

### Implications for the library
- Improves reliability as state model expands (pause/resume/cancel).
- Creates a foundation for observability features without invasive rewrites.
- Requires disciplined governance of lifecycle and event schema changes.
