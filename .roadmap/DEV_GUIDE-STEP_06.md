# Step 6: Mount/Unmount Operations

**Phase**: 2 - Essential
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Phase 1 (Steps 1-5)

## Objective

Implement type-safe wrappers for mounting and unmounting AgentFS filesystems:
- Mount AgentFS as FUSE or NFS filesystem
- List active mounts
- Unmount filesystems
- Context managers for automatic cleanup

## Why This Matters

Mount operations enable:
- Direct filesystem access via standard tools
- Integration with file browsers and IDEs
- RAII pattern for automatic unmounting
- Support for both FUSE and NFS backends

## Implementation Guide

### 6.1 Extend AgentFSCLI with Mount Operations

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    async def mount(
        self,
        agent_id: str,
        mount_point: Path,
        *,
        options: Optional["MountOptions"] = None,
    ) -> "MountInfo":
        """Mount an AgentFS filesystem.

        Args:
            agent_id: Agent identifier or database path
            mount_point: Directory to mount at
            options: Mount configuration options

        Returns:
            MountInfo with mount details

        Examples:
            >>> # Basic mount
            >>> mount = await cli.mount("my-agent", Path("/tmp/myagent"))

            >>> # Mount with options
            >>> mount = await cli.mount(
            ...     "my-agent",
            ...     Path("/tmp/myagent"),
            ...     options=MountOptions(
            ...         auto_unmount=True,
            ...         allow_root=True,
            ...         uid=1000,
            ...         gid=1000
            ...     )
            ... )
        """
        from agentfs_pydantic.models import MountOptions, MountInfo

        # Ensure mount point exists
        mount_point = Path(mount_point)
        mount_point.mkdir(parents=True, exist_ok=True)

        args = ["mount", agent_id, str(mount_point)]

        if options:
            if options.auto_unmount:
                args.append("--auto-unmount")

            if options.foreground:
                args.append("--foreground")

            if options.allow_root:
                args.append("--allow-root")

            if options.allow_other:
                args.append("--allow-other")

            if options.uid is not None:
                args.extend(["--uid", str(options.uid)])

            if options.gid is not None:
                args.extend(["--gid", str(options.gid)])

            if options.backend:
                args.extend(["--backend", options.backend])

        result = await self.binary.execute(args)

        # Parse mount info from result
        # Note: Adjust based on actual CLI output
        backend = options.backend if options else "fuse"
        return MountInfo(
            id=agent_id,
            mount_point=mount_point,
            backend=backend,
            pid=0  # Would need to parse from output
        )

    async def unmount(self, mount_point: Path) -> CommandResult:
        """Unmount an AgentFS filesystem.

        Args:
            mount_point: Mount point to unmount

        Returns:
            CommandResult from unmount operation

        Examples:
            >>> await cli.unmount(Path("/tmp/myagent"))
        """
        args = ["unmount", str(mount_point)]
        return await self.binary.execute(args)

    async def list_mounts(self) -> list["MountInfo"]:
        """List all active AgentFS mounts.

        Returns:
            List of MountInfo for active mounts

        Examples:
            >>> mounts = await cli.list_mounts()
            >>> for mount in mounts:
            ...     print(f"{mount.id} -> {mount.mount_point}")
        """
        from agentfs_pydantic.models import MountInfo

        args = ["mount", "list"]
        result = await self.binary.execute(args)

        # Parse output to create MountInfo list
        # This is a placeholder - adjust based on actual CLI output format
        mounts = []
        for line in result.stdout.strip().split('\n'):
            if not line:
                continue
            # Parse line: "agent_id /mount/point backend pid"
            parts = line.split()
            if len(parts) >= 3:
                mounts.append(MountInfo(
                    id=parts[0],
                    mount_point=Path(parts[1]),
                    backend=parts[2] if len(parts) > 2 else "fuse",
                    pid=int(parts[3]) if len(parts) > 3 else 0
                ))

        return mounts
```

### 6.2 Create Mount Context Manager Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/mount.py`:

```python
"""Mount context managers for automatic cleanup."""

import asyncio
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import MountOptions, MountInfo


class MountContext:
    """Context manager for AgentFS mounts.

    Automatically unmounts on exit.

    Examples:
        >>> async with MountContext(cli, "my-agent", Path("/tmp/mount")) as mount:
        ...     # Filesystem is mounted
        ...     files = list(mount.path.glob("*.txt"))
        ... # Automatically unmounted
    """

    def __init__(
        self,
        cli: AgentFSCLI,
        agent_id: str,
        mount_point: Path,
        *,
        options: Optional[MountOptions] = None
    ):
        """Initialize mount context.

        Args:
            cli: AgentFSCLI instance
            agent_id: Agent to mount
            mount_point: Where to mount
            options: Mount options
        """
        self.cli = cli
        self.agent_id = agent_id
        self.mount_point = Path(mount_point)
        self.options = options
        self._mount_info: Optional[MountInfo] = None

    @property
    def path(self) -> Path:
        """Get the mount point path."""
        return self.mount_point

    @property
    def info(self) -> Optional[MountInfo]:
        """Get mount info if mounted."""
        return self._mount_info

    async def __aenter__(self) -> "MountContext":
        """Mount the filesystem."""
        self._mount_info = await self.cli.mount(
            self.agent_id,
            self.mount_point,
            options=self.options
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Unmount the filesystem."""
        try:
            await self.cli.unmount(self.mount_point)
        except Exception:
            # Log but don't raise during cleanup
            pass
        return False


@asynccontextmanager
async def mount_context(
    cli: AgentFSCLI,
    agent_id: str,
    mount_point: Path,
    *,
    options: Optional[MountOptions] = None
):
    """Async context manager for mounting AgentFS.

    Args:
        cli: AgentFSCLI instance
        agent_id: Agent to mount
        mount_point: Where to mount
        options: Mount options

    Yields:
        MountContext instance

    Examples:
        >>> async with mount_context(cli, "my-agent", Path("/tmp/mount")) as mount:
        ...     files = list(mount.path.glob("**/*.txt"))
    """
    ctx = MountContext(cli, agent_id, mount_point, options=options)
    async with ctx:
        yield ctx
```

