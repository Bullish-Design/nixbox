# Refactoring Proposal: Break External Functions into Toolset Modules

## Summary
`cairn/external_functions.py` currently holds protocol definitions, path validation, file operations, search, LLM calls, and submission handling in one implementation class. This can be split into composable toolsets with shared guards.

## Proposed decomposition
- `cairn/tools/path_guard.py` (normalize/validate paths)
- `cairn/tools/files_toolset.py` (`read_file`, `write_file`, `list_dir`, `file_exists`)
- `cairn/tools/search_toolset.py` (`search_files`, `search_content`)
- `cairn/tools/llm_toolset.py` (`ask_llm`)
- `cairn/tools/submission_toolset.py` (`submit_result`, `log`)
- `cairn/tools/registry.py` (build exported function map for Monty)

## Why this helps
- Keeps each toolset focused and independently testable.
- Makes it easier to swap search strategy (AgentFS walk vs materialized ripgrep) without touching unrelated code.
- Reduces risk of broad regressions in a monolithic tools file.

## Pros
- Cleaner ownership boundaries.
- Better reuse between orchestrator and future standalone agents.
- Facilitates optional tool availability by runtime profile.

## Cons
- More constructor wiring/injection points.
- Existing tests need reorganization around new modules.
- Slightly more indirection when tracing call paths.
