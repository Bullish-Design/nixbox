# Step 18: Documentation & Examples

**Phase**: 4 - Quality
**Difficulty**: Easy
**Estimated Time**: 4-6 hours
**Prerequisites**: All previous steps (1-17)

## Objective

Create comprehensive documentation and examples:
- Complete API documentation
- Usage examples for all features
- Tutorial walkthroughs
- Best practices guide
- Migration guide from direct CLI usage
- Troubleshooting guide

## Why This Matters

Good documentation:
- Lowers barrier to entry
- Reduces support burden
- Showcases capabilities
- Enables self-service learning
- Improves adoption

## Implementation Guide

### 18.1 Create Examples Directory

Create example scripts demonstrating all major features:

Create `/home/user/nixbox/agentfs-pydantic/examples/01_basic_usage.py`:

```python
"""Basic AgentFS usage examples.

This example demonstrates the fundamental operations:
- Creating agents
- Writing and reading files
- Basic filesystem operations
"""

import asyncio
from agentfs_pydantic import quick_init


async def main():
    print("=== Basic AgentFS Usage ===\n")

    # 1. Create an agent
    print("1. Creating agent...")
    fs = await quick_init("example-agent", force=True)
    print("✓ Agent created\n")

    # 2. Write files
    print("2. Writing files...")
    await fs.write("/hello.txt", "Hello, AgentFS!")
    await fs.write("/data.json", '{"key": "value"}')
    print("✓ Files written\n")

    # 3. Read files
    print("3. Reading files...")
    content = await fs.cat("/hello.txt")
    print(f"Content: {content}\n")

    # 4. Check existence
    print("4. Checking file existence...")
    exists = await fs.exists("/hello.txt")
    print(f"File exists: {exists}\n")

    # 5. Create directories
    print("5. Creating directories...")
    await fs.mkdir("/documents/reports", parents=True)
    print("✓ Directories created\n")

    # 6. List directory
    print("6. Listing root directory...")
    entries = await fs.ls("/")
    for entry in entries:
        print(f"  {entry.path}")

    print("\n✓ Example complete!")


if __name__ == "__main__":
    asyncio.run(main())
```

Create `/home/user/nixbox/agentfs-pydantic/examples/02_overlay_workflow.py`:

```python
"""Overlay filesystem workflow.

Demonstrates using AgentFS as a copy-on-write overlay on an existing project.
"""

import asyncio
import tempfile
from pathlib import Path
from agentfs_pydantic import quick_init, quick_diff, overlay_workspace


async def main():
    print("=== Overlay Workflow Example ===\n")

    # Create a mock project
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        (project / "README.md").write_text("# My Project")
        (project / "src").mkdir()
        (project / "src" / "main.py").write_text("print('Hello')")

        print(f"1. Created project at: {project}\n")

        # Create overlay
        print("2. Creating overlay agent...")
        fs = await quick_init("overlay-example", overlay_on=project, force=True)
        print("✓ Overlay created\n")

        # Make changes
        print("3. Making changes in overlay...")
        await fs.write("/NEW_FILE.txt", "This is new")
        await fs.write("/src/main.py", "print('Hello, overlay!')")
        print("✓ Changes made\n")

        # Check diff
        print("4. Checking differences...")
        diff = await quick_diff("overlay-example")
        print(f"Added: {diff['added']}")
        print(f"Modified: {diff['modified']}")
        print(f"Deleted: {diff['deleted']}\n")

        # Verify original unchanged
        print("5. Verifying original project unchanged...")
        original_content = (project / "src" / "main.py").read_text()
        print(f"Original still says: {original_content}")
        assert original_content == "print('Hello')"
        print("✓ Original preserved\n")

        # Using context manager
        print("6. Using overlay_workspace context...")
        async with overlay_workspace(project, mount=False) as (agent_id, workspace_fs):
            await workspace_fs.write("/context.txt", "Created in context")
            print(f"✓ Created file in {agent_id}\n")

    print("✓ Example complete!")


if __name__ == "__main__":
    asyncio.run(main())
```

Create `/home/user/nixbox/agentfs-pydantic/examples/03_sync_workflow.py`:

```python
"""Sync workflow with remote database.

Demonstrates syncing AgentFS with a remote Turso database.
Requires: TURSO_URL and TURSO_DB_AUTH_TOKEN environment variables.
"""

import asyncio
import os
from agentfs_pydantic import (
    quick_init,
    SyncManager,
    auto_sync,
    FSOperations,
)


async def main():
    print("=== Sync Workflow Example ===\n")

    # Check environment
    remote_url = os.getenv("TURSO_URL")
    if not remote_url:
        print("⚠ Set TURSO_URL environment variable to run this example")
        return

    print(f"Remote URL: {remote_url}\n")

    # 1. Manual sync
    print("1. Manual sync workflow...")
    fs = await quick_init("sync-example", force=True)
    await fs.write("/synced.txt", "This will be synced")

    manager = SyncManager("sync-example", remote_url)
    await manager.push()
    print("✓ Pushed to remote\n")

    # 2. Auto-sync context
    print("2. Auto-sync context...")
    async with auto_sync("sync-example", remote_url) as sync_manager:
        # Changes pulled automatically
        fs = FSOperations("sync-example")
        await fs.write("/auto.txt", "Auto-synced")
        # Changes pushed automatically on exit
    print("✓ Auto-synced\n")

    # 3. Check sync stats
    print("3. Sync statistics...")
    stats = await manager.stats()
    print(f"Last sync: {stats.last_sync}")
    print(f"Pending: {stats.pending_changes}\n")

    print("✓ Example complete!")


if __name__ == "__main__":
    asyncio.run(main())
```

Create `/home/user/nixbox/agentfs-pydantic/examples/04_testing_example.py`:

```python
"""Testing with AgentFS utilities.

Demonstrates using testing utilities for unit and integration tests.
"""

import asyncio
from agentfs_pydantic.testing import mock_agent, temp_project, TestHelpers


async def test_file_operations():
    """Test file operations with mock agent."""
    print("=== Testing Example ===\n")

    print("1. Using mock_agent for testing...")
    async with mock_agent(files={"/test.txt": "initial"}) as agent:
        # File already set up
        await agent.assert_file_exists("/test.txt")
        await agent.assert_file_content("/test.txt", "initial")

        # Make changes
        await agent.fs.write("/test.txt", "modified")
        await agent.assert_file_content("/test.txt", "modified")
        print("✓ Mock agent test passed\n")

    print("2. Using temp_project...")
    async with temp_project(files={
        "README.md": "# Test Project",
        "src/main.py": "print('test')"
    }) as project:
        assert (project / "README.md").exists()
        assert (project / "src" / "main.py").exists()
        print(f"✓ Temp project created at: {project}\n")

    print("3. Using test helpers...")
    data = TestHelpers.generate_test_data(100)
    print(f"✓ Generated {len(data)} bytes of test data\n")

    print("✓ All tests passed!")


if __name__ == "__main__":
    asyncio.run(test_file_operations())
```

Create `/home/user/nixbox/agentfs-pydantic/examples/05_advanced_patterns.py`:

```python
"""Advanced AgentFS patterns.

Demonstrates advanced usage patterns:
- Event monitoring
- Server operations
- Timeline analysis
- Workflow automation
"""

import asyncio
from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    EventEmitter,
    EventType,
    BuiltinHandlers,
    mcp_server,
    TimelineAnalyzer,
    with_temp_agent,
)


async def main():
    print("=== Advanced Patterns Example ===\n")

    # 1. Event monitoring
    print("1. Event monitoring...")
    emitter = EventEmitter()

    # Add console logger
    emitter.register(BuiltinHandlers.console_logger(verbose=True))

    # Add error collector
    error_handler, get_errors = BuiltinHandlers.error_collector()
    emitter.register(error_handler)

    # Custom handler
    @emitter.on(EventType.FILE_WRITE)
    def on_write(event):
        print(f"📝 File written: {event.data.get('path', 'unknown')}")

    cli = AgentFSCLI(emitter=emitter)
    await cli.init("events-example", options=InitOptions(force=True))
    print("✓ Events monitored\n")

    # 2. MCP Server
    print("2. Starting MCP server...")
    async with mcp_server("events-example") as server:
        print(f"✓ MCP server running at: {server.url}")
        print("  (Server auto-stopped on context exit)\n")

    # 3. Timeline analysis
    print("3. Timeline analysis...")
    analyzer = TimelineAnalyzer("events-example")
    await analyzer.load()
    summary = analyzer.summary()
    print(f"Operations: {summary['total_entries']}")
    print(f"Success rate: {summary['success_rate']:.1f}%")
    print(f"Tool usage: {summary['tool_stats']}\n")

    # 4. Decorator pattern
    print("4. Using decorator pattern...")
    @with_temp_agent()
    async def process_data(agent_id, fs):
        await fs.write("/processed.txt", "Data processed")
        return f"Processed in {agent_id}"

    result = await process_data()
    print(f"✓ {result}\n")

    print("✓ Example complete!")


if __name__ == "__main__":
    asyncio.run(main())
```

