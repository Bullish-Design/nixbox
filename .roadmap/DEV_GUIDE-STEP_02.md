# Step 2: Enhanced Models

**Phase**: 1 - Core (MVP)
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: Step 1 (CLI Binary Wrapper)

## Objective

Expand the existing Pydantic models to cover all CLI configuration options and results:
- Init/Exec/Run configuration options
- Encryption configuration with validation
- Sandbox configuration
- Sync configuration
- Result models (diff, migration info, etc.)

## Why This Matters

These models provide:
- Type safety for all CLI operations
- Automatic validation of configuration
- Self-documenting API (IDE autocomplete)
- Consistent interface across all operations

## Implementation Guide

### 2.1 Extend models.py

Add these models to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/models.py`:

```python
from pathlib import Path
from typing import Literal
from pydantic import field_validator


# ============================================================================
# Configuration Models
# ============================================================================


class EncryptionConfig(BaseModel):
    """Encryption configuration for AgentFS.

    Validates key length based on cipher type.

    Examples:
        >>> config = EncryptionConfig(
        ...     key="0" * 64,  # 64 hex chars for AES-256
        ...     cipher="aes256gcm"
        ... )
    """

    key: str = Field(
        ...,
        description="Encryption key in hexadecimal",
        pattern=r"^[0-9a-fA-F]+$"
    )
    cipher: Literal["aes256gcm", "aes128gcm", "aegis256", "aegis128l"] = Field(
        default="aes256gcm",
        description="Cipher algorithm to use"
    )

    @field_validator("key")
    @classmethod
    def validate_key_length(cls, v: str, info) -> str:
        """Validate key length matches cipher requirements."""
        data = info.data
        cipher = data.get("cipher", "aes256gcm")

        # Determine required length
        if "256" in cipher:
            required_length = 64  # 256 bits = 64 hex chars
        else:
            required_length = 32  # 128 bits = 32 hex chars

        if len(v) != required_length:
            raise ValueError(
                f"{cipher} requires {required_length} hex characters, got {len(v)}"
            )

        return v


class SyncRemoteConfig(BaseModel):
    """Remote sync configuration.

    Examples:
        >>> config = SyncRemoteConfig(
        ...     url="libsql://mydb.turso.io",
        ...     auth_token="..."
        ... )
    """

    url: str = Field(..., description="Remote database URL (libsql://...)")
    auth_token: Optional[str] = Field(
        None,
        description="Authentication token for remote"
    )
    partial_prefetch: bool = Field(
        default=False,
        description="Enable partial prefetch mode"
    )


class InitOptions(BaseModel):
    """Options for initializing a new AgentFS instance.

    Examples:
        >>> # Basic init
        >>> options = InitOptions()

        >>> # Init with overlay
        >>> options = InitOptions(base="/my/project")

        >>> # Init with encryption
        >>> options = InitOptions(
        ...     encryption=EncryptionConfig(
        ...         key="0" * 64,
        ...         cipher="aes256gcm"
        ...     )
        ... )
    """

    force: bool = Field(
        default=False,
        description="Overwrite existing agent database"
    )
    base: Optional[Path] = Field(
        None,
        description="Base directory for copy-on-write overlay"
    )
    encryption: Optional[EncryptionConfig] = Field(
        None,
        description="Encryption configuration"
    )
    sync_config: Optional[SyncRemoteConfig] = Field(
        None,
        description="Remote sync configuration"
    )
    command: Optional[list[str]] = Field(
        None,
        description="Command to run after init"
    )
    backend: Optional[Literal["fuse", "nfs"]] = Field(
        None,
        description="Filesystem backend (auto-detected if not specified)"
    )


class ExecOptions(BaseModel):
    """Options for executing commands in existing AgentFS.

    Examples:
        >>> options = ExecOptions(backend="fuse")
        >>> options = ExecOptions(
        ...     encryption=EncryptionConfig(key="...", cipher="aes256gcm")
        ... )
    """

    backend: Optional[Literal["fuse", "nfs"]] = Field(
        None,
        description="Filesystem backend to use"
    )
    encryption: Optional[EncryptionConfig] = Field(
        None,
        description="Encryption configuration (must match init)"
    )


