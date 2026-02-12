# Step 13: Migration Support

**Phase**: 3 - Advanced
**Difficulty**: Easy
**Estimated Time**: 2 hours
**Prerequisites**: Phase 2

## Objective

Implement database migration operations:
- Check migration status
- Apply migrations
- Dry-run migrations
- Parse migration information

## Why This Matters

Migration support enables:
- Upgrading database schemas
- Maintaining compatibility
- Safe schema evolution
- Understanding migration requirements

## Implementation Guide

### 13.1 Extend AgentFSCLI with Migration Operations

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    async def migrate(
        self,
        agent_id: str,
        *,
        dry_run: bool = False
    ) -> "MigrationInfo":
        """Check or apply database migrations.

        Args:
            agent_id: Agent identifier
            dry_run: If True, only show what would be done

        Returns:
            MigrationInfo with migration details

        Examples:
            >>> # Check migration status
            >>> info = await cli.migrate("my-agent", dry_run=True)
            >>> if info.needs_migration:
            ...     print(f"Migration needed: {info.current_version} -> {info.target_version}")
            ...     for step in info.steps:
            ...         print(f"  - {step}")
            >>>
            >>> # Apply migrations
            >>> info = await cli.migrate("my-agent", dry_run=False)
            >>> print("Migrations applied")
        """
        from agentfs_pydantic.models import MigrationInfo

        args = ["migrate", agent_id]

        if dry_run:
            args.append("--dry-run")

        result = await self.binary.execute(args)

        # Parse migration info from output
        # This is a placeholder - adjust based on actual CLI output
        current_version = "1.0.0"
        target_version = "1.0.0"
        steps = []

        if result.stdout:
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if "current version:" in line.lower():
                    current_version = line.split(':')[-1].strip()
                elif "target version:" in line.lower():
                    target_version = line.split(':')[-1].strip()
                elif line.strip().startswith('-'):
                    steps.append(line.strip()[1:].strip())

        return MigrationInfo(
            current_version=current_version,
            target_version=target_version,
            steps=steps
        )

    async def check_migrations(
        self,
        agent_id: str
    ) -> bool:
        """Check if migrations are needed.

        Args:
            agent_id: Agent identifier

        Returns:
            True if migrations are needed

        Examples:
            >>> if await cli.check_migrations("my-agent"):
            ...     print("Migrations pending")
            ...     await cli.migrate("my-agent")
        """
        info = await self.migrate(agent_id, dry_run=True)
        return info.needs_migration
```

### 13.2 Create Migration Module with Helpers

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/migration.py`:

```python
"""Migration helpers and automation."""

from typing import Optional, Callable
from contextlib import asynccontextmanager

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import MigrationInfo
from agentfs_pydantic.exceptions import MigrationError


class MigrationManager:
    """Manage database migrations.

    Examples:
        >>> manager = MigrationManager("my-agent")
        >>>
        >>> # Check status
        >>> info = await manager.check()
        >>> print(f"Needs migration: {info.needs_migration}")
        >>>
        >>> # Apply with confirmation
        >>> if await manager.needs_migration():
        ...     print(f"Will migrate: {await manager.preview()}")
        ...     await manager.apply()
    """

    def __init__(
        self,
        agent_id: str,
        *,
        cli: Optional[AgentFSCLI] = None
    ):
        """Initialize migration manager.

        Args:
            agent_id: Agent to manage
            cli: Optional CLI instance
        """
        self.agent_id = agent_id
        self.cli = cli or AgentFSCLI()

    async def check(self) -> MigrationInfo:
        """Check migration status.

        Returns:
            MigrationInfo with current status
        """
        return await self.cli.migrate(self.agent_id, dry_run=True)

    async def needs_migration(self) -> bool:
        """Check if migration is needed.

        Returns:
            True if migration needed
        """
        info = await self.check()
        return info.needs_migration

    async def preview(self) -> list[str]:
        """Preview migration steps.

        Returns:
            List of migration steps
        """
        info = await self.check()
        return info.steps

    async def apply(self, *, confirm: bool = True) -> MigrationInfo:
        """Apply migrations.

        Args:
            confirm: If True, check status first

        Returns:
            MigrationInfo after migration

        Raises:
            MigrationError: If migration fails
        """
        if confirm:
            info = await self.check()
            if not info.needs_migration:
                return info

        try:
            result = await self.cli.migrate(self.agent_id, dry_run=False)
            return result
        except Exception as e:
            info = await self.check()
            raise MigrationError(
                f"Migration failed: {e}",
                current_version=info.current_version,
                target_version=info.target_version
            ) from e


@asynccontextmanager
async def auto_migrate(
    agent_id: str,
    *,
    cli: Optional[AgentFSCLI] = None,
    on_migrate: Optional[Callable[[MigrationInfo], None]] = None
):
    """Context manager for automatic migrations.

    Checks and applies migrations on entry.

    Args:
        agent_id: Agent to manage
        cli: Optional CLI instance
        on_migrate: Optional callback when migration occurs

    Yields:
        MigrationManager instance

    Examples:
        >>> async with auto_migrate("my-agent") as manager:
        ...     # Migrations automatically applied
        ...     # Use agent normally
        ...     pass
    """
    manager = MigrationManager(agent_id, cli=cli)

    # Check and apply migrations
    if await manager.needs_migration():
        info = await manager.apply()
        if on_migrate:
            on_migrate(info)

    yield manager


async def migrate_if_needed(
    agent_id: str,
    *,
    cli: Optional[AgentFSCLI] = None
) -> bool:
    """Migrate agent if needed.

    Convenience function for one-line migration.

    Args:
        agent_id: Agent to migrate
        cli: Optional CLI instance

    Returns:
        True if migration was applied

    Examples:
        >>> if await migrate_if_needed("my-agent"):
        ...     print("Agent migrated successfully")
    """
    manager = MigrationManager(agent_id, cli=cli)

    if await manager.needs_migration():
        await manager.apply()
        return True

    return False
```

