# Simplification Proposal: Unify inbound control paths into one command ingress

## Summary
Cairn behavior is controlled through multiple ingress surfaces (CLI operations, signal files, and orchestrator-internal calls). Consolidate these into one command ingestion boundary to shrink cross-module coupling.

## What to change
1. Define a single command envelope type (e.g. `CairnCommand`) in `cairn/signals.py` or a new `cairn/commands.py`.
2. Route all external actions (`queue`, `accept`, `reject`, status queries) through that envelope.
3. Keep file-based signals as an adapter only (parse file -> command envelope -> submit).
4. Keep CLI as an adapter only (CLI args -> command envelope -> submit).
5. Ensure orchestrator consumes only command objects, not transport details.

## Why this simplifies the mental model
- One conceptual API for "how Cairn is controlled".
- Transport details (signal file vs CLI) become implementation details.
- Easier future removal of file-polling without touching orchestrator behavior.

## Pros
- Cleaner module boundaries (`cli` and `signals` become thin adapters).
- Fewer special cases when adding new actions.
- Better testability of command handling independent of transport.

## Cons
- Initial migration touches several modules at once.
- Existing ad-hoc tooling that writes signal files may need compatibility adapter retention.

## Good acceptance criteria
- Each command type has one parser and one handler.
- `cairn/orchestrator.py` no longer needs to know where a command came from.
- File signal transport can be disabled in tests without changing command semantics.