class SandboxOptions(BaseModel):
    """Options for sandboxed command execution.

    Examples:
        >>> options = SandboxOptions(
        ...     session="my-session",
        ...     allowed_paths=["/home/user/.cache"],
        ...     experimental_sandbox=True
        ... )
    """

    session: Optional[str] = Field(
        None,
        description="Named session for persistence across runs"
    )
    allowed_paths: list[str] = Field(
        default_factory=list,
        description="Additional paths accessible to sandboxed process"
    )
    no_default_allows: bool = Field(
        default=False,
        description="Disable default allowed paths"
    )
    experimental_sandbox: bool = Field(
        default=False,
        description="Enable experimental sandbox features"
    )
    strace: bool = Field(
        default=False,
        description="Enable syscall tracing for debugging"
    )


class MountOptions(BaseModel):
    """Options for mounting AgentFS filesystem.

    Examples:
        >>> options = MountOptions(
        ...     auto_unmount=True,
        ...     allow_root=True,
        ...     uid=1000,
        ...     gid=1000
        ... )
    """

    auto_unmount: bool = Field(
        default=True,
        description="Automatically unmount on process exit"
    )
    foreground: bool = Field(
        default=False,
        description="Run mount in foreground"
    )
    allow_root: bool = Field(
        default=False,
        description="Allow root to access mount"
    )
    allow_other: bool = Field(
        default=False,
        description="Allow other users to access mount"
    )
    uid: Optional[int] = Field(
        None,
        description="Override file owner UID"
    )
    gid: Optional[int] = Field(
        None,
        description="Override file owner GID"
    )
    backend: Optional[Literal["fuse", "nfs"]] = Field(
        None,
        description="Mount backend to use"
    )


class SyncConfig(BaseModel):
    """Configuration for sync operations.

    Examples:
        >>> config = SyncConfig(
        ...     id_or_path="my-agent",
        ...     remote_url="libsql://mydb.turso.io",
        ...     auth_token="...",
        ...     partial_prefetch=True
        ... )
    """

    id_or_path: str = Field(
        ...,
        description="Agent ID or database path"
    )
    remote_url: str = Field(
        ...,
        description="Remote database URL"
    )
    auth_token: Optional[str] = Field(
        None,
        description="Authentication token"
    )
    partial_prefetch: bool = Field(
        default=False,
        description="Enable partial prefetch"
    )


class TimelineQuery(BaseModel):
    """Query parameters for timeline operations.

    Examples:
        >>> query = TimelineQuery(
        ...     limit=100,
        ...     filter_tool="write_file",
        ...     status="success"
        ... )
    """

    limit: int = Field(
        default=100,
        description="Maximum number of entries to return",
        gt=0
    )
    filter_tool: Optional[str] = Field(
        None,
        description="Filter by tool name"
    )
    status: Optional[Literal["pending", "success", "error"]] = Field(
        None,
        description="Filter by status"
    )
    format: Literal["json", "pretty"] = Field(
        default="json",
        description="Output format"
    )


class MCPServerConfig(BaseModel):
    """Configuration for MCP (Model Context Protocol) server.

    Examples:
        >>> config = MCPServerConfig(
        ...     tools=["read_file", "write_file", "kv_get", "kv_set"]
        ... )
    """

    tools: list[str] = Field(
        default_factory=lambda: [
            "read_file",
            "write_file",
            "list_directory",
            "kv_get",
            "kv_set"
        ],
        description="Tools to expose via MCP"
    )


class NFSServerConfig(BaseModel):
    """Configuration for NFS server.

    Examples:
        >>> config = NFSServerConfig(bind="127.0.0.1", port=11111)
    """

    bind: str = Field(
        default="127.0.0.1",
        description="Bind address"
    )
    port: int = Field(
        default=11111,
        description="Bind port",
        gt=0,
        lt=65536
    )


