# Step 1: CLI Binary Wrapper

**Phase**: 1 - Core (MVP)
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: None

## Objective

Create a robust wrapper around the `agentfs` CLI binary that provides:
- Subprocess management for executing agentfs commands
- Async I/O for all operations
- Proper error handling and timeout support
- Output capture (stdout/stderr)
- Type-safe command construction

## Why This Matters

All CLI operations in the library will use this wrapper. It's the foundation for:
- Init/exec/run operations
- Mount/unmount operations
- Sync/timeline/diff operations
- Server management

## Implementation Guide

### 1.1 Create the cli.py Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
"""CLI binary wrapper for agentfs command execution."""

import asyncio
import shutil
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field


class CommandResult(BaseModel):
    """Result from executing a CLI command.

    Examples:
        >>> result = CommandResult(
        ...     stdout="Success",
        ...     stderr="",
        ...     return_code=0,
        ...     duration=1.234
        ... )
        >>> result.success
        True
    """

    stdout: str = Field(description="Standard output from command")
    stderr: str = Field(description="Standard error from command")
    return_code: int = Field(description="Process exit code")
    duration: float = Field(description="Execution duration in seconds")

    @property
    def success(self) -> bool:
        """Check if command succeeded (return code 0)."""
        return self.return_code == 0


class AgentFSBinary:
    """Wrapper for the agentfs CLI binary.

    Handles subprocess execution, output capture, and error handling.

    Examples:
        >>> binary = AgentFSBinary()
        >>> result = await binary.execute(["init", "my-agent"])
        >>> if result.success:
        ...     print("Agent created successfully")
    """

    def __init__(self, binary_path: Optional[Path] = None):
        """Initialize the binary wrapper.

        Args:
            binary_path: Explicit path to agentfs binary. If None, searches PATH.

        Raises:
            FileNotFoundError: If agentfs binary cannot be found.
        """
        if binary_path is None:
            # Search for agentfs in PATH
            found = shutil.which("agentfs")
            if found is None:
                raise FileNotFoundError(
                    "agentfs binary not found in PATH. "
                    "Install AgentFS or provide explicit binary_path."
                )
            self.binary_path = Path(found)
        else:
            self.binary_path = binary_path
            if not self.binary_path.exists():
                raise FileNotFoundError(
                    f"agentfs binary not found at: {self.binary_path}"
                )

    async def execute(
        self,
        args: list[str],
        *,
        check: bool = False,
        capture_output: bool = True,
        timeout: Optional[float] = None,
        env: Optional[dict[str, str]] = None,
    ) -> CommandResult:
        """Execute an agentfs command asynchronously.

        Args:
            args: Command arguments (e.g., ["init", "my-agent"])
            check: If True, raise CalledProcessError on non-zero exit
            capture_output: If True, capture stdout/stderr
            timeout: Command timeout in seconds (None = no timeout)
            env: Additional environment variables

        Returns:
            CommandResult with stdout, stderr, return code, and duration

        Raises:
            asyncio.TimeoutError: If command exceeds timeout
            subprocess.CalledProcessError: If check=True and command fails

        Examples:
            >>> # Simple execution
            >>> result = await binary.execute(["version"])

            >>> # With timeout
            >>> result = await binary.execute(
            ...     ["init", "my-agent"],
            ...     timeout=30.0
            ... )

            >>> # Raise on error
            >>> result = await binary.execute(
            ...     ["mount", "my-agent", "/tmp/mount"],
            ...     check=True
            ... )
        """
        import time

        start_time = time.perf_counter()

        # Build full command
        cmd = [str(self.binary_path)] + args

        # Configure process
        stdout_opt = asyncio.subprocess.PIPE if capture_output else None
        stderr_opt = asyncio.subprocess.PIPE if capture_output else None

        # Create subprocess
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=stdout_opt,
            stderr=stderr_opt,
            env=env,
        )

        # Wait for completion with timeout
        try:
            stdout_bytes, stderr_bytes = await asyncio.wait_for(
                process.communicate(),
                timeout=timeout
            )
        except asyncio.TimeoutError:
            # Kill the process on timeout
            process.kill()
            await process.wait()
            raise

        duration = time.perf_counter() - start_time

        # Decode output
        stdout = stdout_bytes.decode("utf-8") if stdout_bytes else ""
        stderr = stderr_bytes.decode("utf-8") if stderr_bytes else ""

        result = CommandResult(
            stdout=stdout,
            stderr=stderr,
            return_code=process.returncode or 0,
            duration=duration
        )

        # Raise if requested and failed
        if check and not result.success:
            raise subprocess.CalledProcessError(
                returncode=result.return_code,
                cmd=cmd,
                output=result.stdout,
                stderr=result.stderr
            )

        return result

    def __repr__(self) -> str:
        return f"AgentFSBinary(path={self.binary_path})"
