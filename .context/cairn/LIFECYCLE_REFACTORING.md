# Agent Lifecycle Refactoring

## Summary

Consolidated agent lifecycle metadata from multiple scattered storage locations into a single, unified AgentFS KV namespace. This simplifies state management, enables restart recovery, and makes the mental model clearer.

## Problem: Scattered Lifecycle State

### Before Refactoring

Agent lifecycle data was spread across multiple locations:

1. **Runtime memory (`self.active_agents`)** - Dictionary at chimera.py:42
   - In-memory only, lost on restart
   - No persistence

2. **Individual agent KV stores** - Lines 69, 86, 145-148
   - `task`: Task description
   - `generated_code`: LLM code
   - `submission`: Results JSON
   - Scattered across multiple DBs

3. **Bin DB KV** - Line 278
   - `trash:{agent_id}`: GC tracking
   - Only used for cleanup

4. **Filesystem**
   - `.agentfs/agent-{uuid}.db` files
   - No metadata about lifecycle state

### Issues

- **No canonical lifecycle state**: Can't answer "where is agent state?" with one answer
- **No state machine**: Missing queued/running/completed/rejected/accepted states
- **No restart recovery**: Lost all in-flight agents on crash/restart
- **Complex cleanup**: Multi-step process across different stores (lines 271-299)
- **Potential inconsistency**: State could diverge between stores
- **Poor observability**: Hard to track agent history and status

## Solution: Unified Lifecycle Store

### After Refactoring

All agent lifecycle metadata now lives in **one canonical location**: the `lifecycle_store` AgentFS KV namespace.

### New Architecture

```python
# Single source of truth
self.lifecycle_store = await AgentFS.open(AgentFSOptions(id="lifecycle"))

# Lifecycle record structure
@dataclass
class AgentLifecycle:
    agent_id: str
    state: AgentState  # QUEUED/RUNNING/COMPLETED/REJECTED/ACCEPTED
    task: str
    created_at: float
    updated_at: float
    generated_code: str | None
    submission_summary: str | None
    changed_files: list[str] | None
    error: str | None
```

### Key Changes

1. **Unified State Enum** (Lines 32-38)
   ```python
   class AgentState(str, Enum):
       QUEUED = "queued"
       RUNNING = "running"
       COMPLETED = "completed"
       REJECTED = "rejected"
       ACCEPTED = "accepted"
   ```

2. **Single Lifecycle Record** (Lines 41-82)
   - All metadata in one dataclass
   - JSON serialization for AgentFS KV storage
   - Timestamps for audit trail

3. **Lifecycle Management API** (Lines 151-187)
   - `create_lifecycle()`: Initialize new agent
   - `update_lifecycle()`: Update state (single write)
   - `get_lifecycle()`: Read current state
   - `delete_lifecycle()`: Purge old records

4. **Restart Recovery** (Lines 119-149)
   ```python
   async def recover_agents(self) -> None:
       """Recover agent state after restart."""
       # List all lifecycle records
       lifecycle_keys = await self.lifecycle_store.kv.list("agent:")

       for item in lifecycle_keys:
           lifecycle = AgentLifecycle.from_json(item["value"])

           # Only recover running agents
           if lifecycle.state == AgentState.RUNNING:
               if agent_db.exists():
                   agent_fs = await AgentFS.open(...)
                   self.active_agents[agent_id] = agent_fs
               else:
                   # Mark as failed
                   lifecycle.state = AgentState.REJECTED
                   await self.update_lifecycle(lifecycle)
   ```

5. **Simplified Cleanup** (Lines 456-476)
   ```python
   async def cleanup_agent(self, agent_id: str) -> None:
       """Clean up agent resources (idempotent)."""
       # 1. Close AgentFS handle
       if agent_id in self.active_agents:
           await self.active_agents[agent_id].close()
           del self.active_agents[agent_id]

       # 2. Delete DB file
       db_path = self.agentfs_dir / f"{agent_id}.db"
       if db_path.exists():
           db_path.unlink()

       # 3. Keep lifecycle record for history
       #    (purged by retention policy in gc_loop)
   ```

6. **Retention Policy** (Lines 478-504)
   - Centralized in `gc_loop()`
   - Purges old ACCEPTED/REJECTED records after 24 hours
   - Preserves recent history for debugging

## Benefits

### Clarity
- **One canonical record per agent**: `lifecycle_store.kv.get(f"agent:{agent_id}")`
- **One answer to "where is agent state?"**: The lifecycle store
- **Clear state machine**: Enum makes transitions explicit

