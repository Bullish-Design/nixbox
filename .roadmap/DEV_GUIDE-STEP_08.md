# Step 8: Error Handling Hierarchy

**Phase**: 2 - Essential
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: Phase 1 + Steps 6-7

## Objective

Create a comprehensive error handling hierarchy for AgentFS operations:
- Custom exception classes for different error types
- Type-safe error handling
- Informative error messages with context
- Integration with all existing operations

## Why This Matters

Proper error handling enables:
- Distinguishing between different failure types
- Better debugging and troubleshooting
- Type-safe exception handling
- Clearer error messages for users

## Implementation Guide

### 8.1 Create Exceptions Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/exceptions.py`:

```python
"""Exception hierarchy for AgentFS operations."""


class AgentFSError(Exception):
    """Base exception for all AgentFS errors.

    Examples:
        >>> try:
        ...     await cli.init("my-agent")
        ... except AgentFSError as e:
        ...     print(f"AgentFS error: {e}")
    """

    def __init__(self, message: str, *, details: dict | None = None):
        """Initialize error.

        Args:
            message: Error message
            details: Additional error context
        """
        super().__init__(message)
        self.message = message
        self.details = details or {}

    def __str__(self) -> str:
        """Format error message with details."""
        if self.details:
            details_str = ", ".join(f"{k}={v}" for k, v in self.details.items())
            return f"{self.message} ({details_str})"
        return self.message


class AgentNotFoundError(AgentFSError):
    """Agent or database not found.

    Examples:
        >>> try:
        ...     await cli.exec("nonexistent", ["ls"])
        ... except AgentNotFoundError as e:
        ...     print(f"Agent not found: {e.agent_id}")
    """

    def __init__(self, agent_id: str, message: str | None = None):
        """Initialize error.

        Args:
            agent_id: The agent that was not found
            message: Optional custom message
        """
        self.agent_id = agent_id
        msg = message or f"Agent not found: {agent_id}"
        super().__init__(msg, details={"agent_id": agent_id})


class MountError(AgentFSError):
    """Errors related to mounting/unmounting.

    Examples:
        >>> try:
        ...     await cli.mount("my-agent", "/invalid/path")
        ... except MountError as e:
        ...     print(f"Mount failed: {e.reason}")
    """

    def __init__(
        self,
        message: str,
        *,
        mount_point: str | None = None,
        reason: str | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            mount_point: The mount point that failed
            reason: Specific failure reason
        """
        self.mount_point = mount_point
        self.reason = reason
        details = {}
        if mount_point:
            details["mount_point"] = mount_point
        if reason:
            details["reason"] = reason
        super().__init__(message, details=details)


class SyncError(AgentFSError):
    """Errors related to sync operations.

    Examples:
        >>> try:
        ...     await cli.sync_pull(config)
        ... except SyncError as e:
        ...     print(f"Sync failed: {e.operation}")
    """

    def __init__(
        self,
        message: str,
        *,
        operation: str | None = None,
        remote_url: str | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            operation: Sync operation that failed (pull/push/checkpoint)
            remote_url: Remote URL involved
        """
        self.operation = operation
        self.remote_url = remote_url
        details = {}
        if operation:
            details["operation"] = operation
        if remote_url:
            details["remote_url"] = remote_url
        super().__init__(message, details=details)


class EncryptionError(AgentFSError):
    """Errors related to encryption.

    Examples:
        >>> try:
        ...     await cli.init("agent", options=InitOptions(
        ...         encryption=EncryptionConfig(key="invalid", cipher="aes256gcm")
        ...     ))
        ... except EncryptionError as e:
        ...     print(f"Encryption error: {e.cipher}")
    """

    def __init__(
        self,
        message: str,
        *,
        cipher: str | None = None,
        key_length: int | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            cipher: Cipher algorithm involved
            key_length: Key length that caused the error
        """
        self.cipher = cipher
        self.key_length = key_length
        details = {}
        if cipher:
            details["cipher"] = cipher
        if key_length:
            details["key_length"] = key_length
        super().__init__(message, details=details)


class MigrationError(AgentFSError):
    """Errors related to database migrations.

    Examples:
        >>> try:
        ...     await cli.migrate("my-agent")
        ... except MigrationError as e:
        ...     print(f"Migration failed at version: {e.version}")
    """

    def __init__(
        self,
        message: str,
        *,
        current_version: str | None = None,
        target_version: str | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            current_version: Current schema version
            target_version: Target schema version
        """
        self.current_version = current_version
        self.target_version = target_version
        self.version = current_version  # Alias for convenience
        details = {}
        if current_version:
            details["current_version"] = current_version
        if target_version:
            details["target_version"] = target_version
        super().__init__(message, details=details)


class FileSystemError(AgentFSError):
    """Errors related to filesystem operations.

    Examples:
        >>> try:
        ...     await fs.cat("/nonexistent.txt")
        ... except FileSystemError as e:
        ...     print(f"File error: {e.path}")
    """

    def __init__(
        self,
        message: str,
        *,
        path: str | None = None,
        operation: str | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            path: File path involved
            operation: Operation that failed (read/write/delete/etc)
        """
        self.path = path
        self.operation = operation
        details = {}
        if path:
            details["path"] = path
        if operation:
            details["operation"] = operation
        super().__init__(message, details=details)


class ServerError(AgentFSError):
    """Errors related to MCP/NFS servers.

    Examples:
        >>> try:
        ...     await cli.serve_mcp("my-agent")
        ... except ServerError as e:
        ...     print(f"Server error: {e.server_type}")
    """

    def __init__(
        self,
        message: str,
        *,
        server_type: str | None = None,
        bind_address: str | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            server_type: Type of server (mcp/nfs)
            bind_address: Bind address that failed
        """
        self.server_type = server_type
        self.bind_address = bind_address
        details = {}
        if server_type:
            details["server_type"] = server_type
        if bind_address:
            details["bind_address"] = bind_address
        super().__init__(message, details=details)


class CLIError(AgentFSError):
    """Errors from CLI command execution.

    Examples:
        >>> try:
        ...     await cli.exec("my-agent", ["invalid-command"])
        ... except CLIError as e:
        ...     print(f"Command failed: {e.return_code}")
        ...     print(f"Output: {e.stderr}")
    """

    def __init__(
        self,
        message: str,
        *,
        command: list[str] | None = None,
        return_code: int | None = None,
        stdout: str = "",
        stderr: str = ""
    ):
        """Initialize error.

        Args:
            message: Error message
            command: Command that failed
            return_code: Exit code
            stdout: Standard output
            stderr: Standard error
        """
        self.command = command
        self.return_code = return_code
        self.stdout = stdout
        self.stderr = stderr
        details = {}
        if command:
            details["command"] = " ".join(command)
        if return_code is not None:
            details["return_code"] = return_code
        super().__init__(message, details=details)


class ConfigurationError(AgentFSError):
    """Errors related to configuration.

    Examples:
        >>> try:
        ...     config = DevEnvConfig.from_env()
        ... except ConfigurationError as e:
        ...     print(f"Config error: {e.field}")
    """

    def __init__(
        self,
        message: str,
        *,
        field: str | None = None,
        value: str | None = None
    ):
        """Initialize error.

        Args:
            message: Error message
            field: Configuration field that's invalid
            value: Invalid value
        """
        self.field = field
        self.value = value
        details = {}
        if field:
            details["field"] = field
        if value:
            details["value"] = value
        super().__init__(message, details=details)
```

