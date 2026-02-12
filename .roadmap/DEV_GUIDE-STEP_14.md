# Step 14: MCP/NFS Servers

**Phase**: 3 - Advanced
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Phase 2

## Objective

Implement server operations for MCP and NFS:
- Start MCP (Model Context Protocol) server
- Start NFS server
- Server lifecycle management
- Context managers for automatic cleanup

## Why This Matters

Server operations enable:
- MCP integration for AI tools
- NFS access for external systems
- Remote filesystem access
- Integration with other tools

## Implementation Guide

### 14.1 Extend Models for Server Configuration

Already defined in Step 2, but verify in `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/models.py`:

```python
class MCPServerConfig(BaseModel):
    """Configuration for MCP server."""
    tools: list[str] = Field(
        default_factory=lambda: [
            "read_file",
            "write_file",
            "list_directory",
            "kv_get",
            "kv_set"
        ]
    )
    bind: str = Field(default="127.0.0.1")
    port: int = Field(default=8082, gt=0, lt=65536)


class NFSServerConfig(BaseModel):
    """Configuration for NFS server."""
    bind: str = Field(default="127.0.0.1")
    port: int = Field(default=11111, gt=0, lt=65536)


class ServerInfo(BaseModel):
    """Information about running server."""
    server_type: Literal["mcp", "nfs"]
    agent_id: str
    bind_address: str
    port: int
    pid: Optional[int] = None
    url: Optional[str] = None
```

### 14.2 Create Server Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/serve.py`:

```python
"""Server operations for MCP and NFS."""

import asyncio
from typing import Optional
from contextlib import asynccontextmanager

from agentfs_pydantic.cli import AgentFSCLI, AgentFSBinary
from agentfs_pydantic.models import (
    MCPServerConfig,
    NFSServerConfig,
    ServerInfo,
)
from agentfs_pydantic.exceptions import ServerError


class ServerHandle:
    """Handle for a running server process.

    Examples:
        >>> server = await ServerHandle.start_mcp("my-agent")
        >>> print(f"Server at: {server.url}")
        >>> await server.stop()
    """

    def __init__(
        self,
        server_type: str,
        agent_id: str,
        process: asyncio.subprocess.Process,
        config: MCPServerConfig | NFSServerConfig
    ):
        """Initialize server handle.

        Args:
            server_type: "mcp" or "nfs"
            agent_id: Agent being served
            process: Server process
            config: Server configuration
        """
        self.server_type = server_type
        self.agent_id = agent_id
        self.process = process
        self.config = config

    @property
    def url(self) -> str:
        """Get server URL."""
        if self.server_type == "mcp":
            return f"http://{self.config.bind}:{self.config.port}"
        else:
            return f"nfs://{self.config.bind}:{self.config.port}"

    @property
    def is_running(self) -> bool:
        """Check if server is still running."""
        return self.process.returncode is None

    async def stop(self):
        """Stop the server."""
        if self.is_running:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), timeout=5.0)
            except asyncio.TimeoutError:
                self.process.kill()
                await self.process.wait()

    async def wait(self):
        """Wait for server to exit."""
        await self.process.wait()

    def info(self) -> ServerInfo:
        """Get server information."""
        return ServerInfo(
            server_type=self.server_type,
            agent_id=self.agent_id,
            bind_address=self.config.bind,
            port=self.config.port,
            pid=self.process.pid,
            url=self.url
        )

    @classmethod
    async def start_mcp(
        cls,
        agent_id: str,
        *,
        config: Optional[MCPServerConfig] = None,
        binary: Optional[AgentFSBinary] = None
    ) -> "ServerHandle":
        """Start MCP server.

        Args:
            agent_id: Agent to serve
            config: MCP configuration
            binary: Optional binary wrapper

        Returns:
            ServerHandle for the server

        Raises:
            ServerError: If server fails to start
        """
        config = config or MCPServerConfig()
        binary = binary or AgentFSBinary()

        args = ["serve", "mcp", agent_id]
        args.extend(["--bind", config.bind])
        args.extend(["--port", str(config.port)])

        if config.tools:
            for tool in config.tools:
                args.extend(["--tool", tool])

        try:
            # Start server process
            cmd = [str(binary.binary_path)] + args
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            # Wait a bit for server to start
            await asyncio.sleep(0.5)

            if process.returncode is not None:
                stderr = await process.stderr.read()
                raise ServerError(
                    f"MCP server failed to start: {stderr.decode()}",
                    server_type="mcp",
                    bind_address=f"{config.bind}:{config.port}"
                )

            return cls("mcp", agent_id, process, config)

        except Exception as e:
            raise ServerError(
                f"Failed to start MCP server: {e}",
                server_type="mcp",
                bind_address=f"{config.bind}:{config.port}"
            ) from e

    @classmethod
    async def start_nfs(
        cls,
        agent_id: str,
        *,
        config: Optional[NFSServerConfig] = None,
        binary: Optional[AgentFSBinary] = None
    ) -> "ServerHandle":
        """Start NFS server.

        Args:
            agent_id: Agent to serve
            config: NFS configuration
            binary: Optional binary wrapper

        Returns:
            ServerHandle for the server

        Raises:
            ServerError: If server fails to start
        """
        config = config or NFSServerConfig()
        binary = binary or AgentFSBinary()

        args = ["serve", "nfs", agent_id]
        args.extend(["--bind", config.bind])
        args.extend(["--port", str(config.port)])

        try:
            cmd = [str(binary.binary_path)] + args
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            # Wait for server to start
            await asyncio.sleep(0.5)

            if process.returncode is not None:
                stderr = await process.stderr.read()
                raise ServerError(
                    f"NFS server failed to start: {stderr.decode()}",
                    server_type="nfs",
                    bind_address=f"{config.bind}:{config.port}"
                )

            return cls("nfs", agent_id, process, config)

        except Exception as e:
            raise ServerError(
                f"Failed to start NFS server: {e}",
                server_type="nfs",
                bind_address=f"{config.bind}:{config.port}"
            ) from e


@asynccontextmanager
async def mcp_server(
    agent_id: str,
    *,
    config: Optional[MCPServerConfig] = None
):
    """Context manager for MCP server.

    Args:
        agent_id: Agent to serve
        config: MCP configuration

    Yields:
        ServerHandle

    Examples:
        >>> async with mcp_server("my-agent") as server:
        ...     print(f"MCP server at: {server.url}")
        ...     # Server automatically stopped on exit
    """
    server = await ServerHandle.start_mcp(agent_id, config=config)
    try:
        yield server
    finally:
        await server.stop()


@asynccontextmanager
async def nfs_server(
    agent_id: str,
    *,
    config: Optional[NFSServerConfig] = None
):
    """Context manager for NFS server.

    Args:
        agent_id: Agent to serve
        config: NFS configuration

    Yields:
        ServerHandle

    Examples:
        >>> async with nfs_server("my-agent") as server:
        ...     print(f"NFS server at: {server.url}")
        ...     # Mount from external system
        ...     # Server automatically stopped on exit
    """
    server = await ServerHandle.start_nfs(agent_id, config=config)
    try:
        yield server
    finally:
        await server.stop()
```

### 14.3 Add Server Methods to CLI

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    async def serve_mcp(
        self,
        agent_id: str,
        *,
        config: Optional["MCPServerConfig"] = None
    ) -> "ServerHandle":
        """Start MCP server.

        Args:
            agent_id: Agent to serve
            config: MCP configuration

        Returns:
            ServerHandle for the server

        Examples:
            >>> server = await cli.serve_mcp("my-agent")
            >>> print(f"MCP at: {server.url}")
            >>> await server.stop()
        """
        from agentfs_pydantic.serve import ServerHandle
        return await ServerHandle.start_mcp(agent_id, config=config, binary=self.binary)

    async def serve_nfs(
        self,
        agent_id: str,
        *,
        config: Optional["NFSServerConfig"] = None
    ) -> "ServerHandle":
        """Start NFS server.

        Args:
            agent_id: Agent to serve
            config: NFS configuration

        Returns:
            ServerHandle for the server

        Examples:
            >>> server = await cli.serve_nfs("my-agent")
            >>> print(f"NFS at: {server.url}")
            >>> await server.stop()
        """
        from agentfs_pydantic.serve import ServerHandle
        return await ServerHandle.start_nfs(agent_id, config=config, binary=self.binary)