### Reliability
- **Restart recovery**: Agents survive process crashes
- **Idempotent cleanup**: Can be called multiple times safely
- **Error tracking**: `error` field captures failure reasons

### Observability
- **Full audit trail**: `created_at` and `updated_at` timestamps
- **Historical records**: Kept until retention policy expires
- **State visibility**: Query all agents by state

### Maintainability
- **Linear cleanup path**: One function, one order
- **No state divergence**: Single write point
- **Easier testing**: Mock one store instead of many

## Migration Path

### For Existing Deployments

If you have existing agents (unlikely, as this is a new library):

1. On startup, `recover_agents()` handles missing lifecycle records gracefully
2. Old `bin.db` entries are ignored (no code reads from it)
3. New agents automatically use the unified store

### Backward Compatibility

**Note**: This is a brand new library - we do NOT care about backwards compatibility per the requirements.

All code, docs, and functionality now reflect this new unified concept.

## Code Locations

### Removed
- ~~`self.bin`~~ - No longer needed (was line 41, 55, 277-278, 288-299)
- ~~`agent_fs.kv.set("task", ...)`~~ - Now in lifecycle store (was line 69)
- ~~`agent_fs.kv.set("generated_code", ...)`~~ - Now in lifecycle store (was line 86)
- ~~`agent_fs.kv.set("submission", ...)`~~ - Now in lifecycle store (was line 145-148)
- ~~`bin.kv.set(f"trash:{agent_id}", ...)`~~ - Replaced by lifecycle state (was line 278)

### Added
- `AgentState` enum (lines 32-38)
- `AgentLifecycle` dataclass (lines 41-82)
- `self.lifecycle_store` (line 96)
- `recover_agents()` (lines 119-149)
- `create_lifecycle()` (lines 151-161)
- `update_lifecycle()` (lines 163-169)
- `get_lifecycle()` (lines 171-180)
- `delete_lifecycle()` (lines 182-187)

### Modified
- `spawn_agentlet()` - Now creates lifecycle first (line 194)
- `run_agentlet()` - Updates lifecycle states (lines 208-261)
- `submit_result()` - Updates lifecycle, not agent KV (lines 298-307)
- `accept_agentlet()` - Uses lifecycle API (lines 404-438)
- `reject_agentlet()` - Uses lifecycle API (lines 440-454)
- `cleanup_agent()` - Simplified, linear (lines 456-476)
- `gc_loop()` - Now uses lifecycle store (lines 478-504)

## Testing Considerations

### Unit Tests
```python
async def test_lifecycle_transitions():
    # Create agent
    lifecycle = await orchestrator.create_lifecycle("test-001", "task")
    assert lifecycle.state == AgentState.QUEUED

    # Transition to running
    lifecycle.state = AgentState.RUNNING
    await orchestrator.update_lifecycle(lifecycle)

    # Verify persistence
    retrieved = await orchestrator.get_lifecycle("test-001")
    assert retrieved.state == AgentState.RUNNING
```

### Integration Tests
```python
async def test_restart_recovery():
    # Spawn agent
    agent_id = await orchestrator.spawn_agentlet("task")

    # Simulate crash by creating new orchestrator
    orchestrator2 = ChimeraOrchestrator()
    await orchestrator2.initialize()

    # Verify recovery
    assert agent_id in orchestrator2.active_agents
```

## Acceptance Criteria

✅ Exactly one canonical lifecycle record per agent
✅ Restart path reconstructs runtime state from lifecycle store
✅ Cleanup code path is linear and idempotent
✅ No duplicate writes across multiple stores
✅ State transitions are explicit and trackable
✅ Old records are automatically purged by retention policy

## Future Enhancements

Possible future improvements (out of scope for this refactoring):

1. **Persistence to remote store**: Sync lifecycle to Turso for distributed deployments
2. **State machine validation**: Enforce valid state transitions
3. **Metrics**: Track agent success rate, average duration, etc.
4. **Query API**: List agents by state, filter by time range
5. **Event hooks**: Trigger callbacks on state transitions

## Summary

This refactoring demonstrates the value of **consolidating scattered state into a single source of truth**. The mental model is now:

- **Lifecycle store**: All agent metadata and state
- **Agent DB files**: Pure execution artifacts (overlays)
- **Runtime cache**: Performance optimization only

Recovery, cleanup, and observability are all simplified as a result.
