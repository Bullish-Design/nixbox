# nixbox Library Functionality Brainstorm

Based on the AgentFS CLI reference and the goal of creating a slim Pydantic shim library for easy developer interaction with AgentFS in devenv.sh environments.

## Current State

The `agentfs-pydantic` library currently provides:
- ✅ Pydantic models for filesystem entries, stats, tool calls, KV entries
- ✅ View-based query interface for filesystem traversal
- ✅ Type-safe options for AgentFS initialization
- ✅ Async-first API design

## Missing Functionality - Core Wrappers Needed

### 1. Lifecycle Management (Start/Stop)

**Goal**: Make it trivial to start/stop AgentFS instances in Python

```python
from nixbox import AgentFSManager, AgentFSConfig

# Configuration with Pydantic validation
config = AgentFSConfig(
    id="my-agent",
    host="127.0.0.1",
    port=8081,
    data_dir=".agentfs",
    log_level="info"
)

# Context manager for automatic lifecycle
async with AgentFSManager(config) as manager:
    # AgentFS is running
    agent = await manager.get_client()
    # ... do work ...
# AgentFS automatically stopped

# Or manual control
manager = AgentFSManager(config)
await manager.start()
await manager.stop()
```

**Implementation needs**:
- `AgentFSConfig` - Pydantic model for all init/serve options
- `AgentFSManager` - Process lifecycle management
- Background process spawning (subprocess/asyncio)
- Health checks and readiness probes
- Graceful shutdown handling

### 2. CLI Command Wrappers

**Goal**: Type-safe Python wrappers for all agentfs CLI commands

#### 2.1 Init Operations

```python
from nixbox import AgentFSCLI, InitOptions, EncryptionConfig

cli = AgentFSCLI()

# Basic init
await cli.init("my-agent")

# Init with overlay
await cli.init(
    "my-overlay",
    options=InitOptions(
        base="/path/to/project",  # Copy-on-write base
        force=True
    )
)

# Init with encryption
await cli.init(
    "secure-agent",
    options=InitOptions(
        encryption=EncryptionConfig(
            key="...",  # Auto-validated hex length
            cipher="aes256gcm"
        )
    )
)

# Init and run command
result = await cli.init_and_exec(
    "temp-agent",
    command=["make", "build"],
    options=InitOptions(base="/project")
)
```

#### 2.2 Exec Operations

```python
from nixbox import ExecOptions

# Run command in existing AgentFS
result = await cli.exec(
    "my-agent",
    command=["ls", "-la"],
    options=ExecOptions(
        backend="fuse",  # or "nfs"
        encryption=EncryptionConfig(key=..., cipher=...)
    )
)

print(result.stdout)
print(result.stderr)
print(result.return_code)
```

#### 2.3 Run (Sandbox) Operations

```python
from nixbox import SandboxOptions

# Sandboxed execution with COW filesystem
result = await cli.run(
    command=["python", "script.py"],
    options=SandboxOptions(
        session="persistent-session",  # Named session
        allowed_paths=["/home/user/.cache"],
        no_default_allows=False,
        experimental_sandbox=True,
        strace=True  # Debug syscall interception
    )
)
```

#### 2.4 Mount Operations

```python
from nixbox import MountOptions
import asyncio

# Mount filesystem
mount_point = await cli.mount(
    "my-agent",
    path="/tmp/myagent",
    options=MountOptions(
        auto_unmount=True,
        foreground=False,
        allow_root=True,
        uid=1000,
        gid=1000
    )
)

# List mounts
mounts = await cli.list_mounts()
for mount in mounts:
    print(f"{mount.id} -> {mount.mount_point}")

# Unmount
await cli.unmount("/tmp/myagent")
```

#### 2.5 Filesystem Operations

```python
from nixbox import FSOperations

# Direct filesystem operations without mounting
fs = FSOperations("my-agent")

# List directory
entries = await fs.ls("/path", recursive=True)

# Read file
content = await fs.cat("/config.json")

# Write file
await fs.write("/notes.txt", "content here")

# These should integrate with existing View interface
```