### 18.2 Create Documentation Files

Create `/home/user/nixbox/agentfs-pydantic/docs/README.md`:

```markdown
# AgentFS Pydantic Library Documentation

Welcome to the agentfs-pydantic library documentation!

## Quick Links

- [Getting Started](getting_started.md)
- [API Reference](api_reference.md)
- [Examples](../examples/)
- [Best Practices](best_practices.md)
- [Troubleshooting](troubleshooting.md)

## What is agentfs-pydantic?

A type-safe Python library for interacting with AgentFS, providing:

- **Type Safety**: Pydantic models for all operations
- **Async Native**: All I/O operations are async
- **Context Managers**: Automatic resource cleanup
- **devenv.sh Integration**: First-class devenv support
- **Testing Utilities**: Built-in test helpers
- **Event System**: Observable operations

## Installation

```bash
# From PyPI (when published)
pip install agentfs-pydantic

# Development install
cd agentfs-pydantic
uv sync
```

## Quick Start

```python
import asyncio
from agentfs_pydantic import quick_init

async def main():
    # Create an agent
    fs = await quick_init("my-agent")

    # Write files
    await fs.write("/hello.txt", "Hello, AgentFS!")

    # Read files
    content = await fs.cat("/hello.txt")
    print(content)

asyncio.run(main())
```

## Core Concepts

### Agents

AgentFS agents are isolated filesystem environments stored in SQLite databases.

### Overlays

Copy-on-write overlays let you modify files without changing the original.

### Sync

Sync with remote Turso databases for distributed workflows.

### Events

Monitor all operations with the event system.

## Examples

See the [examples directory](../examples/) for complete examples:

- `01_basic_usage.py` - Fundamental operations
- `02_overlay_workflow.py` - Copy-on-write overlays
- `03_sync_workflow.py` - Remote sync
- `04_testing_example.py` - Testing utilities
- `05_advanced_patterns.py` - Advanced features

## Next Steps

1. Read the [Getting Started Guide](getting_started.md)
2. Explore the [Examples](../examples/)
3. Check out [Best Practices](best_practices.md)
4. Review the [API Reference](api_reference.md)
```

Create `/home/user/nixbox/agentfs-pydantic/docs/best_practices.md`:

```markdown
# Best Practices

Guidelines for using agentfs-pydantic effectively.

## General Principles

### 1. Use Context Managers

Always use context managers for automatic cleanup:

```python
# ✓ Good - automatic cleanup
async with temporary_agent() as (agent_id, fs):
    await fs.write("/data.txt", "content")

# ✗ Avoid - manual cleanup required
agent_id, fs = await create_agent()
await fs.write("/data.txt", "content")
# Must manually delete agent database
```

### 2. Type Hints Everywhere

Leverage type hints for better IDE support:

```python
from agentfs_pydantic import FSOperations

async def process_files(fs: FSOperations) -> list[str]:
    """Process files and return paths."""
    entries = await fs.ls("/")
    return [e.path for e in entries]
```

### 3. Error Handling

Use specific exception types:

```python
from agentfs_pydantic import AgentNotFoundError, FileSystemError

try:
    fs = FSOperations("my-agent")
    content = await fs.cat("/config.json")
except AgentNotFoundError:
    print("Agent doesn't exist - create it first")
except FileSystemError as e:
    print(f"File operation failed: {e.path}")
```

## Performance

### 1. Batch Operations

Use batch operations for multiple agents:

```python
# ✓ Good - parallel creation
results = await batch_init(["agent1", "agent2", "agent3"])

# ✗ Slow - sequential creation
for agent_id in ["agent1", "agent2", "agent3"]:
    await cli.init(agent_id)
```

### 2. Reuse CLI Instances

Create CLI once and reuse:

```python
# ✓ Good
cli = AgentFSCLI()
for agent_id in agents:
    fs = cli.fs(agent_id)
    await fs.write("/data.txt", "content")

# ✗ Avoid - creates new CLI each time
for agent_id in agents:
    fs = FSOperations(agent_id)  # Creates new CLI internally
```

## Testing

### 1. Use Testing Utilities

Leverage built-in test helpers:

```python
from agentfs_pydantic.testing import mock_agent

async def test_my_feature():
    async with mock_agent(files={"/config.json": "{}"}) as agent:
        # Test code here
        await agent.assert_file_exists("/config.json")
```

### 2. Cleanup Test Data

Always cleanup test agents:

```python
# ✓ Good - automatic cleanup
async with temporary_agent() as (agent_id, fs):
    # Test code

