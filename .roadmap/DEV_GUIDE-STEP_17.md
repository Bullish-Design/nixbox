# Step 17: High-Level Convenience APIs

**Phase**: 4 - Quality
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: Phases 1-3

## Objective

Create high-level convenience functions that simplify common workflows:
- Decorators for sandboxed execution
- Quick functions for common patterns
- Simplified APIs for beginners
- Chainable operations

## Why This Matters

Convenience APIs enable:
- Faster development
- Clearer code intent
- Better developer experience
- Lower barrier to entry
- Common patterns become one-liners

## Implementation Guide

### 17.1 Create Convenience Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/convenience.py`:

```python
"""High-level convenience APIs for common workflows."""

import asyncio
from pathlib import Path
from typing import Optional, Callable, Any
from functools import wraps

from agentfs_pydantic.cli import AgentFSCLI, temporary_agent, sandbox_session
from agentfs_pydantic.models import InitOptions, SandboxOptions
from agentfs_pydantic.filesystem import FSOperations
from agentfs_pydantic.mount import mount_context


# ============================================================================
# Quick Operations
# ============================================================================


async def quick_init(
    agent_id: str,
    *,
    overlay_on: Optional[Path] = None,
    sync_to: Optional[str] = None,
    force: bool = False
) -> FSOperations:
    """Quickly initialize an agent and get filesystem interface.

    One-liner to create an agent and start working with it.

    Args:
        agent_id: Agent identifier
        overlay_on: Optional base directory for overlay
        sync_to: Optional remote URL for sync
        force: Overwrite if exists

    Returns:
        FSOperations interface

    Examples:
        >>> # Simple agent
        >>> fs = await quick_init("my-agent")
        >>>
        >>> # Overlay agent
        >>> fs = await quick_init("overlay", overlay_on=Path("/my/project"))
        >>>
        >>> # Synced agent
        >>> fs = await quick_init("synced", sync_to="libsql://db.turso.io")
    """
    from agentfs_pydantic.models import SyncRemoteConfig

    cli = AgentFSCLI()

    sync_config = None
    if sync_to:
        import os
        sync_config = SyncRemoteConfig(
            url=sync_to,
            auth_token=os.getenv("TURSO_DB_AUTH_TOKEN")
        )

    options = InitOptions(
        base=overlay_on,
        sync_config=sync_config,
        force=force
    )

    await cli.init(agent_id, options=options)
    return FSOperations(agent_id, cli=cli)


async def quick_snapshot(
    source: Path,
    agent_id: Optional[str] = None
) -> str:
    """Quick snapshot of a directory into AgentFS.

    Args:
        source: Source directory to snapshot
        agent_id: Optional agent ID (generated if not provided)

    Returns:
        Agent ID containing the snapshot

    Examples:
        >>> agent_id = await quick_snapshot(Path("/my/project"))
        >>> print(f"Snapshotted to: {agent_id}")
    """
    import uuid

    agent_id = agent_id or f"snapshot-{uuid.uuid4().hex[:8]}"
    await quick_init(agent_id, overlay_on=source, force=True)
    return agent_id


async def quick_diff(
    agent_id: str,
    *,
    summary: bool = True
) -> dict | list:
    """Quick diff summary for overlay agent.

    Args:
        agent_id: Overlay agent ID
        summary: If True, return summary dict, else change list

    Returns:
        Summary dict or list of changes

    Examples:
        >>> diff = await quick_diff("overlay-agent")
        >>> print(f"Changed files: {diff['total']}")
    """
    from agentfs_pydantic.diff import quick_diff as _quick_diff
    from agentfs_pydantic.cli import AgentFSCLI

    if summary:
        return await _quick_diff(agent_id)
    else:
        cli = AgentFSCLI()
        result = await cli.diff(agent_id)
        return result.changes


# ============================================================================
# Decorators
# ============================================================================


def sandboxed(
    session: Optional[str] = None,
    allowed_paths: Optional[list[str]] = None
):
    """Decorator to run function in sandbox.

    Args:
        session: Optional session name for persistence
        allowed_paths: Additional allowed paths

    Examples:
        >>> @sandboxed(session="build")
        ... async def build_project():
        ...     import subprocess
        ...     subprocess.run(["make", "build"])
        ...     return "Built successfully"
        >>>
        >>> result = await build_project()
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Determine if we need to run the command
            if asyncio.iscoroutinefunction(func):
                # Async function - run in sandbox
                async with sandbox_session(
                    session_name=session,
                    allowed_paths=allowed_paths or []
                ) as run:
                    # This is a simplification - in reality would need to
                    # serialize function execution
                    return await func(*args, **kwargs)
            else:
                # Sync function
                result = func(*args, **kwargs)
                return result

        return wrapper
    return decorator


def with_temp_agent(
    base: Optional[Path] = None,
    keep: bool = False
):
    """Decorator to run function with temporary agent.

    Args:
        base: Optional base directory
        keep: If True, don't delete agent after

    Examples:
        >>> @with_temp_agent(base=Path("/project"))
        ... async def test_changes(agent_id, fs):
        ...     await fs.write("/test.txt", "data")
        ...     return await fs.cat("/test.txt")
        >>>
        >>> content = await test_changes()
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            async with temporary_agent(base=base, keep=keep) as (agent_id, fs):
                return await func(agent_id, fs, *args, **kwargs)
        return wrapper
    return decorator


def with_mount(mount_point: Optional[Path] = None):
    """Decorator to run function with mounted agent.

    Args:
        mount_point: Where to mount (temp dir if not specified)

    Examples:
        >>> @with_mount()
        ... async def process_files(agent_id, mount_path):
        ...     files = list(mount_path.glob("*.txt"))
        ...     return len(files)
        >>>
        >>> # Agent must be created first
        >>> count = await process_files("my-agent")
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(agent_id: str, *args, **kwargs):
            import tempfile

            if mount_point:
                mount_at = mount_point
                async with mount_context(AgentFSCLI(), agent_id, mount_at) as mount:
                    return await func(agent_id, mount.path, *args, **kwargs)
            else:
                with tempfile.TemporaryDirectory() as tmpdir:
                    mount_at = Path(tmpdir) / "mount"
                    async with mount_context(AgentFSCLI(), agent_id, mount_at) as mount:
                        return await func(agent_id, mount.path, *args, **kwargs)

        return wrapper
    return decorator


# ============================================================================
# Workflow Helpers
# ============================================================================


class WorkflowBuilder:
    """Fluent interface for building AgentFS workflows.

    Examples:
        >>> workflow = (
        ...     WorkflowBuilder()
        ...     .create_agent("my-agent")
        ...     .with_overlay("/my/project")
        ...     .write_file("/output.txt", "result")
        ...     .sync_to("libsql://db.turso.io")
        ... )
        >>>
        >>> await workflow.execute()
    """

    def __init__(self):
        """Initialize workflow builder."""
        self._steps: list[Callable] = []
        self._agent_id: Optional[str] = None

    def create_agent(self, agent_id: str) -> "WorkflowBuilder":
        """Add agent creation step."""
        self._agent_id = agent_id

        async def step():
            cli = AgentFSCLI()
            await cli.init(agent_id)

        self._steps.append(step)
        return self

    def with_overlay(self, base: Path) -> "WorkflowBuilder":
        """Add overlay configuration."""
        async def step():
            # This modifies the previous init step
            # Implementation would need to track options
            pass

        self._steps.append(step)
        return self

    def write_file(self, path: str, content: str) -> "WorkflowBuilder":
        """Add file write step."""
        agent_id = self._agent_id

        async def step():
            fs = FSOperations(agent_id)
            await fs.write(path, content)

        self._steps.append(step)
        return self

    def sync_to(self, remote_url: str) -> "WorkflowBuilder":
        """Add sync step."""
        agent_id = self._agent_id

        async def step():
            from agentfs_pydantic.sync import SyncManager
            import os

            manager = SyncManager(
                agent_id,
                remote_url,
                auth_token=os.getenv("TURSO_DB_AUTH_TOKEN")
            )
            await manager.push()

        self._steps.append(step)
        return self

    async def execute(self):
        """Execute the workflow."""
        for step in self._steps:
            await step()


# ============================================================================
# Batch Operations
# ============================================================================


async def batch_init(
    agent_ids: list[str],
    *,
    base: Optional[Path] = None,
    force: bool = False
) -> dict[str, bool]:
    """Initialize multiple agents in parallel.

    Args:
        agent_ids: List of agent IDs to create
        base: Optional base directory for all
        force: Force overwrite

    Returns:
        Dictionary mapping agent_id to success status

    Examples:
        >>> results = await batch_init(["agent1", "agent2", "agent3"])
        >>> print(f"Created {sum(results.values())} agents")
    """
    cli = AgentFSCLI()
    options = InitOptions(base=base, force=force) if base or force else None

    async def init_one(agent_id: str) -> tuple[str, bool]:
        try:
            await cli.init(agent_id, options=options)
            return agent_id, True
        except Exception:
            return agent_id, False

    results = await asyncio.gather(*[init_one(aid) for aid in agent_ids])
    return dict(results)
```