```

### 1.2 Add Missing Import

At the top of `cli.py`, add:

```python
import subprocess
```

### 1.3 Update __init__.py

Add exports to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.cli import AgentFSBinary, CommandResult

__all__ = [
    # Existing exports...
    "AgentFSBinary",
    "CommandResult",
]
```

### 1.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_cli.py`:

```python
"""Tests for CLI binary wrapper."""

import pytest
from pathlib import Path

from agentfs_pydantic.cli import AgentFSBinary, CommandResult


class TestCommandResult:
    """Tests for CommandResult model."""

    def test_success_property(self):
        """Test success property for different return codes."""
        # Success
        result = CommandResult(
            stdout="ok",
            stderr="",
            return_code=0,
            duration=1.0
        )
        assert result.success is True

        # Failure
        result = CommandResult(
            stdout="",
            stderr="error",
            return_code=1,
            duration=1.0
        )
        assert result.success is False


class TestAgentFSBinary:
    """Tests for AgentFSBinary wrapper."""

    def test_init_finds_binary_in_path(self):
        """Test that binary is found in PATH."""
        binary = AgentFSBinary()
        assert binary.binary_path.exists()
        assert binary.binary_path.name == "agentfs"

    def test_init_with_explicit_path(self):
        """Test initialization with explicit path."""
        # Find binary first
        temp_binary = AgentFSBinary()
        path = temp_binary.binary_path

        # Use explicit path
        binary = AgentFSBinary(binary_path=path)
        assert binary.binary_path == path

    def test_init_raises_if_not_found(self):
        """Test that FileNotFoundError is raised if binary not found."""
        fake_path = Path("/nonexistent/agentfs")
        with pytest.raises(FileNotFoundError, match="not found"):
            AgentFSBinary(binary_path=fake_path)

    @pytest.mark.asyncio
    async def test_execute_version(self):
        """Test executing version command."""
        binary = AgentFSBinary()
        result = await binary.execute(["version"])

        assert result.success
        assert result.return_code == 0
        assert len(result.stdout) > 0
        assert result.duration > 0

    @pytest.mark.asyncio
    async def test_execute_with_timeout(self):
        """Test command timeout."""
        binary = AgentFSBinary()

        # This should complete quickly
        result = await binary.execute(["version"], timeout=5.0)
        assert result.success

    @pytest.mark.asyncio
    async def test_execute_check_raises_on_failure(self):
        """Test that check=True raises on command failure."""
        binary = AgentFSBinary()

        # Invalid command should fail
        with pytest.raises(subprocess.CalledProcessError):
            await binary.execute(
                ["invalid-command-xyz"],
                check=True
            )

    @pytest.mark.asyncio
    async def test_execute_returns_stderr(self):
        """Test that stderr is captured."""
        binary = AgentFSBinary()

        # Run invalid command without check
        result = await binary.execute(["invalid-command-xyz"])

        assert not result.success
        assert len(result.stderr) > 0 or len(result.stdout) > 0
```

## Testing

### Manual Testing

1. **Test binary detection**:
```bash
cd /home/user/nixbox/agentfs-pydantic
python -c "
from agentfs_pydantic.cli import AgentFSBinary
binary = AgentFSBinary()
print(f'Found: {binary.binary_path}')
"
```

2. **Test command execution**:
```python
import asyncio
from agentfs_pydantic.cli import AgentFSBinary

async def main():
    binary = AgentFSBinary()
    result = await binary.execute(["version"])
    print(f"Success: {result.success}")
    print(f"Output: {result.stdout}")
    print(f"Duration: {result.duration}s")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_cli.py -v
```

## Success Criteria

- [ ] `AgentFSBinary` class created with proper initialization
- [ ] Binary can be found in PATH or specified explicitly
- [ ] `execute()` method works asynchronously
- [ ] `CommandResult` model captures all execution details
- [ ] Timeout handling works correctly
- [ ] Error handling (check parameter) works correctly
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: `FileNotFoundError: agentfs binary not found`
- **Solution**: Ensure agentfs is installed and in PATH. In devenv.sh: `devenv shell`

**Issue**: `ImportError: cannot import name 'AgentFSBinary'`
- **Solution**: Make sure you updated `__init__.py` with the new exports

**Issue**: Tests fail with asyncio errors
- **Solution**: Ensure pytest-asyncio is installed: `uv add --dev pytest-asyncio`

## Next Steps

Once this step is complete:
1. Proceed to [Step 2: Enhanced Models](./DEV_GUIDE-STEP_02.md)
2. The binary wrapper will be used by all CLI operation wrappers

## Additional Notes

### Design Decisions

- **Why async?** All I/O should be async to support concurrent operations
- **Why Pydantic for CommandResult?** Type safety and validation, consistent with library design
- **Why shutil.which?** Cross-platform way to find executables in PATH

### Future Enhancements

In later steps, this module will be extended with:
- Logging of all commands
- Event emission for observability (Phase 4)
- Retry logic for network operations
- Better error parsing from stderr
