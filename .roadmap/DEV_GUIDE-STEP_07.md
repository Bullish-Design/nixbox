# Step 7: Filesystem Operations (ls/cat/write)

**Phase**: 2 - Essential
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Phase 1 + Step 6

## Objective

Implement direct filesystem operations without requiring mount:
- List directory contents (`ls`)
- Read file contents (`cat`)
- Write files (`write`)
- Integration with existing View interface

## Why This Matters

Direct filesystem operations enable:
- File manipulation without mounting
- Scriptable file operations
- Integration with existing View-based queries
- Simpler API for common tasks

## Implementation Guide

### 7.1 Create Filesystem Operations Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/filesystem.py`:

```python
"""Filesystem operations for AgentFS."""

from pathlib import Path
from typing import Optional, List
from agentfs_pydantic.cli import AgentFSCLI, CommandResult
from agentfs_pydantic.models import FileEntry


class FSOperations:
    """Direct filesystem operations without mounting.

    Examples:
        >>> fs = FSOperations("my-agent")
        >>>
        >>> # List directory
        >>> entries = await fs.ls("/")
        >>>
        >>> # Read file
        >>> content = await fs.cat("/config.json")
        >>>
        >>> # Write file
        >>> await fs.write("/notes.txt", "Hello AgentFS")
    """

    def __init__(
        self,
        agent_id: str,
        *,
        cli: Optional[AgentFSCLI] = None
    ):
        """Initialize filesystem operations.

        Args:
            agent_id: Agent identifier or database path
            cli: Optional CLI instance (created if not provided)
        """
        self.agent_id = agent_id
        self.cli = cli or AgentFSCLI()

    async def ls(
        self,
        path: str = "/",
        *,
        recursive: bool = False
    ) -> List[FileEntry]:
        """List directory contents.

        Args:
            path: Directory path to list
            recursive: Recursively list subdirectories

        Returns:
            List of FileEntry objects

        Examples:
            >>> # List root directory
            >>> entries = await fs.ls("/")
            >>>
            >>> # List recursively
            >>> all_entries = await fs.ls("/", recursive=True)
            >>>
            >>> # List specific directory
            >>> docs = await fs.ls("/documents")
        """
        cmd = ["ls", "-la"]
        if recursive:
            cmd.append("-R")
        cmd.append(path)

        result = await self.cli.exec(self.agent_id, cmd)

        # Parse ls output into FileEntry objects
        entries = []
        for line in result.stdout.strip().split('\n'):
            if not line or line.startswith('total'):
                continue

            # Parse ls -la output format
            # Example: drwxr-xr-x 2 user group 4096 Jan 1 12:00 dirname
            parts = line.split(None, 8)
            if len(parts) < 9:
                continue

            permissions = parts[0]
            is_dir = permissions.startswith('d')
            size = int(parts[4]) if parts[4].isdigit() else 0
            name = parts[8]

            # Construct full path
            full_path = f"{path.rstrip('/')}/{name}"

            entries.append(FileEntry(
                path=full_path,
                is_directory=is_dir,
                size=size,
                # Additional fields would require parsing timestamps, etc.
            ))

        return entries

    async def cat(self, path: str) -> str:
        """Read file contents.

        Args:
            path: File path to read

        Returns:
            File contents as string

        Raises:
            Exception: If file doesn't exist or can't be read

        Examples:
            >>> # Read text file
            >>> content = await fs.cat("/README.md")
            >>> print(content)
            >>>
            >>> # Read JSON file
            >>> import json
            >>> data = json.loads(await fs.cat("/config.json"))
        """
        result = await self.cli.exec(self.agent_id, ["cat", path])

        if not result.success:
            raise FileNotFoundError(f"Failed to read {path}: {result.stderr}")

        return result.stdout

    async def write(
        self,
        path: str,
        content: str,
        *,
        mode: str = "w"
    ) -> CommandResult:
        """Write content to a file.

        Args:
            path: File path to write
            content: Content to write
            mode: Write mode ('w' for overwrite, 'a' for append)

        Returns:
            CommandResult from write operation

        Examples:
            >>> # Write new file
            >>> await fs.write("/notes.txt", "Hello World")
            >>>
            >>> # Append to file
            >>> await fs.write("/log.txt", "New entry\\n", mode="a")
            >>>
            >>> # Write JSON
            >>> import json
            >>> data = {"key": "value"}
            >>> await fs.write("/data.json", json.dumps(data, indent=2))
        """
        # Use shell redirection for writing
        operator = ">>" if mode == "a" else ">"
        cmd = ["sh", "-c", f"cat {operator} {path}"]

        # Execute with content as stdin
        # Note: This is a simplified implementation
        # In practice, might need to use echo or printf
        result = await self.cli.exec(
            self.agent_id,
            ["sh", "-c", f'echo "{content}" {operator} {path}']
        )

        return result

    async def mkdir(
        self,
        path: str,
        *,
        parents: bool = True
    ) -> CommandResult:
        """Create directory.

        Args:
            path: Directory path to create
            parents: Create parent directories if needed

        Returns:
            CommandResult from mkdir operation

        Examples:
            >>> # Create single directory
            >>> await fs.mkdir("/newdir")
            >>>
            >>> # Create nested directories
            >>> await fs.mkdir("/path/to/deep/dir", parents=True)
        """
        cmd = ["mkdir"]
        if parents:
            cmd.append("-p")
        cmd.append(path)

        return await self.cli.exec(self.agent_id, cmd)

    async def rm(
        self,
        path: str,
        *,
        recursive: bool = False,
        force: bool = False
    ) -> CommandResult:
        """Remove file or directory.

        Args:
            path: Path to remove
            recursive: Recursively remove directories
            force: Force removal without prompts

        Returns:
            CommandResult from rm operation

        Examples:
            >>> # Remove file
            >>> await fs.rm("/old-file.txt")
            >>>
            >>> # Remove directory recursively
            >>> await fs.rm("/old-dir", recursive=True, force=True)
        """
        cmd = ["rm"]
        if recursive:
            cmd.append("-r")
        if force:
            cmd.append("-f")
        cmd.append(path)

        return await self.cli.exec(self.agent_id, cmd)

    async def exists(self, path: str) -> bool:
        """Check if path exists.

        Args:
            path: Path to check

        Returns:
            True if path exists, False otherwise

        Examples:
            >>> if await fs.exists("/config.json"):
            ...     config = await fs.cat("/config.json")
        """
        result = await self.cli.exec(
            self.agent_id,
            ["test", "-e", path]
        )
        return result.success

    async def is_file(self, path: str) -> bool:
        """Check if path is a file.

        Args:
            path: Path to check

        Returns:
            True if path is a regular file

        Examples:
            >>> if await fs.is_file("/data.json"):
            ...     content = await fs.cat("/data.json")
        """
        result = await self.cli.exec(
            self.agent_id,
            ["test", "-f", path]
        )
        return result.success

    async def is_dir(self, path: str) -> bool:
        """Check if path is a directory.

        Args:
            path: Path to check

        Returns:
            True if path is a directory

        Examples:
            >>> if await fs.is_dir("/documents"):
            ...     files = await fs.ls("/documents")
        """
        result = await self.cli.exec(
            self.agent_id,
            ["test", "-d", path]
        )
        return result.success
```

