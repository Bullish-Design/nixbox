# Example UX: Pipeline-Based Agent Run Refactor

## Scenario
A developer wants to add a new pre-execution static analysis step before running generated code.

## Current implementation UX (today)
1. Open `_run_agent` in `cairn/orchestrator.py`.
2. Find the linear flow that does generation, validation, execution, submission capture, workspace materialization, and final transition.
3. Insert static analysis logic between existing calls.
4. Manually align state transitions and error handling with existing `try/except/finally` behavior.

### What this feels like
- Direct and simple for one-off edits.
- Fragile when inserting new behavior: easy to break transition ordering or duplicate error paths.
- Hard to test one step in isolation without invoking most of `_run_agent`.

## Refactored implementation UX (after change)
1. Create `StaticAnalysisStage` in `cairn/pipeline/stages/`.
2. Define stage preconditions, output shape, and failure semantics against `AgentRunContext`.
3. Register it in `cairn/pipeline/runner.py` between validate and execute.
4. Add stage-level tests that assert success/failure behavior independently.

### What this feels like
- More boilerplate per stage.
- Clear extension point for new behavior.
- Observability is cleaner because timing/error reporting can be standardized per stage.

## Pros, cons, and implications
### Pros
- Composable flow makes experimentation safer (retry stage, optional stage, feature-flagged stage).
- Smaller units are easier to test and review.
- Better telemetry model: per-stage metrics become straightforward.

### Cons
- Increased object/model overhead (context objects, stage interfaces, runner orchestration).
- Requires strict conventions for context mutation and error propagation.
- Can feel heavy if the run flow remains very small.

### Implications for the library
- Encourages plugin-like evolution of execution flow.
- Makes long-term maintenance easier when run complexity grows.
- Requires migration discipline so old inline flow doesn’t coexist with stage logic.