### 13.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.migration import (
    MigrationManager,
    auto_migrate,
    migrate_if_needed,
)

__all__ = [
    # ... existing ...
    "MigrationManager",
    "auto_migrate",
    "migrate_if_needed",
]
```

### 13.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_migration.py`:

```python
"""Tests for migration operations."""

import pytest
from pathlib import Path

from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    MigrationManager,
    migrate_if_needed,
)


@pytest.fixture
async def test_agent():
    """Create test agent."""
    cli = AgentFSCLI()
    agent_id = "migration-test"
    await cli.init(agent_id, options=InitOptions(force=True))
    yield agent_id
    # Cleanup
    import os
    db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
    if db_path.exists():
        os.remove(db_path)


class TestMigration:
    """Tests for migration operations."""

    @pytest.mark.asyncio
    async def test_check_migrations(self, test_agent):
        """Test checking migration status."""
        cli = AgentFSCLI()
        needs_migration = await cli.check_migrations(test_agent)
        assert isinstance(needs_migration, bool)

    @pytest.mark.asyncio
    async def test_migration_info(self, test_agent):
        """Test getting migration info."""
        cli = AgentFSCLI()
        info = await cli.migrate(test_agent, dry_run=True)

        assert info.current_version is not None
        assert info.target_version is not None
        assert isinstance(info.steps, list)

    @pytest.mark.asyncio
    async def test_migration_manager(self, test_agent):
        """Test migration manager."""
        manager = MigrationManager(test_agent)

        info = await manager.check()
        assert info is not None

        needs = await manager.needs_migration()
        assert isinstance(needs, bool)

    @pytest.mark.asyncio
    async def test_migrate_if_needed(self, test_agent):
        """Test convenience function."""
        result = await migrate_if_needed(test_agent)
        assert isinstance(result, bool)
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    MigrationManager,
    auto_migrate,
)

async def main():
    cli = AgentFSCLI()

    # Create agent
    await cli.init("migration-demo", options=InitOptions(force=True))

    # Check migrations
    print("1. Checking migration status...")
    needs = await cli.check_migrations("migration-demo")
    print(f"Needs migration: {needs}")

    # Get migration info
    print("\n2. Migration info:")
    info = await cli.migrate("migration-demo", dry_run=True)
    print(f"Current version: {info.current_version}")
    print(f"Target version: {info.target_version}")
    print(f"Needs migration: {info.needs_migration}")
    if info.steps:
        print("Steps:")
        for step in info.steps:
            print(f"  - {step}")

    # Use migration manager
    print("\n3. Migration manager:")
    manager = MigrationManager("migration-demo")
    if await manager.needs_migration():
        print("Applying migrations...")
        await manager.apply()
        print("Done")

    # Auto-migrate
    print("\n4. Auto-migrate context:")
    async with auto_migrate("migration-demo") as mgr:
        print("Migrations applied automatically")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_migration.py -v
```

## Success Criteria

- [ ] migrate operation implemented
- [ ] Dry-run mode works
- [ ] check_migrations helper works
- [ ] MigrationInfo parsed correctly
- [ ] MigrationManager provides high-level API
- [ ] auto_migrate context works
- [ ] migrate_if_needed convenience function works
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Migration fails
- **Solution**: Check database isn't in use, backup first

**Issue**: Version parsing fails
- **Solution**: Ensure CLI output format is consistent

**Issue**: No migration needed
- **Solution**: Database already at latest version

## Next Steps

Once this step is complete:
1. Proceed to [Step 14: MCP/NFS Servers](./DEV_GUIDE-STEP_14.md)
2. Complete Phase 3: Advanced features

## Design Notes

- Always safe to check migrations (dry-run)
- Migration is automatic when needed
- Version tracking helps understand schema
- Context manager for automatic migration
- Errors include version information
