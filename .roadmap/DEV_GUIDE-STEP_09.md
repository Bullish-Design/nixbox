# Step 9: Context Managers for Resources

**Phase**: 2 - Essential
**Difficulty**: Medium
**Estimated Time**: 2-3 hours
**Prerequisites**: Steps 6-8

## Objective

Implement comprehensive context managers for all resource types:
- AgentFS lifecycle (init/cleanup)
- Mount/unmount automation
- Server start/stop automation
- Temporary agents
- RAII pattern throughout

## Why This Matters

Context managers provide:
- Automatic resource cleanup
- Prevention of resource leaks
- Pythonic RAII patterns
- Simpler, safer code for common patterns

## Implementation Guide

### 9.1 Create Temporary Agent Context

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional
import uuid


@asynccontextmanager
async def temporary_agent(
    cli: Optional[AgentFSCLI] = None,
    *,
    base: Optional[Path] = None,
    keep: bool = False,
    prefix: str = "temp"
):
    """Create a temporary AgentFS instance.

    Agent is automatically cleaned up on exit unless keep=True.

    Args:
        cli: Optional CLI instance
        base: Optional base directory for overlay
        keep: If True, keep the database after exit
        prefix: Prefix for generated agent ID

    Yields:
        Tuple of (agent_id, FSOperations)

    Examples:
        >>> # Auto-cleanup agent
        >>> async with temporary_agent() as (agent_id, fs):
        ...     await fs.write("/test.txt", "data")
        ...     # Agent deleted on exit
        >>>
        >>> # Keep agent after exit
        >>> async with temporary_agent(keep=True) as (agent_id, fs):
        ...     await fs.write("/data.txt", "important")
        ...     print(f"Agent saved: {agent_id}")
    """
    from agentfs_pydantic.models import InitOptions
    from agentfs_pydantic.filesystem import FSOperations

    cli = cli or AgentFSCLI()
    agent_id = f"{prefix}-{uuid.uuid4().hex[:8]}"

    # Initialize agent
    options = InitOptions(base=base) if base else None
    await cli.init(agent_id, options=options)

    try:
        # Yield agent_id and filesystem interface
        fs = FSOperations(agent_id, cli=cli)
        yield agent_id, fs
    finally:
        # Cleanup unless keep=True
        if not keep:
            import os
            db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
            if db_path.exists():
                try:
                    os.remove(db_path)
                except Exception:
                    pass  # Best effort cleanup


@asynccontextmanager
async def sandbox_session(
    cli: Optional[AgentFSCLI] = None,
    *,
    session_name: Optional[str] = None,
    allowed_paths: list[str] | None = None
):
    """Create a sandbox session context.

    Args:
        cli: Optional CLI instance
        session_name: Optional session name (generated if not provided)
        allowed_paths: Additional allowed paths for sandbox

    Yields:
        Function to run commands in sandbox

    Examples:
        >>> async with sandbox_session(session_name="build") as run:
        ...     result = await run(["make", "build"])
        ...     assert result.success
    """
    from agentfs_pydantic.models import SandboxOptions

    cli = cli or AgentFSCLI()
    session = session_name or f"sandbox-{uuid.uuid4().hex[:8]}"

    options = SandboxOptions(
        session=session,
        allowed_paths=allowed_paths or []
    )

    async def run_command(command: list[str]):
        """Run command in this sandbox session."""
        return await cli.run(command, options=options)

    yield run_command
```

### 9.2 Enhanced Mount Context Manager

Update `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/mount.py`:

```python
from typing import AsyncIterator


