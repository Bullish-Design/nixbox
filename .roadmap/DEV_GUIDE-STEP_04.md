# Step 4: AgentFSManager Lifecycle

**Phase**: 1 - Core (MVP)
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Steps 1-3 (CLI Binary, Models, Init/Exec/Run)

## Objective

Create `AgentFSManager` class that provides:
- Automatic lifecycle management (start/stop)
- Process management for `agentfs serve` operations
- Health checks and readiness probes
- Graceful shutdown handling
- Context manager support

## Why This Matters

The manager enables:
- Starting AgentFS as a background service
- Automatic cleanup on exit
- Health monitoring
- Integration with async applications
- Foundation for devenv.sh integration

## Implementation Guide

### 4.1 Create manager.py Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/manager.py`:

```python
"""AgentFS lifecycle management."""

import asyncio
import signal
from pathlib import Path
from typing import Optional
from pydantic import BaseModel, Field


class AgentFSConfig(BaseModel):
    """Configuration for AgentFS manager.

    Examples:
        >>> config = AgentFSConfig(
        ...     id="my-agent",
        ...     host="127.0.0.1",
        ...     port=8081
        ... )
    """

    id: str = Field(..., description="Agent identifier")
    host: str = Field(default="127.0.0.1", description="Bind host")
    port: int = Field(default=8081, description="Bind port", gt=0, lt=65536)
    data_dir: Optional[Path] = Field(
        None,
        description="Data directory (defaults to ~/.agentfs)"
    )
    log_level: str = Field(
        default="info",
        description="Log level (debug, info, warn, error)"
    )

    @property
    def db_path(self) -> Path:
        """Get the database file path."""
        base_dir = self.data_dir or (Path.home() / ".agentfs")
        return base_dir / f"{self.id}.db"

    @property
    def endpoint(self) -> str:
        """Get the HTTP endpoint URL."""
        return f"http://{self.host}:{self.port}"


class AgentFSManager:
    """Manages AgentFS process lifecycle.

    Handles starting, stopping, and monitoring AgentFS server processes.

    Examples:
        >>> # Context manager usage
        >>> config = AgentFSConfig(id="my-agent")
        >>> async with AgentFSManager(config) as manager:
        ...     # AgentFS is running
        ...     client = await manager.get_client()
        ...     # Do work...
        ... # Automatically stopped

        >>> # Manual control
        >>> manager = AgentFSManager(config)
        >>> await manager.start()
        >>> # Do work...
        >>> await manager.stop()
    """

    def __init__(self, config: AgentFSConfig, binary_path: Optional[Path] = None):
        """Initialize the manager.

        Args:
            config: AgentFS configuration
            binary_path: Optional path to agentfs binary
        """
        self.config = config
        self.binary_path = binary_path
        self._process: Optional[asyncio.subprocess.Process] = None
        self._started = False

    async def start(self, *, wait_ready: bool = True, timeout: float = 10.0) -> None:
        """Start the AgentFS server process.

        Args:
            wait_ready: Wait for server to be ready
            timeout: Timeout for readiness check in seconds

        Raises:
            RuntimeError: If already started or if readiness check fails
            FileNotFoundError: If agentfs binary not found

        Examples:
            >>> await manager.start()  # Wait for ready
            >>> await manager.start(wait_ready=False)  # Start async
        """
        if self._started:
            raise RuntimeError("AgentFS already started")

        from agentfs_pydantic.cli import AgentFSBinary

        # Get binary
        if self.binary_path:
            binary = AgentFSBinary(binary_path=self.binary_path)
        else:
            binary = AgentFSBinary()

        # Build command
        args = [
            str(binary.binary_path),
            "serve",
            self.config.id,
            "--host", self.config.host,
            "--port", str(self.config.port),
            "--log-level", self.config.log_level,
        ]

        # Start process
        self._process = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        self._started = True

        # Wait for readiness if requested
        if wait_ready:
            await self.wait_ready(timeout=timeout)

    async def stop(self, *, timeout: float = 5.0) -> None:
        """Stop the AgentFS server process.

        Attempts graceful shutdown (SIGTERM) first, then forces (SIGKILL).

        Args:
            timeout: Timeout for graceful shutdown in seconds

        Examples:
            >>> await manager.stop()
            >>> await manager.stop(timeout=10.0)  # Wait longer
        """
        if not self._started or not self._process:
            return

        try:
            # Try graceful shutdown
            self._process.terminate()

            try:
                await asyncio.wait_for(
                    self._process.wait(),
                    timeout=timeout
                )
            except asyncio.TimeoutError:
                # Force kill
                self._process.kill()
                await self._process.wait()

        finally:
            self._started = False
            self._process = None

    async def wait_ready(self, *, timeout: float = 10.0) -> None:
        """Wait for server to be ready to accept connections.

        Args:
            timeout: Maximum time to wait in seconds

        Raises:
            asyncio.TimeoutError: If server doesn't become ready in time
            RuntimeError: If process exits unexpectedly

        Examples:
            >>> await manager.wait_ready(timeout=30.0)
        """
        import aiohttp

        start_time = asyncio.get_event_loop().time()
        endpoint = self.config.endpoint

        while True:
            # Check if process died
            if self._process and self._process.returncode is not None:
                raise RuntimeError(
                    f"AgentFS process exited with code {self._process.returncode}"
                )

            # Check timeout
            elapsed = asyncio.get_event_loop().time() - start_time
            if elapsed > timeout:
                raise asyncio.TimeoutError(
                    f"AgentFS not ready after {timeout}s"
                )

            # Try to connect
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        f"{endpoint}/health",
                        timeout=aiohttp.ClientTimeout(total=1.0)
                    ) as resp:
                        if resp.status == 200:
                            return
            except (aiohttp.ClientError, asyncio.TimeoutError):
                pass

            # Wait before retry
            await asyncio.sleep(0.5)

    async def is_healthy(self) -> bool:
        """Check if server is healthy.

        Returns:
            True if server responds to health check

        Examples:
            >>> if await manager.is_healthy():
            ...     print("Server is healthy")
        """
        if not self._started:
            return False

        try:
            import aiohttp

            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.config.endpoint}/health",
                    timeout=aiohttp.ClientTimeout(total=2.0)
                ) as resp:
                    return resp.status == 200
        except Exception:
            return False

    async def get_client(self):
        """Get an AgentFS client connected to this manager's instance.

        Returns:
            Connected AgentFS client

        Raises:
            RuntimeError: If manager not started

        Examples:
            >>> client = await manager.get_client()
            >>> await client.fs.write_file("/test.txt", "content")
        """
        if not self._started:
            raise RuntimeError("Manager not started. Call start() first.")

        from agentfs_sdk import AgentFS

        return await AgentFS.open({"id": self.config.id})

    @property
    def is_running(self) -> bool:
        """Check if process is currently running."""
        return (
            self._started
            and self._process is not None
            and self._process.returncode is None
        )

    @property
    def pid(self) -> Optional[int]:
        """Get process ID if running."""
        if self._process:
            return self._process.pid
        return None

    async def __aenter__(self):
        """Context manager entry - start the server."""
        await self.start()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - stop the server."""
        await self.stop()
        return False

    def __repr__(self) -> str:
        status = "running" if self.is_running else "stopped"
        return f"AgentFSManager(id={self.config.id}, status={status})"
```