```

### 14.4 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.serve import ServerHandle, mcp_server, nfs_server

__all__ = [
    # ... existing ...
    "ServerHandle",
    "mcp_server",
    "nfs_server",
]
```

### 14.5 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_serve.py`:

```python
"""Tests for server operations."""

import pytest
from pathlib import Path

from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    MCPServerConfig,
    NFSServerConfig,
    mcp_server,
    nfs_server,
)


@pytest.fixture
async def test_agent():
    """Create test agent."""
    cli = AgentFSCLI()
    agent_id = "server-test"
    await cli.init(agent_id, options=InitOptions(force=True))
    yield agent_id
    # Cleanup
    import os
    db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
    if db_path.exists():
        os.remove(db_path)


class TestServers:
    """Tests for server operations."""

    @pytest.mark.asyncio
    async def test_mcp_server_context(self, test_agent):
        """Test MCP server context manager."""
        async with mcp_server(test_agent) as server:
            assert server.is_running
            assert server.server_type == "mcp"
            assert server.url.startswith("http://")

        # Server should be stopped after context
        assert not server.is_running

    @pytest.mark.asyncio
    async def test_nfs_server_context(self, test_agent):
        """Test NFS server context manager."""
        async with nfs_server(test_agent) as server:
            assert server.is_running
            assert server.server_type == "nfs"
            assert server.url.startswith("nfs://")

        assert not server.is_running

    @pytest.mark.asyncio
    async def test_server_info(self, test_agent):
        """Test server info."""
        async with mcp_server(test_agent) as server:
            info = server.info()
            assert info.server_type == "mcp"
            assert info.agent_id == test_agent
            assert info.pid is not None

    @pytest.mark.asyncio
    async def test_custom_config(self, test_agent):
        """Test server with custom configuration."""
        config = MCPServerConfig(
            bind="127.0.0.1",
            port=8090,
            tools=["read_file", "write_file"]
        )

        async with mcp_server(test_agent, config=config) as server:
            assert server.config.port == 8090
            assert len(server.config.tools) == 2
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    MCPServerConfig,
    NFSServerConfig,
    mcp_server,
    nfs_server,
)

async def main():
    cli = AgentFSCLI()

    # Create agent
    await cli.init("server-demo", options=InitOptions(force=True))

    # Test MCP server
    print("1. Starting MCP server...")
    async with mcp_server("server-demo") as server:
        print(f"MCP server running at: {server.url}")
        print(f"PID: {server.process.pid}")
        print(f"Tools: {server.config.tools}")

        # Keep server running briefly
        await asyncio.sleep(2)

    print("MCP server stopped")

    # Test NFS server
    print("\n2. Starting NFS server...")
    config = NFSServerConfig(port=11111)
    async with nfs_server("server-demo", config=config) as server:
        print(f"NFS server running at: {server.url}")
        await asyncio.sleep(2)

    print("NFS server stopped")

    # Manual server control
    print("\n3. Manual server control...")
    server = await cli.serve_mcp("server-demo")
    print(f"Started: {server.url}")
    await asyncio.sleep(2)
    await server.stop()
    print("Stopped")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_serve.py -v
```

## Success Criteria

- [ ] MCP server operations implemented
- [ ] NFS server operations implemented
- [ ] ServerHandle manages process lifecycle
- [ ] Context managers auto-cleanup servers
- [ ] Server configuration options work
- [ ] Server info accessible
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Port already in use
- **Solution**: Use different port in config

**Issue**: Server fails to start
- **Solution**: Check AgentFS binary supports server commands

**Issue**: Server doesn't stop
- **Solution**: ServerHandle uses terminate then kill

## Next Steps

Once Phase 3 is complete:
1. Proceed to [Step 15: Observer/Event System](./DEV_GUIDE-STEP_15.md)
2. Begin Phase 4: Quality improvements

## Design Notes

- Servers run as separate processes
- Context managers ensure cleanup
- Both MCP and NFS supported
- Configurable bind address and port
- Server handles provide lifecycle control
- Async-first design throughout