### 6.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.mount import MountContext, mount_context

__all__ = [
    # ... existing ...
    "MountContext",
    "mount_context",
]
```

### 6.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_mount.py`:

```python
"""Tests for mount operations."""

import pytest
import tempfile
from pathlib import Path

from agentfs_pydantic import AgentFSCLI, MountOptions, mount_context


@pytest.fixture
def cli():
    """Create CLI instance."""
    return AgentFSCLI()


@pytest.fixture
async def test_agent(cli):
    """Create test agent."""
    agent_id = "mount-test-agent"
    await cli.init(agent_id, options=InitOptions(force=True))
    yield agent_id
    # Cleanup
    import os
    db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
    if db_path.exists():
        os.remove(db_path)


class TestMount:
    """Tests for mount operations."""

    @pytest.mark.asyncio
    async def test_mount_and_unmount(self, cli, test_agent):
        """Test basic mount and unmount."""
        with tempfile.TemporaryDirectory() as tmpdir:
            mount_point = Path(tmpdir) / "mount"

            # Mount
            mount_info = await cli.mount(test_agent, mount_point)
            assert mount_info.mount_point == mount_point
            assert mount_info.id == test_agent

            # Verify mounted
            assert mount_point.exists()

            # Unmount
            result = await cli.unmount(mount_point)
            assert result.success

    @pytest.mark.asyncio
    async def test_mount_with_options(self, cli, test_agent):
        """Test mount with options."""
        with tempfile.TemporaryDirectory() as tmpdir:
            mount_point = Path(tmpdir) / "mount"

            options = MountOptions(
                auto_unmount=True,
                uid=1000,
                gid=1000
            )

            mount_info = await cli.mount(test_agent, mount_point, options=options)
            assert mount_info.mount_point == mount_point

            # Cleanup
            await cli.unmount(mount_point)

    @pytest.mark.asyncio
    async def test_mount_context(self, cli, test_agent):
        """Test mount context manager."""
        with tempfile.TemporaryDirectory() as tmpdir:
            mount_point = Path(tmpdir) / "mount"

            async with mount_context(cli, test_agent, mount_point) as mount:
                # Inside context - filesystem is mounted
                assert mount.path.exists()
                assert mount.info is not None

            # After context - should be unmounted
            # (auto-unmount may have removed the directory)
```

## Testing

### Manual Testing

```python
import asyncio
from pathlib import Path
from agentfs_pydantic import AgentFSCLI, InitOptions, MountOptions, mount_context

async def main():
    cli = AgentFSCLI()

    # Create test agent
    await cli.init("mount-demo", options=InitOptions(force=True))

    # Test mount operations
    mount_point = Path("/tmp/agentfs-mount-demo")

    print("1. Mounting filesystem...")
    mount_info = await cli.mount("mount-demo", mount_point)
    print(f"Mounted at: {mount_info.mount_point}")

    print("\n2. Listing mounts...")
    mounts = await cli.list_mounts()
    for m in mounts:
        print(f"  {m.id} -> {m.mount_point}")

    print("\n3. Unmounting...")
    await cli.unmount(mount_point)
    print("Unmounted successfully")

    print("\n4. Testing context manager...")
    async with mount_context(cli, "mount-demo", mount_point) as mount:
        print(f"Mounted at: {mount.path}")
        # Do work with mounted filesystem
    print("Auto-unmounted")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_mount.py -v
```

## Success Criteria

- [ ] Mount operation implemented with options support
- [ ] Unmount operation works correctly
- [ ] List mounts returns active mounts
- [ ] MountContext provides automatic cleanup
- [ ] Context manager pattern works correctly
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Mount point already in use
- **Solution**: Unmount first or use a different directory

**Issue**: Permission denied for mount
- **Solution**: Use `allow_root=True` or check filesystem permissions

**Issue**: FUSE not available
- **Solution**: Install FUSE or use NFS backend: `backend="nfs"`

## Next Steps

Once this step is complete:
1. Proceed to [Step 7: Filesystem Operations](./DEV_GUIDE-STEP_07.md)
2. Mount operations will enable direct filesystem manipulation

## Design Notes

- Context managers ensure automatic cleanup
- Both FUSE and NFS backends supported
- Mount point created if it doesn't exist
- Auto-unmount option recommended for safety