#### 2.6 Sync Operations

```python
from nixbox import SyncConfig, SyncStats

# Configure sync
sync = SyncConfig(
    id_or_path="my-agent",
    remote_url="libsql://...",
    auth_token="...",
    partial_prefetch=True
)

# Sync operations
await cli.sync_pull(sync)
await cli.sync_push(sync)
await cli.sync_checkpoint(sync)

# Get stats
stats: SyncStats = await cli.sync_stats(sync)
print(f"Last sync: {stats.last_sync}")
print(f"Pending changes: {stats.pending_changes}")
```

#### 2.7 Timeline Operations

```python
from nixbox import TimelineQuery, TimelineFormat

# Query timeline
timeline = await cli.timeline(
    "my-agent",
    query=TimelineQuery(
        limit=100,
        filter_tool="write_file",
        status="success",
        format=TimelineFormat.JSON
    )
)

for entry in timeline.entries:
    print(f"{entry.timestamp}: {entry.tool_name} - {entry.status}")
```

#### 2.8 Diff Operations

```python
# Show overlay changes
diff = await cli.diff("my-overlay")

for change in diff.changes:
    print(f"{change.type}: {change.path}")
    if change.type == "modified":
        print(f"  Before: {change.before_size} bytes")
        print(f"  After: {change.after_size} bytes")
```

#### 2.9 Migration Operations

```python
from nixbox import MigrationInfo

# Check pending migrations
migration_info = await cli.migrate(
    "my-agent",
    dry_run=True
)

print(f"Current: {migration_info.current_version}")
print(f"Target: {migration_info.target_version}")
print(f"Steps: {len(migration_info.steps)}")

# Apply migrations
await cli.migrate("my-agent", dry_run=False)
```

#### 2.10 Serve Operations

```python
from nixbox import MCPServerConfig, NFSServerConfig

# Start MCP server (Model Context Protocol)
mcp_server = await cli.serve_mcp(
    "my-agent",
    config=MCPServerConfig(
        tools=["read_file", "write_file", "kv_get", "kv_set"]
    )
)

# Start NFS server
nfs_server = await cli.serve_nfs(
    "my-agent",
    config=NFSServerConfig(
        bind="127.0.0.1",
        port=11111
    )
)

# Both return server handles with .stop() methods
await nfs_server.stop()
```

### 3. Enhanced Models

Expand the existing Pydantic models to cover all CLI concepts:

```python
# Config models
class InitOptions(BaseModel):
    force: bool = False
    base: Optional[Path] = None
    encryption: Optional[EncryptionConfig] = None
    sync_config: Optional[SyncRemoteConfig] = None
    command: Optional[list[str]] = None
    backend: Optional[Literal["fuse", "nfs"]] = None

class EncryptionConfig(BaseModel):
    key: str = Field(..., pattern=r"^[0-9a-fA-F]{32,64}$")
    cipher: Literal["aes256gcm", "aes128gcm", "aegis256", "aegis128l"]

    @field_validator("key")
    @classmethod
    def validate_key_length(cls, v, info):
        cipher = info.data.get("cipher")
        required_length = 64 if "256" in cipher else 32
        if len(v) != required_length:
            raise ValueError(f"{cipher} requires {required_length} hex chars")
        return v

class MountInfo(BaseModel):
    id: str
    mount_point: Path
    backend: Literal["fuse", "nfs"]
    pid: int

class SyncStats(BaseModel):
    last_sync: Optional[datetime]
    pending_changes: int
    total_synced: int

class DiffChange(BaseModel):
    type: Literal["added", "modified", "deleted"]
    path: str
    before_size: Optional[int] = None
    after_size: Optional[int] = None

class MigrationInfo(BaseModel):
    current_version: str
    target_version: str
    steps: list[str]

class CommandResult(BaseModel):
    stdout: str
    stderr: str
    return_code: int
    duration: float
```

### 4. Integration with devenv.sh

**Goal**: Seamless integration with devenv.sh environments