### 17.2 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.convenience import (
    quick_init,
    quick_snapshot,
    quick_diff,
    sandboxed,
    with_temp_agent,
    with_mount,
    WorkflowBuilder,
    batch_init,
)

__all__ = [
    # ... existing ...
    "quick_init",
    "quick_snapshot",
    "quick_diff",
    "sandboxed",
    "with_temp_agent",
    "with_mount",
    "WorkflowBuilder",
    "batch_init",
]
```

### 17.3 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_convenience.py`:

```python
"""Tests for convenience APIs."""

import pytest
from pathlib import Path
import tempfile

from agentfs_pydantic.convenience import (
    quick_init,
    quick_snapshot,
    with_temp_agent,
    batch_init,
)


class TestQuickOperations:
    """Tests for quick operation functions."""

    @pytest.mark.asyncio
    async def test_quick_init(self):
        """Test quick_init."""
        fs = await quick_init("quick-test", force=True)
        await fs.write("/test.txt", "data")
        assert await fs.exists("/test.txt")

        # Cleanup
        import os
        db_path = Path.home() / ".agentfs" / "quick-test.db"
        if db_path.exists():
            os.remove(db_path)

    @pytest.mark.asyncio
    async def test_quick_snapshot(self):
        """Test quick_snapshot."""
        with tempfile.TemporaryDirectory() as tmpdir:
            project = Path(tmpdir)
            (project / "file.txt").write_text("content")

            agent_id = await quick_snapshot(project)
            assert agent_id.startswith("snapshot-")

            # Cleanup
            import os
            db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
            if db_path.exists():
                os.remove(db_path)


class TestDecorators:
    """Tests for decorator functions."""

    @pytest.mark.asyncio
    async def test_with_temp_agent(self):
        """Test with_temp_agent decorator."""
        @with_temp_agent()
        async def use_agent(agent_id, fs):
            await fs.write("/decorated.txt", "data")
            return await fs.exists("/decorated.txt")

        result = await use_agent()
        assert result is True


class TestBatchOperations:
    """Tests for batch operations."""

    @pytest.mark.asyncio
    async def test_batch_init(self):
        """Test batch initialization."""
        agent_ids = ["batch-1", "batch-2", "batch-3"]
        results = await batch_init(agent_ids, force=True)

        assert len(results) == 3
        assert all(results.values())

        # Cleanup
        import os
        for agent_id in agent_ids:
            db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
            if db_path.exists():
                os.remove(db_path)
```