class MountContext:
    """Enhanced mount context manager with error handling."""

    # ... existing __init__ ...

    async def __aenter__(self) -> "MountContext":
        """Mount the filesystem with error handling."""
        from agentfs_pydantic.exceptions import MountError

        try:
            self._mount_info = await self.cli.mount(
                self.agent_id,
                self.mount_point,
                options=self.options
            )
            return self
        except Exception as e:
            raise MountError(
                f"Failed to mount {self.agent_id}",
                mount_point=str(self.mount_point),
                reason=str(e)
            ) from e

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Unmount with error suppression."""
        if self._mount_info:
            try:
                await self.cli.unmount(self.mount_point)
            except Exception:
                # Suppress unmount errors during cleanup
                pass
        return False

    async def remount(self):
        """Remount the filesystem (unmount then mount)."""
        await self.cli.unmount(self.mount_point)
        self._mount_info = await self.cli.mount(
            self.agent_id,
            self.mount_point,
            options=self.options
        )
```

### 9.3 Create Combined Workflow Contexts

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/contexts.py`:

```python
"""High-level context managers for common workflows."""

from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from agentfs_pydantic.cli import AgentFSCLI, temporary_agent
from agentfs_pydantic.mount import mount_context
from agentfs_pydantic.models import InitOptions, MountOptions


@asynccontextmanager
async def mounted_agent(
    agent_id: str,
    mount_point: Path,
    *,
    cli: Optional[AgentFSCLI] = None,
    mount_options: Optional[MountOptions] = None
):
    """Context manager for using an agent with mounted filesystem.

    Args:
        agent_id: Agent to mount
        mount_point: Where to mount
        cli: Optional CLI instance
        mount_options: Mount configuration

    Yields:
        Path to mounted filesystem

    Examples:
        >>> async with mounted_agent("my-agent", Path("/tmp/mount")) as path:
        ...     files = list(path.glob("*.txt"))
        ...     for f in files:
        ...         print(f.read_text())
    """
    cli = cli or AgentFSCLI()

    async with mount_context(cli, agent_id, mount_point, options=mount_options) as mount:
        yield mount.path


@asynccontextmanager
async def temporary_mounted_agent(
    base: Optional[Path] = None,
    *,
    cli: Optional[AgentFSCLI] = None,
    mount_options: Optional[MountOptions] = None
):
    """Create and mount a temporary agent.

    Combines temporary_agent and mount_context for one-liner usage.

    Args:
        base: Optional base directory for overlay
        cli: Optional CLI instance
        mount_options: Mount configuration

    Yields:
        Tuple of (mounted_path, agent_id)

    Examples:
        >>> async with temporary_mounted_agent(base=Path("/project")) as (path, agent_id):
        ...     # Work with mounted filesystem
        ...     (path / "output.txt").write_text("result")
        ...     # Agent and mount auto-cleaned
    """
    import tempfile

    cli = cli or AgentFSCLI()

    async with temporary_agent(cli=cli, base=base) as (agent_id, fs):
        with tempfile.TemporaryDirectory() as tmpdir:
            mount_point = Path(tmpdir) / "mount"

            async with mount_context(
                cli,
                agent_id,
                mount_point,
                options=mount_options
            ) as mount:
                yield mount.path, agent_id


@asynccontextmanager
async def overlay_workspace(
    project_path: Path,
    *,
    cli: Optional[AgentFSCLI] = None,
    mount: bool = True
):
    """Create an overlay workspace on top of a project.

    Perfect for testing changes without affecting the original project.

    Args:
        project_path: Project directory to overlay
        cli: Optional CLI instance
        mount: If True, also mount the filesystem

    Yields:
        If mount=True: mounted Path
        If mount=False: (agent_id, FSOperations)

    Examples:
        >>> # With mounting
        >>> async with overlay_workspace(Path("/my/project")) as workspace:
        ...     # workspace is a Path to mounted overlay
        ...     (workspace / "test.txt").write_text("test changes")
        ...     # Changes don't affect /my/project
        >>>
        >>> # Without mounting
        >>> async with overlay_workspace(Path("/my/project"), mount=False) as (agent_id, fs):
        ...     await fs.write("/test.txt", "test changes")
    """
    cli = cli or AgentFSCLI()

    async with temporary_agent(cli=cli, base=project_path) as (agent_id, fs):
        if mount:
            import tempfile
            with tempfile.TemporaryDirectory() as tmpdir:
                mount_point = Path(tmpdir) / "workspace"

                async with mount_context(cli, agent_id, mount_point) as mount_ctx:
                    yield mount_ctx.path
        else:
            yield agent_id, fs
```

### 9.4 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.cli import temporary_agent, sandbox_session
from agentfs_pydantic.contexts import (
    mounted_agent,
    temporary_mounted_agent,
    overlay_workspace,
)

__all__ = [
    # ... existing ...
    "temporary_agent",
    "sandbox_session",
    "mounted_agent",
    "temporary_mounted_agent",
    "overlay_workspace",
]
```

### 9.5 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_contexts.py`:

```python
"""Tests for context managers."""

import pytest
from pathlib import Path

from agentfs_pydantic import (
    AgentFSCLI,
    temporary_agent,
    sandbox_session,
    mounted_agent,
    overlay_workspace,
)


class TestTemporaryAgent:
    """Tests for temporary_agent context."""

    @pytest.mark.asyncio
    async def test_auto_cleanup(self):
        """Test that agent is cleaned up automatically."""
        agent_id = None

        async with temporary_agent() as (aid, fs):
            agent_id = aid
            await fs.write("/test.txt", "data")

            # Agent exists during context
            assert await fs.exists("/test.txt")

        # Agent should be cleaned up
        db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
        assert not db_path.exists()

    @pytest.mark.asyncio
    async def test_keep_agent(self):
        """Test keeping agent after context."""
        agent_id = None

        async with temporary_agent(keep=True) as (aid, fs):
            agent_id = aid
            await fs.write("/keep.txt", "data")

        # Agent should still exist
        db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
        assert db_path.exists()

        # Cleanup
        import os
        os.remove(db_path)


class TestSandboxSession:
    """Tests for sandbox_session context."""

    @pytest.mark.asyncio
    async def test_session_execution(self):
        """Test running commands in sandbox session."""
        async with sandbox_session(session_name="test") as run:
            result = await run(["echo", "hello"])
            assert result.success
            assert "hello" in result.stdout


class TestOverlayWorkspace:
    """Tests for overlay_workspace context."""

    @pytest.mark.asyncio
    async def test_overlay_without_mount(self):
        """Test overlay workspace without mounting."""
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            project = Path(tmpdir)
            (project / "original.txt").write_text("original")

            async with overlay_workspace(project, mount=False) as (agent_id, fs):
                # Can write to overlay
                await fs.write("/new.txt", "new content")

                # Original project unchanged
                assert not (project / "new.txt").exists()
                assert (project / "original.txt").read_text() == "original"
```

## Testing

### Manual Testing

```python
import asyncio
from pathlib import Path
from agentfs_pydantic import temporary_agent, overlay_workspace

async def main():
    # Test 1: Temporary agent
    print("1. Testing temporary agent...")
    async with temporary_agent() as (agent_id, fs):
        print(f"Created: {agent_id}")
        await fs.write("/temp.txt", "temporary data")
        content = await fs.cat("/temp.txt")
        print(f"Content: {content}")
    print("Agent cleaned up")

    # Test 2: Overlay workspace
    print("\n2. Testing overlay workspace...")
    project = Path("/tmp/test-project")
    project.mkdir(exist_ok=True)
    (project / "original.txt").write_text("original")

    async with overlay_workspace(project, mount=False) as (agent_id, fs):
        await fs.write("/modified.txt", "new file")
        print(f"Created overlay: {agent_id}")
    print("Overlay cleaned up, project unchanged")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_contexts.py -v
```

## Success Criteria

- [ ] temporary_agent context created
- [ ] sandbox_session context created
- [ ] mounted_agent context created
- [ ] temporary_mounted_agent combines both
- [ ] overlay_workspace for project overlays
- [ ] All contexts properly cleanup on exit
- [ ] Error handling in contexts
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Resources not cleaned up
- **Solution**: Ensure `finally` blocks handle cleanup

**Issue**: Context manager errors
- **Solution**: Use `try/except` in `__aexit__`

**Issue**: Nested context complexity
- **Solution**: Use `@asynccontextmanager` decorator

## Next Steps

Once Phase 2 is complete:
1. Proceed to [Step 10: Sync Operations](./DEV_GUIDE-STEP_10.md)
2. Begin Phase 3: Advanced features

## Design Notes

- All contexts are async context managers
- Cleanup is best-effort (never raises)
- Contexts can be composed
- RAII pattern throughout
- Pythonic and intuitive APIs
