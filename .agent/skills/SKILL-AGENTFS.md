# SKILL: Working with AgentFS

This guide covers working with the AgentFS SDK in the Nixbox/Cairn project.

## Overview

**AgentFS** is a SQLite-based virtual filesystem with overlay semantics. Each agent gets its own database that can shadow files from a base layer.

### Key Concepts

- **Stable Layer**: Ground truth database (`stable.db`)
- **Overlay**: Agent-specific database that inherits from stable
- **Copy-on-Write**: Reads fall through to stable, writes go to overlay
- **Inode-based**: Files are content-addressed, supporting hard links

## Installation

AgentFS is provided via the `agentfs.nix` module:

```nix
# devenv.nix
{
  imports = [
    ./nixbox/modules/agentfs.nix
  ];
}
```

This provides:
- `agentfs` CLI tool
- AgentFS process (via `devenv up`)
- Environment variables (`AGENTFS_*`)

## Python SDK Usage

### Opening a Filesystem

```python
from agentfs_sdk import AgentFS, AgentFSOptions

# Open stable layer
stable = await AgentFS.open(AgentFSOptions(id="stable"))

# Open agent overlay
agent = await AgentFS.open(AgentFSOptions(id="agent-abc123"))
```

### File Operations

```python
# Write file
await stable.fs.write_file("main.py", b"print('hello')")

# Read file
content = await stable.fs.read_file("main.py")
print(content)  # b"print('hello')"

# List directory
entries = await stable.fs.readdir("/")
for entry in entries:
    print(f"{entry.name}: {entry.type}")

# Check file stats
stat = await stable.fs.stat("main.py")
print(f"Size: {stat.size}, Modified: {stat.mtime}")

# Remove file
await stable.fs.remove("old_file.py")

# Create directory
await stable.fs.mkdir("src/utils")
```

### Overlay Semantics

```python
# Setup
stable = await AgentFS.open(AgentFSOptions(id="stable"))
agent = await AgentFS.open(AgentFSOptions(id="agent-001"))

# Write to stable
await stable.fs.write_file("file.txt", b"original")

# Read from agent (falls through to stable)
content = await agent.fs.read_file("file.txt")
print(content)  # b"original"

# Write to agent (only to overlay)
await agent.fs.write_file("file.txt", b"modified")

# Read from agent (from overlay)
content = await agent.fs.read_file("file.txt")
print(content)  # b"modified"

# Read from stable (unchanged)
content = await stable.fs.read_file("file.txt")
print(content)  # b"original"
```

### KV Store

```python
# Set key-value
await stable.kv.set("config:theme", "dark")

# Get value
theme = await stable.kv.get("config:theme")
print(theme)  # "dark"

# List keys by prefix
entries = await stable.kv.list("config:")
for entry in entries:
    print(f"{entry.key} = {entry.value}")

# Delete key
await stable.kv.delete("config:theme")
```

### Tool Call Tracking

```python
# Tool calls are automatically logged when using external functions
# Query them:
calls = await stable.tools.list()
for call in calls:
    print(f"{call.name}: {call.duration_ms}ms")

# Get stats
stats = await stable.tools.stats()
for stat in stats:
    print(f"{stat.name}: {stat.total_calls} calls, {stat.avg_duration_ms}ms avg")
```

## Pydantic Models

Use `agentfs-pydantic` for type safety:

```python
from agentfs_pydantic import (
    AgentFSOptions,
    FileEntry,
    FileStats,
    View,
    ViewQuery,
)

# Validated options
options = AgentFSOptions(id="my-agent")
agent = await AgentFS.open(options.model_dump())

# Query interface
view = View(
    agent=agent,
    query=ViewQuery(
        path_pattern="*.py",
        recursive=True,
        include_content=True
    )
)

files = await view.load()
for file in files:
    print(f"{file.path}: {file.stats.size} bytes")
```

## Common Patterns

### Initialize Stable from Project

```python
async def init_stable(project_root: Path):
    """Copy project files into stable.db"""
    stable = await AgentFS.open(AgentFSOptions(id="stable"))

    for file_path in project_root.rglob("*"):
        if not file_path.is_file():
            continue

        # Skip hidden directories
        if any(part.startswith(".") for part in file_path.parts):
            continue

        rel_path = str(file_path.relative_to(project_root))
        content = file_path.read_bytes()
        await stable.fs.write_file(rel_path, content)
```

### Sync Changes to Stable

```python
from watchfiles import awatch

async def watch_and_sync(project_root: Path):
    """Watch filesystem and sync changes to stable"""
    stable = await AgentFS.open(AgentFSOptions(id="stable"))

    async for changes in awatch(project_root):
        for change_type, path_str in changes:
            path = Path(path_str)

            if not path.is_relative_to(project_root):
                continue

            rel_path = str(path.relative_to(project_root))

            if change_type in (Change.added, Change.modified):
                if path.is_file():
                    content = path.read_bytes()
                    await stable.fs.write_file(rel_path, content)

            elif change_type == Change.deleted:
                await stable.fs.remove(rel_path)
```

### Merge Overlay to Stable

```python
async def merge_overlay(agent_id: str, changed_files: list[str]):
    """Copy changed files from agent overlay to stable"""
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    agent = await AgentFS.open(AgentFSOptions(id=agent_id))

    for path in changed_files:
        content = await agent.fs.read_file(path)
        await stable.fs.write_file(path, content)
```

### Generate Diff