### 8.2 Update CLI to Raise Custom Exceptions

Update error handling in `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
from agentfs_pydantic.exceptions import (
    AgentFSError,
    AgentNotFoundError,
    CLIError,
)

class AgentFSBinary:
    # ... existing code ...

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

        ... existing docstring ...
        """
        import time

        start_time = time.perf_counter()

        # Build full command
        cmd = [str(self.binary_path)] + args

        # ... existing execution code ...

        result = CommandResult(
            stdout=stdout,
            stderr=stderr,
            return_code=process.returncode or 0,
            duration=duration
        )

        # Raise custom exceptions based on error
        if check and not result.success:
            # Try to determine error type from stderr
            stderr_lower = result.stderr.lower()

            if "not found" in stderr_lower and len(args) > 1:
                # Likely an agent not found error
                raise AgentNotFoundError(
                    args[1],
                    message=result.stderr.strip()
                )
            else:
                # Generic CLI error
                raise CLIError(
                    f"Command failed with exit code {result.return_code}",
                    command=cmd,
                    return_code=result.return_code,
                    stdout=result.stdout,
                    stderr=result.stderr
                )

        return result
```

### 8.3 Update Filesystem Operations

Update `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/filesystem.py`:

```python
from agentfs_pydantic.exceptions import FileSystemError

class FSOperations:
    # ... existing code ...

    async def cat(self, path: str) -> str:
        """Read file contents.

        ... existing docstring ...
        """
        result = await self.cli.exec(self.agent_id, ["cat", path])

        if not result.success:
            raise FileSystemError(
                f"Failed to read file: {result.stderr}",
                path=path,
                operation="read"
            )

        return result.stdout
```