```python
from nixbox import DevEnvIntegration

# Auto-detect devenv.sh environment variables
integration = DevEnvIntegration.from_env()

# Uses AGENTFS_HOST, AGENTFS_PORT, AGENTFS_DATA_DIR, etc.
async with integration.connect() as client:
    # Already connected to the devenv.sh managed AgentFS
    pass

# Or explicit configuration
integration = DevEnvIntegration(
    host=os.getenv("AGENTFS_HOST", "127.0.0.1"),
    port=int(os.getenv("AGENTFS_PORT", "8081")),
    data_dir=Path(os.getenv("AGENTFS_DATA_DIR", ".devenv/state/agentfs")),
    db_name=os.getenv("AGENTFS_DB_NAME", "sandbox")
)
```

### 5. High-Level Convenience APIs

Make common workflows trivial:

```python
from nixbox import quick_sandbox, temporary_agent

# Quick sandbox execution
@quick_sandbox(session="my-session")
async def build_project():
    """Runs in sandboxed environment automatically"""
    subprocess.run(["make", "build"])

# Temporary agent with auto-cleanup
async with temporary_agent(base="/my/project") as agent:
    # Agent created with overlay on /my/project
    await agent.fs.write_file("/output.txt", "result")
    # Agent automatically destroyed on exit

# Or keep the database
async with temporary_agent(base="/my/project", keep=True) as agent:
    print(f"Agent DB at: {agent.db_path}")
```

### 6. Async Context Managers

**All long-running operations should support async context managers:**

```python
# Mount contexts
async with cli.mount_context("my-agent", "/tmp/mount") as mount:
    # Filesystem is mounted
    files = mount.path.glob("**/*.txt")
# Automatically unmounted

# Server contexts
async with cli.mcp_server_context("my-agent") as server:
    print(f"MCP server at {server.url}")
    # Server running
# Automatically stopped

# Sandbox contexts
async with cli.sandbox_context(session="test") as sandbox:
    result = await sandbox.run(["pytest"])
# Session persisted for next run
```

### 7. Error Handling

**Type-safe error hierarchy:**

```python
from nixbox.exceptions import (
    AgentFSError,
    AgentNotFoundError,
    MountError,
    SyncError,
    EncryptionError,
    MigrationError
)

try:
    await cli.mount("nonexistent", "/tmp/test")
except AgentNotFoundError as e:
    print(f"Agent not found: {e.agent_id}")
except MountError as e:
    print(f"Mount failed: {e.reason}")
```

### 8. Observability & Logging

```python
from nixbox import AgentFSObserver

# Register observers for lifecycle events
observer = AgentFSObserver()

@observer.on_mount
async def handle_mount(event):
    print(f"Mounted: {event.agent_id} at {event.mount_point}")

@observer.on_tool_call
async def handle_tool_call(event):
    print(f"Tool called: {event.name} with {event.parameters}")

manager = AgentFSManager(config, observer=observer)
```

### 9. Testing Utilities

```python
from nixbox.testing import AgentFSTestCase, mock_agent

class MyTest(AgentFSTestCase):
    async def test_with_agent(self):
        # Automatically provides a fresh agent per test
        await self.agent.fs.write_file("/test.txt", "data")
        files = await self.query("*.txt").load()
        self.assertEqual(len(files), 1)

# Or use fixture-style
async def test_something():
    async with mock_agent() as agent:
        # Temporary agent, auto-cleaned
        pass
```

### 10. CLI Binary Wrapper

Wrap the agentfs binary with subprocess management:

```python
from nixbox.cli import AgentFSBinary

binary = AgentFSBinary()  # Auto-finds in PATH or uses explicit path

# All CLI operations use this under the hood
result = await binary.execute(
    ["init", "my-agent", "--force"],
    check=True,  # Raise on non-zero exit
    capture_output=True,
    timeout=30.0
)
```

## Architecture Recommendations

### Module Structure

