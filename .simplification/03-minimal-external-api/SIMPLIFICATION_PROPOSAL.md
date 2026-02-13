# Simplification Proposal: Shrink the Monty external function surface to a strict core

## Summary
`cairn/external_functions.py` currently exposes a broad, partly overlapping API (`read_file`, `write_file`, `list_dir`, `search_files`, `search_content`, `ask_llm`, etc.). Trim to a strict core and move non-essential helpers to optional utilities.

## What to change
1. Define a "core external contract" for agent execution in `cairn/external_functions.py`:
   - `read_file`
   - `write_file`
   - `list_dir`
   - `submit_result`
   - optional `log`
2. Move expensive or complex operations (`search_content`, glob walker behavior, extra wrappers) behind optional helper modules.
3. Keep agent prompt/code generation aligned to only the core contract.
4. Update tests to verify only core contract as required behavior.

## Why this simplifies the mental model
- Fewer tools for agents means fewer semantics to remember and secure.
- Smaller trusted boundary between Monty code and host runtime.
- Encourages compositional agent behavior (build from primitives) over ever-growing toolset.

## Pros
- Reduced security and maintenance surface area.
- Easier documentation and onboarding.
- Less coupling to implementation details (e.g., current search strategy).

## Cons
- Some tasks may become a bit slower/wordier in agent code due to fewer convenience APIs.
- Requires prompt-template updates to avoid referencing removed helpers.

## Good acceptance criteria
- Core functions are fully documented and stable.
- Non-core helpers are clearly marked optional/experimental.
- Security validation and size/path guards exist in one shared path.
