# Example Experience: Storage Lifecycle Simplification

## Current implementation experience

### User perspective
- After restarts or cleanup events, users may occasionally see confusing historical state (e.g., task appears completed in one place but stale elsewhere).
- Operational tooling must inspect multiple stores to answer simple lifecycle questions.

### Developer perspective
- Lifecycle data exists in runtime memory, state files, bin metadata, and overlay DB artifacts.
- Debugging inconsistencies means correlating writes across multiple persistence paths.
- Cleanup (`trash_agent` and related flows) has branching logic with more failure modes.

## Simplified implementation experience

### User perspective
- One canonical lifecycle index is the source of truth for task state.
- Restart behavior is more predictable because orchestration reconstructs state from one durable record.
- History/retention behavior is easier to explain.

### Developer perspective
- Lifecycle transitions are written once to one store.
- Overlay DB files are treated as disposable execution artifacts, not lifecycle authorities.
- Cleanup path is linear and idempotent.

## Pros, cons, and implications

### Pros
- Reduced stale/contradictory state risk.
- Clearer operational observability and recovery.
- Simpler garbage collection and retention enforcement.

### Cons
- Migration effort for existing persisted data formats.
- Need to preserve expected UX around existing bin/history tooling.

### Other implications
- Canonical store schema becomes critical and should be versioned.
- Incident-response playbooks become shorter because state lookup has one path.