```
nixbox/
├── __init__.py           # Main exports
├── models.py             # All Pydantic models (expand existing)
├── cli.py                # CLI wrapper (AgentFSCLI, AgentFSBinary)
├── manager.py            # Lifecycle management (AgentFSManager)
├── devenv.py             # devenv.sh integration
├── view.py               # Existing View interface (keep)
├── sync.py               # Sync operations
├── mount.py              # Mount/unmount operations
├── serve.py              # MCP/NFS servers
├── exceptions.py         # Error hierarchy
├── observer.py           # Event observers
└── testing.py            # Test utilities
```

### Design Principles

1. **Type Safety First**: Everything validated with Pydantic
2. **Async Native**: All I/O operations are async
3. **Context Managers**: RAII pattern for resource management
4. **Sensible Defaults**: Work out-of-box for common cases
5. **Composable**: Small, focused functions that combine well
6. **Observable**: Events for monitoring and debugging
7. **Testable**: Built-in test utilities
8. **devenv.sh Native**: First-class integration with devenv environments

### Implementation Priorities

**Phase 1 - Core (MVP)**:
1. ✅ Basic models (already done)
2. ✅ View interface (already done)
3. 🔲 CLI binary wrapper (subprocess management)
4. 🔲 Init/Exec/Run operations
5. 🔲 AgentFSManager lifecycle
6. 🔲 devenv.sh integration

**Phase 2 - Essential**:
7. 🔲 Mount/unmount operations
8. 🔲 Filesystem operations (ls/cat/write)
9. 🔲 Error handling hierarchy
10. 🔲 Context managers for all resources

**Phase 3 - Advanced**:
11. 🔲 Sync operations
12. 🔲 Timeline queries
13. 🔲 Diff operations
14. 🔲 Migration support
15. 🔲 MCP/NFS servers

**Phase 4 - Quality**:
16. 🔲 Observer/event system
17. 🔲 Testing utilities
18. 🔲 High-level convenience APIs
19. 🔲 Comprehensive documentation
20. 🔲 Example workflows

## Example End-to-End Workflow

Here's what the complete library should enable:

```python
import asyncio
from nixbox import (
    DevEnvIntegration,
    AgentFSCLI,
    InitOptions,
    SandboxOptions,
    View,
    ViewQuery
)

async def main():
    # Connect to devenv.sh managed AgentFS
    integration = DevEnvIntegration.from_env()
    cli = AgentFSCLI()

    # Create a new agent with overlay
    await cli.init(
        "build-agent",
        options=InitOptions(base="/my/project")
    )

    # Run sandboxed build
    result = await cli.run(
        command=["make", "build"],
        options=SandboxOptions(
            session="build-session",
            allowed_paths=["~/.cache"]
        )
    )

    if result.return_code != 0:
        print(f"Build failed: {result.stderr}")
        return

    # Query build outputs
    async with integration.connect() as agent:
        view = View(
            agent=agent,
            query=ViewQuery(
                path_pattern="*.so",
                recursive=True
            )
        )

        artifacts = await view.load()
        print(f"Built {len(artifacts)} artifacts:")
        for artifact in artifacts:
            print(f"  {artifact.path} ({artifact.stats.size} bytes)")

    # View timeline
    timeline = await cli.timeline("build-agent", limit=50)
    print(f"\nRecent activity: {len(timeline.entries)} operations")

if __name__ == "__main__":
    asyncio.run(main())
```

## Open Questions

1. **Binary location**: Should we vendor the agentfs binary or require it in PATH?
2. **Sync authentication**: How to handle TURSO_DB_AUTH_TOKEN securely?
3. **Platform differences**: How to abstract FUSE (Linux) vs NFS (macOS) backends?
4. **Process management**: Use asyncio.subprocess, trio, or external process manager?
5. **State management**: Where to track running servers/mounts (in-memory, sqlite, etc.)?
6. **Configuration precedence**: ENV vars vs. config files vs. code?

## Success Metrics

A successful nixbox library will:
- ✅ Reduce AgentFS integration code by 80%
- ✅ Provide type safety for all operations
- ✅ Work seamlessly in devenv.sh environments
- ✅ Enable TDD with built-in test utilities
- ✅ Have comprehensive documentation with examples
- ✅ Support both simple scripts and complex applications
