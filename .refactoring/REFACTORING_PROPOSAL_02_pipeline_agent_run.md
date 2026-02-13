# Refactoring Proposal: Convert Agent Run Flow into a Composable Pipeline

## Summary
The `_run_agent` method in `cairn/orchestrator.py` mixes state transitions with step logic (generate, validate, execute, submit, materialize). Converting this into explicit pipeline stages would make behavior easier to reason about and extend.

## Proposed design
Introduce a stage pipeline abstraction:
- `GenerateCodeStage`
- `ValidateCodeStage`
- `ExecuteStage`
- `CaptureSubmissionStage`
- `MaterializeWorkspaceStage`
- `FinalizeReviewStage`

Each stage:
- accepts/returns a shared `AgentRunContext`
- declares preconditions and failure semantics
- records structured telemetry (duration/error)

## Implementation location
- `cairn/pipeline/context.py`
- `cairn/pipeline/stages/*.py`
- `cairn/pipeline/runner.py`
- `cairn/orchestrator.py` uses `PipelineRunner.run(ctx)` instead of inline flow.

## Why this helps
- Keeps lifecycle logic linear and explicit.
- New behavior (e.g., static checks, test stage, auto-fix retry) becomes plug-and-play.
- Improves observability because each stage can emit consistent metrics.

## Pros
- High composability for future features.
- Easier targeted testing per stage.
- Lower risk when changing one step.

## Cons
- Slight boilerplate for stage classes/context models.
- Possible over-abstraction if project stays very small.
- Requires careful error propagation conventions.
