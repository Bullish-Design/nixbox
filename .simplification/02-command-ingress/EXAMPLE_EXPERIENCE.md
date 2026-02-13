# Example Experience: Unified Command Ingress Simplification

## Current implementation experience

### User perspective
- A user can control Cairn via CLI and file-based signals.
- Similar operations may behave slightly differently depending on ingress path (argument parsing rules, error messages, timing).
- Troubleshooting "why command X worked from CLI but not signal file" can be confusing.

### Developer perspective
- Adding a new command may require changes in multiple places:
  - CLI argument parser
  - signal-file parsing
  - orchestrator entry handling
- Transport concerns leak into business logic, so command semantics are harder to keep consistent.

## Simplified implementation experience

### User perspective
- Every action maps to the same command object shape and handler path.
- CLI and signal-file adapters differ only in input translation; semantics are consistent.
- Error reporting and validation become more uniform across entry points.

### Developer perspective
- New command workflow:
  1. Add command type to `CairnCommand` envelope.
  2. Implement/extend one handler.
  3. Update adapters (CLI/signal) to emit envelope.
- Orchestrator no longer cares where commands originated.

## Pros, cons, and implications

### Pros
- Cleaner boundaries and lower coupling.
- Better command-level testability independent of transport.
- Easier future transport changes (remove file polling, add RPC, etc.).

### Cons
- Initial migration is cross-cutting and may be noisy.
- Legacy tooling writing raw signal files may need a compatibility adapter.

### Other implications
- Better audit/logging opportunities: one canonical command stream.
- Potentially easier permissions model because validation can be centralized.