### 7.2 Add Convenience Method to AgentFSCLI

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    def fs(self, agent_id: str) -> "FSOperations":
        """Get filesystem operations interface for an agent.

        Args:
            agent_id: Agent identifier

        Returns:
            FSOperations instance

        Examples:
            >>> cli = AgentFSCLI()
            >>> fs = cli.fs("my-agent")
            >>> content = await fs.cat("/file.txt")
        """
        from agentfs_pydantic.filesystem import FSOperations
        return FSOperations(agent_id, cli=self)
```

### 7.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.filesystem import FSOperations

__all__ = [
    # ... existing ...
    "FSOperations",
]
```

### 7.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_filesystem.py`:

```python
"""Tests for filesystem operations."""

import pytest
from pathlib import Path

from agentfs_pydantic import AgentFSCLI, InitOptions, FSOperations


@pytest.fixture
async def test_agent():
    """Create test agent."""
    cli = AgentFSCLI()
    agent_id = "fs-test-agent"
    await cli.init(agent_id, options=InitOptions(force=True))
    yield agent_id
    # Cleanup
    import os
    db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
    if db_path.exists():
        os.remove(db_path)


class TestFSOperations:
    """Tests for filesystem operations."""

    @pytest.mark.asyncio
    async def test_write_and_read(self, test_agent):
        """Test writing and reading files."""
        fs = FSOperations(test_agent)

        # Write file
        await fs.write("/test.txt", "Hello AgentFS")

        # Read file
        content = await fs.cat("/test.txt")
        assert "Hello AgentFS" in content

    @pytest.mark.asyncio
    async def test_mkdir_and_ls(self, test_agent):
        """Test directory creation and listing."""
        fs = FSOperations(test_agent)

        # Create directory
        await fs.mkdir("/testdir")

        # List root
        entries = await fs.ls("/")
        paths = [e.path for e in entries]
        assert any("testdir" in p for p in paths)

    @pytest.mark.asyncio
    async def test_exists_checks(self, test_agent):
        """Test existence checking."""
        fs = FSOperations(test_agent)

        # Create file
        await fs.write("/exists-test.txt", "content")

        # Check existence
        assert await fs.exists("/exists-test.txt")
        assert await fs.is_file("/exists-test.txt")
        assert not await fs.is_dir("/exists-test.txt")

    @pytest.mark.asyncio
    async def test_remove_file(self, test_agent):
        """Test file removal."""
        fs = FSOperations(test_agent)

        # Create and remove file
        await fs.write("/temp.txt", "temporary")
        assert await fs.exists("/temp.txt")

        await fs.rm("/temp.txt")
        assert not await fs.exists("/temp.txt")

    @pytest.mark.asyncio
    async def test_cli_fs_method(self, test_agent):
        """Test CLI convenience method."""
        cli = AgentFSCLI()
        fs = cli.fs(test_agent)

        await fs.write("/cli-test.txt", "test")
        content = await fs.cat("/cli-test.txt")
        assert "test" in content
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import AgentFSCLI, InitOptions, FSOperations

async def main():
    cli = AgentFSCLI()

    # Create test agent
    await cli.init("fs-demo", options=InitOptions(force=True))

    # Use filesystem operations
    fs = FSOperations("fs-demo")

    print("1. Writing files...")
    await fs.write("/hello.txt", "Hello from AgentFS!")
    await fs.write("/data.json", '{"key": "value"}')

    print("\n2. Reading files...")
    content = await fs.cat("/hello.txt")
    print(f"Content: {content}")

    print("\n3. Listing directory...")
    entries = await fs.ls("/")
    for entry in entries:
        print(f"  {entry.path} ({'dir' if entry.is_directory else 'file'})")

    print("\n4. Creating directory...")
    await fs.mkdir("/documents/reports", parents=True)

    print("\n5. Checking existence...")
    exists = await fs.exists("/hello.txt")
    print(f"/hello.txt exists: {exists}")

    print("\n6. Using CLI convenience method...")
    fs2 = cli.fs("fs-demo")
    await fs2.write("/via-cli.txt", "Created via CLI method")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_filesystem.py -v
```

## Success Criteria

- [ ] FSOperations class created with core methods
- [ ] ls() lists directory contents
- [ ] cat() reads file contents
- [ ] write() creates/updates files
- [ ] mkdir() creates directories
- [ ] rm() removes files/directories
- [ ] exists/is_file/is_dir checks work
- [ ] CLI convenience method added
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: File not found errors
- **Solution**: Use `exists()` check before operations

**Issue**: Write operation escaping issues
- **Solution**: Be careful with special characters in content

**Issue**: Permission denied
- **Solution**: Check agent initialization and file permissions

## Next Steps

Once this step is complete:
1. Proceed to [Step 8: Error Handling Hierarchy](./DEV_GUIDE-STEP_08.md)
2. Filesystem operations will be used throughout the library

## Design Notes

- Operations work without mounting filesystem
- Integrates with existing View interface
- Simple, file-system-like API
- All operations are async
- Convenience method on CLI for easy access
