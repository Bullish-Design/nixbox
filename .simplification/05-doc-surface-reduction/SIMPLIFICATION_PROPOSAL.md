# Simplification Proposal: Reduce architecture/doc duplication to one canonical source per topic

## Summary
Nixbox/Cairn currently spreads architecture guidance across `README.md`, `CONCEPT.md`, `SPEC.md`, progress files, and skill docs. Consolidate docs so each topic has one canonical source and others become concise pointers.

## What to change
1. Assign canonical ownership:
   - `CONCEPT.md` for philosophy and constraints
   - `SPEC.md` for current architecture and runtime contracts
   - `README.md` for install + quickstart only
2. Convert overlapping sections in README/spec/progress docs into links instead of repeated prose.
3. Archive or delete stale stage/progress files once merged into canonical docs.
4. In `.agent/skills/*`, keep only task-specific workflows and reference canonical docs for architecture.

## Why this simplifies the mental model
- Contributors don’t have to reconcile multiple, partially diverging narratives.
- Lower maintenance burden when APIs change.
- Easier onboarding path: read in known order, no guesswork.

## Pros
- Less documentation drift.
- Faster contributor ramp-up.
- Clear distinction between "how it works" vs "how to use it".

## Cons
- One-time editorial effort.
- Existing deep links into non-canonical docs may need redirects/notes.

## Good acceptance criteria
- Each major topic has one authoritative file.
- Cross-doc duplication is replaced by links.
- New contributor reading order is explicit and short.