# ============================================================================
# Result Models
# ============================================================================


class MountInfo(BaseModel):
    """Information about an active mount.

    Examples:
        >>> info = MountInfo(
        ...     id="my-agent",
        ...     mount_point=Path("/tmp/myagent"),
        ...     backend="fuse",
        ...     pid=12345
        ... )
    """

    id: str = Field(description="Agent ID")
    mount_point: Path = Field(description="Mount point path")
    backend: Literal["fuse", "nfs"] = Field(description="Mount backend")
    pid: int = Field(description="Process ID of mount daemon")


class SyncStats(BaseModel):
    """Statistics from sync operations.

    Examples:
        >>> stats = SyncStats(
        ...     last_sync=datetime.now(),
        ...     pending_changes=5,
        ...     total_synced=1000
        ... )
    """

    last_sync: Optional[datetime] = Field(
        None,
        description="Timestamp of last successful sync"
    )
    pending_changes: int = Field(
        default=0,
        description="Number of pending changes to sync"
    )
    total_synced: int = Field(
        default=0,
        description="Total number of synced operations"
    )


class DiffChange(BaseModel):
    """Represents a single change in a diff.

    Examples:
        >>> change = DiffChange(
        ...     type="modified",
        ...     path="/config.json",
        ...     before_size=100,
        ...     after_size=150
        ... )
    """

    type: Literal["added", "modified", "deleted"] = Field(
        description="Type of change"
    )
    path: str = Field(description="File path")
    before_size: Optional[int] = Field(
        None,
        description="Size before change (for modified/deleted)"
    )
    after_size: Optional[int] = Field(
        None,
        description="Size after change (for added/modified)"
    )


class DiffResult(BaseModel):
    """Result of a diff operation.

    Examples:
        >>> result = DiffResult(changes=[
        ...     DiffChange(type="added", path="/new.txt", after_size=100),
        ...     DiffChange(type="modified", path="/old.txt", before_size=50, after_size=75)
        ... ])
    """

    changes: list[DiffChange] = Field(
        default_factory=list,
        description="List of changes"
    )

    @property
    def total_changes(self) -> int:
        """Total number of changes."""
        return len(self.changes)

    @property
    def added_count(self) -> int:
        """Number of added files."""
        return sum(1 for c in self.changes if c.type == "added")

    @property
    def modified_count(self) -> int:
        """Number of modified files."""
        return sum(1 for c in self.changes if c.type == "modified")

    @property
    def deleted_count(self) -> int:
        """Number of deleted files."""
        return sum(1 for c in self.changes if c.type == "deleted")


class MigrationInfo(BaseModel):
    """Information about database migrations.

    Examples:
        >>> info = MigrationInfo(
        ...     current_version="1.0.0",
        ...     target_version="2.0.0",
        ...     steps=["Add column X", "Create index Y"]
        ... )
    """

    current_version: str = Field(description="Current schema version")
    target_version: str = Field(description="Target schema version")
    steps: list[str] = Field(
        default_factory=list,
        description="Migration steps to apply"
    )

    @property
    def needs_migration(self) -> bool:
        """Check if migration is needed."""
        return self.current_version != self.target_version


class TimelineEntry(BaseModel):
    """Single entry in the timeline.

    Examples:
        >>> entry = TimelineEntry(
        ...     timestamp=datetime.now(),
        ...     tool_name="write_file",
        ...     status="success",
        ...     parameters={"path": "/test.txt"},
        ...     duration_ms=12.5
        ... )
    """

    timestamp: datetime = Field(description="Entry timestamp")
    tool_name: str = Field(description="Tool/operation name")
    status: Literal["pending", "success", "error"] = Field(
        description="Operation status"
    )
    parameters: dict[str, Any] = Field(
        default_factory=dict,
        description="Operation parameters"
    )
    result: Optional[Any] = Field(
        None,
        description="Operation result"
    )
    error: Optional[str] = Field(
        None,
        description="Error message if failed"
    )
    duration_ms: Optional[float] = Field(
        None,
        description="Operation duration in milliseconds"
    )