# ✗ Avoid - leaves test databases
agent_id = "test-agent"
await cli.init(agent_id)
# No cleanup!
```

## DevEnv Integration

### 1. Environment Variables

Use environment variables for configuration:

```python
# In devenv.nix
env = {
  AGENTFS_ENABLED = "1";
  TURSO_DB_AUTH_TOKEN = "...";
};

# In Python
from agentfs_pydantic import DevEnvIntegration

integration = DevEnvIntegration.from_env()
```

### 2. Auto-Connect

Use devenv integration for automatic connection:

```python
async with integration.connect() as agent:
    # Already connected to devenv-managed instance
    await agent.fs.write("/data.txt", "content")
```

## Security

### 1. Never Commit Credentials

Use environment variables for sensitive data:

```python
import os

# ✓ Good
auth_token = os.getenv("TURSO_DB_AUTH_TOKEN")

# ✗ Never do this
auth_token = "secret_token_here"  # Don't hardcode!
```

### 2. Encryption Keys

Generate and store encryption keys securely:

```python
import secrets

# Generate 256-bit key
key = secrets.token_hex(32)  # 64 hex characters

# Store in environment, not in code
os.environ["AGENTFS_ENCRYPTION_KEY"] = key
```

## Debugging

### 1. Enable Event Logging

Use event system for debugging:

```python
from agentfs_pydantic import EventEmitter, BuiltinHandlers

emitter = EventEmitter()
emitter.register(BuiltinHandlers.console_logger(verbose=True))

cli = AgentFSCLI(emitter=emitter)
# All operations now logged
```

### 2. Timeline Analysis

Use timeline for debugging:

```python
from agentfs_pydantic import TimelineAnalyzer

analyzer = TimelineAnalyzer("my-agent")
await analyzer.load()

# Get recent errors
errors = analyzer.errors()
for error in errors:
    print(f"{error.timestamp}: {error.error}")
```

## Common Patterns

### Temporary Overlays

```python
async with overlay_workspace(Path("/project")) as workspace:
    # Make temporary changes
    (workspace / "test.txt").write_text("test")
    # Original project unchanged
```

### Sync Workflow

```python
async with auto_sync("agent", "libsql://db.turso.io") as manager:
    # Changes pulled on entry
    fs = FSOperations("agent")
    await fs.write("/data.txt", "new data")
    # Changes pushed on exit
```

### Testing Workflow

```python
@with_temp_agent()
async def test_feature(agent_id, fs):
    await fs.write("/test.txt", "data")
    assert await fs.exists("/test.txt")
```
```

### 18.3 Update Main README

Update `/home/user/nixbox/agentfs-pydantic/README.md` with comprehensive overview.

## Testing

Run all examples to ensure they work:

```bash
cd /home/user/nixbox/agentfs-pydantic

# Run each example
python examples/01_basic_usage.py
python examples/02_overlay_workflow.py
python examples/04_testing_example.py
python examples/05_advanced_patterns.py

# Sync example requires credentials
TURSO_URL="..." TURSO_DB_AUTH_TOKEN="..." python examples/03_sync_workflow.py
```

## Success Criteria

- [ ] Complete examples for all major features
- [ ] Documentation covers all APIs
- [ ] Getting started guide created
- [ ] Best practices documented
- [ ] Troubleshooting guide created
- [ ] API reference generated
- [ ] All examples run successfully
- [ ] README updated with overview

## Common Issues

**Issue**: Examples don't run
- **Solution**: Ensure all dependencies installed with `uv sync`

**Issue**: Documentation outdated
- **Solution**: Keep docs in sync with code changes

**Issue**: Missing examples
- **Solution**: Add examples for newly added features

## Final Steps

Once Phase 4 is complete:
1. Review all documentation
2. Run all tests: `uv run pytest -v`
3. Run all examples
4. Update version number
5. Consider publishing to PyPI
6. Share with community

## Design Notes

- Examples are runnable code
- Documentation is in Markdown
- Best practices based on real usage
- Troubleshooting from common issues
- API reference can be auto-generated from docstrings
- Keep examples simple and focused

## Congratulations!

You've completed all 18 steps and built a comprehensive, production-ready AgentFS Python library!

Key achievements:
- ✓ Type-safe wrappers for all CLI operations
- ✓ Async-first API design
- ✓ Context managers for resource management
- ✓ devenv.sh integration
- ✓ Comprehensive error handling
- ✓ Event system for observability
- ✓ Testing utilities for TDD
- ✓ High-level convenience APIs
- ✓ Complete documentation and examples

The library is now ready for:
- Production use
- Publishing to PyPI
- Community adoption
- Further enhancements
