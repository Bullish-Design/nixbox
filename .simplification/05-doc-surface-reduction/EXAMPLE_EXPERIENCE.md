# Example Experience: Documentation Surface Reduction Simplification

## Current implementation experience

### User/developer perspective
- New contributors read `README.md`, then find overlapping but not identical details in `SPEC.md`, `CONCEPT.md`, progress docs, and skill docs.
- It's unclear which document is authoritative when details diverge.
- Maintenance updates are expensive because similar text exists in multiple places.

## Simplified implementation experience

### User/developer perspective
- Reading path is explicit:
  1. `README.md` for install/quickstart.
  2. `CONCEPT.md` for philosophy/constraints.
  3. `SPEC.md` for current architecture and contracts.
- Non-canonical docs link back to source-of-truth sections instead of duplicating content.
- Contributors spend less time reconciling narrative differences.

## Pros, cons, and implications

### Pros
- Lower documentation drift and maintenance burden.
- Faster onboarding due to clear reading order.
- Easier reviews because authoritative location is known.

### Cons
- Up-front editorial work to consolidate and prune.
- Some existing links/bookmarks may break without redirects or notes.

### Other implications
- Requires governance discipline: all architecture updates should land in canonical files first.
- Skill docs become leaner and more task-focused, improving long-term maintainability.
