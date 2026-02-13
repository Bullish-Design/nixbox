# Example UX: External Functions Toolset Decomposition Refactor

## Scenario
A developer needs to improve `search_content` performance without affecting submission or LLM helpers.

## Current implementation UX (today)
1. Open `cairn/external_functions.py`.
2. Navigate a large class containing path validation, file IO, directory search, regex search, LLM calls, logging, and submission persistence.
3. Update `search_content` and confirm no side effects in unrelated methods.
4. Re-run broad tests because all tools are bundled in one implementation.

### What this feels like
- Convenient single location initially.
- File grows into a mixed-responsibility hotspot.
- Risky changes: unrelated behaviors can be unintentionally coupled.

## Refactored implementation UX (after change)
1. Open `cairn/tools/search_toolset.py` and change search strategy there.
2. Reuse shared path checks from `cairn/tools/path_guard.py`.
3. Ensure registry wiring in `cairn/tools/registry.py` still exports expected Monty-callable functions.
4. Test only search toolset behavior plus one registry integration test.

### What this feels like
- Slightly more navigation across modules.
- Clear ownership boundaries for each capability.
- Easier targeted optimization without touching unrelated LLM/submission code.

## Pros, cons, and implications
### Pros
- Better separation of concerns and clearer code ownership.
- Independent testing and optimization by tool family.
- Runtime profiles can expose only required toolsets.

### Cons
- More dependency wiring at construction time.
- Traceability across registry + toolset modules adds mild indirection.
- Refactor requires carefully preserving existing function signatures for sandbox compatibility.

### Implications for the library
- Enables modular tool ecosystems (core vs optional tools).
- Supports future reuse of toolsets outside orchestrator contexts.
- Needs robust compatibility tests to ensure function map stability.
