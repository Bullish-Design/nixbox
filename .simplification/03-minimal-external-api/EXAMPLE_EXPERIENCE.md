# Example Experience: Minimal External API Simplification

## Current implementation experience

### User perspective (agent behavior)
- Agents may use many helper tools (`search_content`, wrappers, specialized helpers).
- Some tasks are convenient, but behavior can feel uneven when tools differ in constraints/performance.
- Security expectations are harder to reason about because tool surface is broad.

### Developer perspective
- Prompt/tool docs are longer and easier to drift.
- Changes to one helper can have hidden impact on generated code relying on convenience behavior.
- Validation and guardrails are spread across more code paths.

## Simplified implementation experience

### User perspective
- Agent capabilities are predictable: small core primitives (`read_file`, `write_file`, `list_dir`, `submit_result`, optional `log`).
- Complex behavior is composed explicitly from simple operations.
- Fewer surprises from tool-specific edge cases.

### Developer perspective
- Core contract is concise and stable.
- Optional helpers are clearly non-core and can evolve independently.
- Security controls can be concentrated on a narrower boundary.

## Pros, cons, and implications

### Pros
- Smaller trusted surface and easier hardening.
- Simpler onboarding and documentation.
- Less prompt drift from reducing tool catalog size.

### Cons
- Some workflows become more verbose or slower without convenience APIs.
- Prompt templates and tests need updates to stop referencing removed helpers.

### Other implications
- Better portability across environments because fewer custom primitives are required.
- Opportunity to define versioned "core contract" compatibility guarantees.