### 8.4 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.exceptions import (
    AgentFSError,
    AgentNotFoundError,
    MountError,
    SyncError,
    EncryptionError,
    MigrationError,
    FileSystemError,
    ServerError,
    CLIError,
    ConfigurationError,
)

__all__ = [
    # ... existing ...
    "AgentFSError",
    "AgentNotFoundError",
    "MountError",
    "SyncError",
    "EncryptionError",
    "MigrationError",
    "FileSystemError",
    "ServerError",
    "CLIError",
    "ConfigurationError",
]
```

### 8.5 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_exceptions.py`:

```python
"""Tests for exception hierarchy."""

import pytest

from agentfs_pydantic.exceptions import (
    AgentFSError,
    AgentNotFoundError,
    MountError,
    CLIError,
    FileSystemError,
)


class TestExceptionHierarchy:
    """Tests for exception classes."""

    def test_base_exception(self):
        """Test base AgentFSError."""
        error = AgentFSError("Test error", details={"key": "value"})
        assert str(error) == "Test error (key=value)"
        assert error.message == "Test error"
        assert error.details == {"key": "value"}

    def test_agent_not_found_error(self):
        """Test AgentNotFoundError."""
        error = AgentNotFoundError("my-agent")
        assert error.agent_id == "my-agent"
        assert "my-agent" in str(error)

    def test_mount_error(self):
        """Test MountError."""
        error = MountError(
            "Mount failed",
            mount_point="/tmp/mount",
            reason="Permission denied"
        )
        assert error.mount_point == "/tmp/mount"
        assert error.reason == "Permission denied"
        assert "Permission denied" in str(error)

    def test_cli_error(self):
        """Test CLIError."""
        error = CLIError(
            "Command failed",
            command=["agentfs", "init", "test"],
            return_code=1,
            stderr="Error message"
        )
        assert error.command == ["agentfs", "init", "test"]
        assert error.return_code == 1
        assert error.stderr == "Error message"

    def test_filesystem_error(self):
        """Test FileSystemError."""
        error = FileSystemError(
            "File not found",
            path="/missing.txt",
            operation="read"
        )
        assert error.path == "/missing.txt"
        assert error.operation == "read"

    def test_exception_inheritance(self):
        """Test that all exceptions inherit from AgentFSError."""
        assert issubclass(AgentNotFoundError, AgentFSError)
        assert issubclass(MountError, AgentFSError)
        assert issubclass(CLIError, AgentFSError)
        assert issubclass(FileSystemError, AgentFSError)
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import (
    AgentFSCLI,
    AgentNotFoundError,
    FileSystemError,
    FSOperations
)

async def main():
    cli = AgentFSCLI()

    # Test 1: Agent not found
    try:
        await cli.exec("nonexistent-agent", ["ls"])
    except AgentNotFoundError as e:
        print(f"Caught AgentNotFoundError: {e.agent_id}")

    # Test 2: File not found
    try:
        fs = FSOperations("my-agent")
        await fs.cat("/nonexistent.txt")
    except FileSystemError as e:
        print(f"Caught FileSystemError: path={e.path}, operation={e.operation}")

    # Test 3: Generic error handling
    try:
        await cli.exec("bad-agent", ["invalid"], check=True)
    except AgentFSError as e:
        print(f"Caught AgentFSError: {e}")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_exceptions.py -v
```

## Success Criteria

- [ ] Exception hierarchy created with base class
- [ ] Specific exception types for all error categories
- [ ] All exceptions include relevant context (agent_id, path, etc.)
- [ ] String representation includes details
- [ ] CLI operations raise appropriate exceptions
- [ ] Filesystem operations use custom exceptions
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Too many exception types
- **Solution**: Start with basic types, add specialized ones as needed

**Issue**: Losing stack traces
- **Solution**: Use `raise from` when wrapping exceptions

**Issue**: Catching wrong exception type
- **Solution**: Catch most specific type first, then broader types

## Next Steps

Once this step is complete:
1. Proceed to [Step 9: Context Managers for Resources](./DEV_GUIDE-STEP_09.md)
2. Use exceptions in all error handling throughout library

## Design Notes

- All exceptions inherit from `AgentFSError`
- Exceptions include structured context (not just strings)
- Details dict allows flexible error information
- Type-safe exception handling with specific types
- Clear, informative error messages
