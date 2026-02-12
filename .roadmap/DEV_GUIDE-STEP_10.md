# Step 10: Sync Operations

**Phase**: 3 - Advanced
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Phase 2 (Steps 1-9)

## Objective

Implement type-safe wrappers for sync operations with remote databases:
- Pull changes from remote
- Push changes to remote
- Checkpoint operations
- Sync statistics and status
- Error handling for network operations

## Why This Matters

Sync operations enable:
- Distributed AgentFS usage
- Backup and restore
- Collaboration across instances
- Integration with Turso databases

## Implementation Guide

### 10.1 Extend AgentFSCLI with Sync Operations

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    async def sync_pull(
        self,
        config: "SyncConfig"
    ) -> CommandResult:
        """Pull changes from remote database.

        Args:
            config: Sync configuration

        Returns:
            CommandResult from pull operation

        Examples:
            >>> from agentfs_pydantic import SyncConfig
            >>>
            >>> config = SyncConfig(
            ...     id_or_path="my-agent",
            ...     remote_url="libsql://mydb.turso.io",
            ...     auth_token="...",
            ... )
            >>>
            >>> result = await cli.sync_pull(config)
            >>> print(f"Pulled changes: {result.success}")
        """
        from agentfs_pydantic.models import SyncConfig

        args = ["sync", "pull", config.id_or_path]
        args.extend(["--remote-url", config.remote_url])

        if config.auth_token:
            args.extend(["--auth-token", config.auth_token])

        if config.partial_prefetch:
            args.append("--partial-prefetch")

        return await self.binary.execute(args)

    async def sync_push(
        self,
        config: "SyncConfig"
    ) -> CommandResult:
        """Push changes to remote database.

        Args:
            config: Sync configuration

        Returns:
            CommandResult from push operation

        Examples:
            >>> result = await cli.sync_push(config)
            >>> if result.success:
            ...     print("Changes pushed successfully")
        """
        args = ["sync", "push", config.id_or_path]
        args.extend(["--remote-url", config.remote_url])

        if config.auth_token:
            args.extend(["--auth-token", config.auth_token])

        return await self.binary.execute(args)

    async def sync_checkpoint(
        self,
        config: "SyncConfig"
    ) -> CommandResult:
        """Create a sync checkpoint.

        Args:
            config: Sync configuration

        Returns:
            CommandResult from checkpoint operation

        Examples:
            >>> result = await cli.sync_checkpoint(config)
            >>> print("Checkpoint created")
        """
        args = ["sync", "checkpoint", config.id_or_path]
        args.extend(["--remote-url", config.remote_url])

        if config.auth_token:
            args.extend(["--auth-token", config.auth_token])

        return await self.binary.execute(args)

    async def sync_stats(
        self,
        config: "SyncConfig"
    ) -> "SyncStats":
        """Get sync statistics.

        Args:
            config: Sync configuration

        Returns:
            SyncStats with sync information

        Examples:
            >>> stats = await cli.sync_stats(config)
            >>> print(f"Last sync: {stats.last_sync}")
            >>> print(f"Pending changes: {stats.pending_changes}")
        """
        from agentfs_pydantic.models import SyncStats
        from datetime import datetime

        args = ["sync", "stats", config.id_or_path]
        args.extend(["--remote-url", config.remote_url])

        if config.auth_token:
            args.extend(["--auth-token", config.auth_token])

        result = await self.binary.execute(args)

        # Parse output to create SyncStats
        # This is a placeholder - adjust based on actual CLI output format
        stats = SyncStats(
            last_sync=None,  # Would parse from output
            pending_changes=0,  # Would parse from output
            total_synced=0  # Would parse from output
        )

        return stats
```

### 10.2 Create Sync Module with Helpers

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/sync.py`:

```python
"""Sync operations and helpers."""

import os
from typing import Optional
from contextlib import asynccontextmanager

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import SyncConfig, SyncStats
from agentfs_pydantic.exceptions import SyncError


class SyncManager:
    """High-level sync management.

    Examples:
        >>> manager = SyncManager(
        ...     agent_id="my-agent",
        ...     remote_url="libsql://mydb.turso.io",
        ...     auth_token="..."
        ... )
        >>>
        >>> # Pull changes
        >>> await manager.pull()
        >>>
        >>> # Push changes
        >>> await manager.push()
        >>>
        >>> # Bidirectional sync
        >>> await manager.sync()
    """

    def __init__(
        self,
        agent_id: str,
        remote_url: str,
        *,
        auth_token: Optional[str] = None,
        partial_prefetch: bool = False,
        cli: Optional[AgentFSCLI] = None
    ):
        """Initialize sync manager.

        Args:
            agent_id: Agent to sync
            remote_url: Remote database URL
            auth_token: Authentication token (can use env var)
            partial_prefetch: Enable partial prefetch
            cli: Optional CLI instance
        """
        self.agent_id = agent_id
        self.remote_url = remote_url
        self.auth_token = auth_token or os.getenv("TURSO_DB_AUTH_TOKEN")
        self.partial_prefetch = partial_prefetch
        self.cli = cli or AgentFSCLI()

        self._config = SyncConfig(
            id_or_path=agent_id,
            remote_url=remote_url,
            auth_token=self.auth_token,
            partial_prefetch=partial_prefetch
        )

    async def pull(self) -> bool:
        """Pull changes from remote.

        Returns:
            True if successful

        Raises:
            SyncError: If pull fails
        """
        try:
            result = await self.cli.sync_pull(self._config)
            if not result.success:
                raise SyncError(
                    f"Pull failed: {result.stderr}",
                    operation="pull",
                    remote_url=self.remote_url
                )
            return True
        except Exception as e:
            raise SyncError(
                f"Pull error: {e}",
                operation="pull",
                remote_url=self.remote_url
            ) from e

    async def push(self) -> bool:
        """Push changes to remote.

        Returns:
            True if successful

        Raises:
            SyncError: If push fails
        """
        try:
            result = await self.cli.sync_push(self._config)
            if not result.success:
                raise SyncError(
                    f"Push failed: {result.stderr}",
                    operation="push",
                    remote_url=self.remote_url
                )
            return True
        except Exception as e:
            raise SyncError(
                f"Push error: {e}",
                operation="push",
                remote_url=self.remote_url
            ) from e

    async def sync(self) -> bool:
        """Bidirectional sync (pull then push).

        Returns:
            True if successful

        Raises:
            SyncError: If sync fails
        """
        await self.pull()
        await self.push()
        return True

    async def checkpoint(self) -> bool:
        """Create a checkpoint.

        Returns:
            True if successful
        """
        result = await self.cli.sync_checkpoint(self._config)
        return result.success

    async def stats(self) -> SyncStats:
        """Get sync statistics.

        Returns:
            SyncStats object
        """
        return await self.cli.sync_stats(self._config)


@asynccontextmanager
async def auto_sync(
    agent_id: str,
    remote_url: str,
    *,
    auth_token: Optional[str] = None,
    pull_on_enter: bool = True,
    push_on_exit: bool = True,
    cli: Optional[AgentFSCLI] = None
):
    """Context manager for automatic sync.

    Pulls on entry, pushes on exit.

    Args:
        agent_id: Agent to sync
        remote_url: Remote database URL
        auth_token: Authentication token
        pull_on_enter: Pull changes on entry
        push_on_exit: Push changes on exit
        cli: Optional CLI instance

    Yields:
        SyncManager instance

    Examples:
        >>> async with auto_sync("my-agent", "libsql://db.turso.io") as manager:
        ...     # Changes automatically pulled
        ...     fs = FSOperations("my-agent")
        ...     await fs.write("/data.txt", "new data")
        ...     # Changes automatically pushed on exit
    """
    manager = SyncManager(
        agent_id,
        remote_url,
        auth_token=auth_token,
        cli=cli
    )

    if pull_on_enter:
        await manager.pull()

    try:
        yield manager
    finally:
        if push_on_exit:
            try:
                await manager.push()
            except Exception:
                # Best effort push
                pass
```

### 10.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.sync import SyncManager, auto_sync

__all__ = [
    # ... existing ...
    "SyncManager",
    "auto_sync",
]
```

### 10.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_sync.py`:

```python
"""Tests for sync operations.

Note: These tests require a Turso database for full integration testing.
"""

import pytest
import os
from pathlib import Path

from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    SyncConfig,
    SyncManager,
    auto_sync,
)


@pytest.fixture
def sync_config():
    """Create sync config (skip if no credentials)."""
    remote_url = os.getenv("TEST_TURSO_URL")
    auth_token = os.getenv("TEST_TURSO_TOKEN")

    if not remote_url or not auth_token:
        pytest.skip("Turso credentials not available")

    return {
        "remote_url": remote_url,
        "auth_token": auth_token
    }


class TestSyncOperations:
    """Tests for sync operations."""

    @pytest.mark.asyncio
    async def test_sync_manager_creation(self):
        """Test creating sync manager."""
        manager = SyncManager(
            "test-agent",
            "libsql://test.turso.io",
            auth_token="test-token"
        )
        assert manager.agent_id == "test-agent"
        assert manager.remote_url == "libsql://test.turso.io"

    @pytest.mark.asyncio
    @pytest.mark.integration
    async def test_sync_workflow(self, sync_config):
        """Test complete sync workflow (requires Turso DB)."""
        cli = AgentFSCLI()
        agent_id = "sync-test-agent"

        # Initialize agent
        await cli.init(agent_id, options=InitOptions(force=True))

        try:
            # Create sync manager
            manager = SyncManager(
                agent_id,
                sync_config["remote_url"],
                auth_token=sync_config["auth_token"]
            )

            # Test pull
            await manager.pull()

            # Test push
            await manager.push()

            # Test stats
            stats = await manager.stats()
            assert stats is not None

        finally:
            # Cleanup
            import os
            db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
            if db_path.exists():
                os.remove(db_path)

    @pytest.mark.asyncio
    @pytest.mark.integration
    async def test_auto_sync_context(self, sync_config):
        """Test auto-sync context manager."""
        from agentfs_pydantic import FSOperations

        cli = AgentFSCLI()
        agent_id = "auto-sync-test"

        await cli.init(agent_id, options=InitOptions(force=True))

        try:
            async with auto_sync(
                agent_id,
                sync_config["remote_url"],
                auth_token=sync_config["auth_token"]
            ) as manager:
                # Write data
                fs = FSOperations(agent_id)
                await fs.write("/sync-test.txt", "synced data")

            # Data should be pushed automatically

        finally:
            # Cleanup
            import os
            db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
            if db_path.exists():
                os.remove(db_path)
```

## Testing

### Manual Testing

```python
import asyncio
import os
from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    SyncManager,
    auto_sync,
    FSOperations
)

async def main():
    # Setup (requires Turso database)
    remote_url = os.getenv("TURSO_URL")
    auth_token = os.getenv("TURSO_DB_AUTH_TOKEN")

    if not remote_url or not auth_token:
        print("Set TURSO_URL and TURSO_DB_AUTH_TOKEN environment variables")
        return

    cli = AgentFSCLI()

    # Initialize agent
    await cli.init("sync-demo", options=InitOptions(force=True))

    # Test 1: Manual sync
    print("1. Testing manual sync...")
    manager = SyncManager("sync-demo", remote_url, auth_token=auth_token)

    await manager.pull()
    print("Pulled changes")

    fs = FSOperations("sync-demo")
    await fs.write("/synced.txt", "Hello from sync!")

    await manager.push()
    print("Pushed changes")

    # Test 2: Auto sync
    print("\n2. Testing auto-sync...")
    async with auto_sync("sync-demo", remote_url, auth_token=auth_token) as mgr:
        await fs.write("/auto-synced.txt", "Auto synced!")
    print("Auto-sync complete")

asyncio.run(main())
```

### Automated Testing

```bash
# Set up test database
export TEST_TURSO_URL="libsql://your-test-db.turso.io"
export TEST_TURSO_TOKEN="your-token"

# Run tests
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_sync.py -v -m integration
```

## Success Criteria

- [ ] sync_pull operation implemented
- [ ] sync_push operation implemented
- [ ] sync_checkpoint operation implemented
- [ ] sync_stats returns statistics
- [ ] SyncManager provides high-level API
- [ ] auto_sync context manager works
- [ ] Error handling for network failures
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Authentication failures
- **Solution**: Verify `TURSO_DB_AUTH_TOKEN` is set correctly

**Issue**: Network timeouts
- **Solution**: Check remote URL and network connectivity

**Issue**: Partial prefetch errors
- **Solution**: Ensure remote database supports partial prefetch

## Next Steps

Once this step is complete:
1. Proceed to [Step 11: Timeline Queries](./DEV_GUIDE-STEP_11.md)
2. Sync operations enable distributed workflows

## Design Notes

- Auth token can come from environment variable
- SyncManager provides simpler API than raw CLI
- auto_sync context automates common pattern
- Bidirectional sync = pull then push
- Error handling specific to network operations