### 4.2 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.manager import AgentFSConfig, AgentFSManager

__all__ = [
    # ... existing ...
    "AgentFSConfig",
    "AgentFSManager",
]
```

### 4.3 Add Dependency

AgentFS manager needs `aiohttp` for health checks:

```bash
cd /home/user/nixbox/agentfs-pydantic
uv add aiohttp
```

### 4.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_manager.py`:

```python
"""Tests for AgentFS lifecycle manager."""

import pytest
from pathlib import Path

from agentfs_pydantic.manager import AgentFSConfig, AgentFSManager


@pytest.fixture
def config():
    """Create test configuration."""
    return AgentFSConfig(
        id="test-manager-agent",
        host="127.0.0.1",
        port=8182,  # Use different port to avoid conflicts
    )


class TestAgentFSConfig:
    """Tests for AgentFSConfig model."""

    def test_default_values(self):
        """Test default configuration values."""
        config = AgentFSConfig(id="test")
        assert config.host == "127.0.0.1"
        assert config.port == 8081
        assert config.log_level == "info"

    def test_db_path_property(self):
        """Test database path computation."""
        config = AgentFSConfig(id="my-agent")
        expected = Path.home() / ".agentfs" / "my-agent.db"
        assert config.db_path == expected

    def test_endpoint_property(self):
        """Test endpoint URL generation."""
        config = AgentFSConfig(id="test", host="0.0.0.0", port=9000)
        assert config.endpoint == "http://0.0.0.0:9000"


class TestAgentFSManager:
    """Tests for AgentFSManager lifecycle."""

    @pytest.mark.asyncio
    async def test_manager_start_stop(self, config):
        """Test starting and stopping manager."""
        manager = AgentFSManager(config)

        # Should not be running initially
        assert not manager.is_running
        assert manager.pid is None

        # Note: This test requires agentfs serve to be available
        # You may need to skip if not in proper environment
        try:
            await manager.start(wait_ready=True, timeout=10.0)
            assert manager.is_running
            assert manager.pid is not None

            # Check health
            is_healthy = await manager.is_healthy()
            assert is_healthy

            # Stop
            await manager.stop()
            assert not manager.is_running
        except FileNotFoundError:
            pytest.skip("agentfs binary not available")

    @pytest.mark.asyncio
    async def test_context_manager(self, config):
        """Test context manager interface."""
        try:
            async with AgentFSManager(config) as manager:
                assert manager.is_running
                assert await manager.is_healthy()
            # Should be stopped after exit
            assert not manager.is_running
        except FileNotFoundError:
            pytest.skip("agentfs binary not available")

    @pytest.mark.asyncio
    async def test_get_client(self, config):
        """Test getting connected client."""
        try:
            async with AgentFSManager(config) as manager:
                client = await manager.get_client()
                assert client is not None
        except FileNotFoundError:
            pytest.skip("agentfs binary not available")
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import AgentFSConfig, AgentFSManager

async def main():
    # Create configuration
    config = AgentFSConfig(
        id="test-manager",
        port=8182
    )

    print(f"Starting AgentFS at {config.endpoint}...")

    # Use context manager
    async with AgentFSManager(config) as manager:
        print(f"AgentFS running (PID: {manager.pid})")
        print(f"Healthy: {await manager.is_healthy()}")

        # Get client and do something
        client = await manager.get_client()
        await client.fs.write_file("/test.txt", "Hello from manager")

        print("Waiting 5 seconds...")
        await asyncio.sleep(5)

    print("AgentFS stopped")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_manager.py -v
```

## Success Criteria

- [ ] `AgentFSConfig` model created with validation
- [ ] `AgentFSManager` class created with start/stop methods
- [ ] Process lifecycle management works correctly
- [ ] Health checks work
- [ ] Graceful shutdown works
- [ ] Context manager support works
- [ ] `get_client()` returns working client
- [ ] All tests pass
- [ ] Dependency (aiohttp) added

## Common Issues

**Issue**: Server fails to start
- **Solution**: Check if port is already in use, try different port

**Issue**: Readiness check times out
- **Solution**: Increase timeout, check server logs for startup issues

**Issue**: Process doesn't stop
- **Solution**: Check logs, may need to manually kill process

## Next Steps

Once this step is complete:
1. Proceed to [Step 5: devenv.sh Integration](./DEV_GUIDE-STEP_05.md)
2. The manager will be used for automatic AgentFS management in devenv environments

## Design Notes

- Uses asyncio subprocess for process management
- Health checks use HTTP endpoint (assumes AgentFS exposes /health)
- Graceful shutdown: SIGTERM first, then SIGKILL
- Context manager ensures cleanup even on errors