class TimelineResult(BaseModel):
    """Result of a timeline query.

    Examples:
        >>> result = TimelineResult(entries=[...])
        >>> print(f"Found {len(result.entries)} timeline entries")
    """

    entries: list[TimelineEntry] = Field(
        default_factory=list,
        description="Timeline entries"
    )

    @property
    def total_entries(self) -> int:
        """Total number of entries."""
        return len(self.entries)

    @property
    def success_count(self) -> int:
        """Number of successful operations."""
        return sum(1 for e in self.entries if e.status == "success")

    @property
    def error_count(self) -> int:
        """Number of failed operations."""
        return sum(1 for e in self.entries if e.status == "error")
```

### 2.2 Update Exports

Update `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.models import (
    # Existing...
    AgentFSOptions,
    FileEntry,
    FileStats,
    KVEntry,
    ToolCall,
    ToolCallStats,
    # New config models
    EncryptionConfig,
    InitOptions,
    ExecOptions,
    SandboxOptions,
    MountOptions,
    SyncConfig,
    SyncRemoteConfig,
    TimelineQuery,
    MCPServerConfig,
    NFSServerConfig,
    # New result models
    MountInfo,
    SyncStats,
    DiffChange,
    DiffResult,
    MigrationInfo,
    TimelineEntry,
    TimelineResult,
)

__all__ = [
    # ... existing ...
    # Config models
    "EncryptionConfig",
    "InitOptions",
    "ExecOptions",
    "SandboxOptions",
    "MountOptions",
    "SyncConfig",
    "SyncRemoteConfig",
    "TimelineQuery",
    "MCPServerConfig",
    "NFSServerConfig",
    # Result models
    "MountInfo",
    "SyncStats",
    "DiffChange",
    "DiffResult",
    "MigrationInfo",
    "TimelineEntry",
    "TimelineResult",
]
```

### 2.3 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_enhanced_models.py`:

```python
"""Tests for enhanced models."""

import pytest
from datetime import datetime
from pathlib import Path

from agentfs_pydantic.models import (
    EncryptionConfig,
    InitOptions,
    ExecOptions,
    SandboxOptions,
    MountOptions,
    DiffChange,
    DiffResult,
    MigrationInfo,
    TimelineEntry,
    TimelineResult,
)


class TestEncryptionConfig:
    """Tests for EncryptionConfig model."""

    def test_aes256_requires_64_hex_chars(self):
        """Test AES-256 key length validation."""
        # Valid
        config = EncryptionConfig(
            key="0" * 64,
            cipher="aes256gcm"
        )
        assert len(config.key) == 64

        # Invalid - too short
        with pytest.raises(ValueError, match="requires 64"):
            EncryptionConfig(
                key="0" * 32,
                cipher="aes256gcm"
            )

    def test_aes128_requires_32_hex_chars(self):
        """Test AES-128 key length validation."""
        # Valid
        config = EncryptionConfig(
            key="0" * 32,
            cipher="aes128gcm"
        )
        assert len(config.key) == 32

    def test_key_must_be_hex(self):
        """Test that key must be hexadecimal."""
        with pytest.raises(ValueError):
            EncryptionConfig(
                key="not-hex-chars!",
                cipher="aes256gcm"
            )


class TestInitOptions:
    """Tests for InitOptions model."""

    def test_default_options(self):
        """Test default initialization."""
        options = InitOptions()
        assert options.force is False
        assert options.base is None
        assert options.encryption is None

    def test_with_base_path(self):
        """Test with base directory."""
        options = InitOptions(base=Path("/my/project"))
        assert options.base == Path("/my/project")

    def test_with_encryption(self):
        """Test with encryption config."""
        encryption = EncryptionConfig(
            key="0" * 64,
            cipher="aes256gcm"
        )
        options = InitOptions(encryption=encryption)
        assert options.encryption == encryption


class TestSandboxOptions:
    """Tests for SandboxOptions model."""

    def test_default_options(self):
        """Test default sandbox options."""
        options = SandboxOptions()
        assert options.session is None
        assert options.allowed_paths == []
        assert options.experimental_sandbox is False

    def test_with_session(self):
        """Test with named session."""
        options = SandboxOptions(session="my-session")
        assert options.session == "my-session"


class TestDiffResult:
    """Tests for DiffResult model."""

    def test_change_counts(self):
        """Test change count properties."""
        result = DiffResult(changes=[
            DiffChange(type="added", path="/new.txt", after_size=100),
            DiffChange(type="modified", path="/old.txt", before_size=50, after_size=75),
            DiffChange(type="deleted", path="/gone.txt", before_size=200),
            DiffChange(type="added", path="/another.txt", after_size=50),
        ])

        assert result.total_changes == 4
        assert result.added_count == 2
        assert result.modified_count == 1
        assert result.deleted_count == 1


class TestMigrationInfo:
    """Tests for MigrationInfo model."""

    def test_needs_migration(self):
        """Test needs_migration property."""
        # Needs migration
        info = MigrationInfo(
            current_version="1.0.0",
            target_version="2.0.0",
            steps=["Add column"]
        )
        assert info.needs_migration is True

        # Up to date
        info = MigrationInfo(
            current_version="2.0.0",
            target_version="2.0.0",
            steps=[]
        )
        assert info.needs_migration is False


class TestTimelineResult:
    """Tests for TimelineResult model."""

    def test_entry_counts(self):
        """Test entry count properties."""
        result = TimelineResult(entries=[
            TimelineEntry(
                timestamp=datetime.now(),
                tool_name="read",
                status="success",
            ),
            TimelineEntry(
                timestamp=datetime.now(),
                tool_name="write",
                status="success",
            ),
            TimelineEntry(
                timestamp=datetime.now(),
                tool_name="delete",
                status="error",
                error="Not found"
            ),
        ])

        assert result.total_entries == 3
        assert result.success_count == 2
        assert result.error_count == 1
```

## Testing

### Manual Testing

```python
from agentfs_pydantic.models import InitOptions, EncryptionConfig, SandboxOptions

# Test model creation
init_opts = InitOptions(
    force=True,
    encryption=EncryptionConfig(key="0" * 64, cipher="aes256gcm")
)
print(f"Init options: {init_opts}")

# Test validation
sandbox_opts = SandboxOptions(
    session="test-session",
    allowed_paths=["/tmp", "/home/user/.cache"],
    experimental_sandbox=True
)
print(f"Sandbox options: {sandbox_opts}")

# Test model_dump for CLI usage
print(init_opts.model_dump(exclude_none=True))
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_enhanced_models.py -v
```

## Success Criteria

- [ ] All configuration models created (Init, Exec, Sandbox, Mount, Sync, Timeline, Server configs)
- [ ] All result models created (MountInfo, SyncStats, DiffResult, MigrationInfo, TimelineResult)
- [ ] Encryption validation works correctly (key length checks)
- [ ] All models have proper examples in docstrings
- [ ] Helper properties work (e.g., `DiffResult.added_count`)
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Validation error for encryption key
- **Solution**: Ensure key is hex and correct length (32 for 128-bit, 64 for 256-bit)

**Issue**: Model import errors
- **Solution**: Update `__init__.py` with all new model names

## Next Steps

Once this step is complete:
1. Proceed to [Step 3: Init/Exec/Run Operations](./DEV_GUIDE-STEP_03.md)
2. These models will be used by all CLI wrappers

## Design Notes

- All optional fields have defaults or `None`
- Validation happens at model creation time
- Models can be serialized with `model_dump()` for CLI usage
- Helper properties make models more convenient to use