```python
import difflib

async def generate_diff(agent_id: str, file_path: str) -> str:
    """Generate unified diff between stable and agent overlay"""
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    agent = await AgentFS.open(AgentFSOptions(id=agent_id))

    stable_content = await stable.fs.read_file(file_path)
    agent_content = await agent.fs.read_file(file_path)

    stable_lines = stable_content.decode().splitlines(keepends=True)
    agent_lines = agent_content.decode().splitlines(keepends=True)

    diff = difflib.unified_diff(
        stable_lines,
        agent_lines,
        fromfile=f"stable/{file_path}",
        tofile=f"agent/{file_path}"
    )

    return "".join(diff)
```

### Materialize Workspace

```python
async def materialize_workspace(agent_id: str, workspace_path: Path):
    """Copy agent overlay to disk for preview"""
    agent = await AgentFS.open(AgentFSOptions(id=agent_id))

    # Create workspace directory
    workspace_path.mkdir(parents=True, exist_ok=True)

    # Get all files (including those from stable via overlay)
    async def walk_directory(path: str = "/"):
        entries = await agent.fs.readdir(path)

        for entry in entries:
            full_path = f"{path}/{entry.name}".lstrip("/")

            if entry.type == "directory":
                # Recurse
                yield from walk_directory(full_path)
            else:
                yield full_path

    # Copy files
    async for file_path in walk_directory():
        content = await agent.fs.read_file(file_path)
        dest = workspace_path / file_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
```

## Performance Tips

### Batch Operations

```python
# ❌ Slow: One transaction per file
for path in files:
    await agent.fs.write_file(path, content)

# ✅ Fast: Batch writes
async with agent.fs.transaction():
    for path in files:
        await agent.fs.write_file(path, content)
```

### Use KV for Metadata

```python
# ❌ Slow: Create file for every piece of metadata
await agent.fs.write_file(".meta/agent_id.txt", agent_id.encode())
await agent.fs.write_file(".meta/task.txt", task.encode())

# ✅ Fast: Use KV store
await agent.kv.set("agent_id", agent_id)
await agent.kv.set("task", task)
```

### Query Efficiently

```python
# ❌ Slow: Load all content
view = View(agent, ViewQuery(path_pattern="**/*", include_content=True))
all_files = await view.load()  # Loads gigabytes

# ✅ Fast: Query without content first
view = View(agent, ViewQuery(path_pattern="**/*.py", include_content=False))
py_files = await view.load()  # Just metadata

# Then load content only for files you need
for file in py_files:
    if needs_content(file):
        content = await agent.fs.read_file(file.path)
```

## Error Handling

```python
from agentfs_sdk import (
    FileNotFoundError,
    PermissionError,
    AgentFSError,
)

# Handle missing files
try:
    content = await agent.fs.read_file("missing.txt")
except FileNotFoundError:
    # File doesn't exist in overlay or stable
    content = b"default content"

# Handle permission errors
try:
    await agent.fs.remove("/system/important.txt")
except PermissionError:
    # Operation not allowed
    pass

# Catch all AgentFS errors
try:
    await agent.fs.write_file("file.txt", content)
except AgentFSError as e:
    logger.error(f"AgentFS error: {e}")
```

## Testing

### Unit Tests

```python
import pytest
from agentfs_sdk import AgentFS, AgentFSOptions

@pytest.fixture
async def stable_fs():
    """Create temporary stable filesystem"""
    fs = await AgentFS.open(AgentFSOptions(id="test-stable"))
    yield fs
    await fs.close()

@pytest.mark.asyncio
async def test_write_read(stable_fs):
    """Test basic write/read operations"""
    await stable_fs.fs.write_file("test.txt", b"hello")
    content = await stable_fs.fs.read_file("test.txt")
    assert content == b"hello"

@pytest.mark.asyncio
async def test_overlay_isolation():
    """Test overlay doesn't affect stable"""
    stable = await AgentFS.open(AgentFSOptions(id="test-stable"))
    agent = await AgentFS.open(AgentFSOptions(id="test-agent"))

    await stable.fs.write_file("file.txt", b"original")
    await agent.fs.write_file("file.txt", b"modified")

    stable_content = await stable.fs.read_file("file.txt")
    agent_content = await agent.fs.read_file("file.txt")

    assert stable_content == b"original"
    assert agent_content == b"modified"
```

## Debugging

### Inspect Database

```bash
# Open database with sqlite3
sqlite3 .agentfs/stable.db

# List tables
.tables

# Query inodes
SELECT * FROM inodes LIMIT 10;

# Query directory entries
SELECT * FROM directory_entries;

# Query KV store
SELECT * FROM kv_store;

# Query tool calls
SELECT name, duration_ms FROM tool_calls ORDER BY started_at DESC LIMIT 10;
```

### Logging

```python
import logging

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("agentfs")

# AgentFS will log operations
await agent.fs.write_file("file.txt", b"content")
# DEBUG:agentfs: Writing file: file.txt (7 bytes)
```

## References

- [AgentFS Specification](https://docs.turso.tech/agentfs)
- [AgentFS Python SDK](https://docs.turso.tech/agentfs/python-sdk)
- [agentfs-pydantic Library](../../agentfs-pydantic/README.md)
- [SPEC.md](../../SPEC.md) - Storage layer architecture

## See Also

- [SKILL-MONTY.md](SKILL-MONTY.md) - Execution layer
- [SKILL-DEVENV.md](SKILL-DEVENV.md) - Nix integration