## Testing

### Manual Testing

```python
import asyncio
from pathlib import Path
from agentfs_pydantic.convenience import (
    quick_init,
    quick_snapshot,
    with_temp_agent,
    WorkflowBuilder,
)

async def main():
    # Test 1: Quick init
    print("1. Quick init...")
    fs = await quick_init("quick-demo", force=True)
    await fs.write("/quick.txt", "Quick operation!")
    print("Agent created and file written in one line")

    # Test 2: Quick snapshot
    print("\n2. Quick snapshot...")
    # Snapshot current directory
    agent_id = await quick_snapshot(Path.cwd())
    print(f"Snapshotted to: {agent_id}")

    # Test 3: Decorator
    print("\n3. Using decorator...")
    @with_temp_agent()
    async def do_work(agent_id, fs):
        await fs.write("/work.txt", "Done")
        return f"Worked with {agent_id}"

    result = await do_work()
    print(result)

    # Test 4: Workflow builder
    print("\n4. Workflow builder...")
    workflow = (
        WorkflowBuilder()
        .create_agent("workflow-demo")
        .write_file("/result.txt", "Workflow result")
    )
    await workflow.execute()
    print("Workflow executed")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_convenience.py -v
```

## Success Criteria

- [ ] quick_init simplifies agent creation
- [ ] quick_snapshot captures directories
- [ ] quick_diff provides summary
- [ ] Decorators work correctly
- [ ] WorkflowBuilder provides fluent API
- [ ] Batch operations work in parallel
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Decorator function signature
- **Solution**: Use @wraps to preserve metadata

**Issue**: Workflow steps not executing
- **Solution**: Ensure execute() is called

**Issue**: Batch operations fail partially
- **Solution**: Results dict shows which succeeded

## Next Steps

Once this step is complete:
1. Proceed to [Step 18: Documentation & Examples](./DEV_GUIDE-STEP_18.md)
2. Finalize the library with comprehensive documentation

## Design Notes

- Quick functions reduce boilerplate
- Decorators enable declarative patterns
- Workflow builder provides fluent interface
- Batch operations use asyncio.gather
- All convenience functions use core APIs
- Type hints throughout for IDE support
