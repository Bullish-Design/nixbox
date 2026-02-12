# Step 3: Init/Exec/Run Operations

**Phase**: 1 - Core (MVP)
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Steps 1-2 (CLI Binary Wrapper, Enhanced Models)

## Objective

Implement type-safe wrappers for the core AgentFS CLI commands:
- `agentfs init` - Initialize new AgentFS instances
- `agentfs exec` - Execute commands in existing instances
- `agentfs run` - Run commands in sandboxed environments

These are the foundational operations for all AgentFS workflows.

## Why This Matters

These operations enable:
- Creating new AgentFS databases programmatically
- Running commands inside AgentFS environments
- Sandboxed execution with copy-on-write filesystems
- Foundation for all higher-level APIs

## Implementation Guide

### 3.1 Create AgentFSCLI Class

Create the main CLI class that uses `AgentFSBinary` to provide high-level operations.

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    """High-level interface for AgentFS CLI operations.

    Provides type-safe wrappers around agentfs commands.

    Examples:
        >>> cli = AgentFSCLI()
        >>> await cli.init("my-agent")
        >>> result = await cli.exec("my-agent", ["ls", "-la"])
        >>> print(result.stdout)
    """

    def __init__(self, binary_path: Optional[Path] = None):
        """Initialize CLI wrapper.

        Args:
            binary_path: Optional explicit path to agentfs binary
        """
        self.binary = AgentFSBinary(binary_path=binary_path)

    async def init(
        self,
        agent_id: str,
        *,
        options: Optional["InitOptions"] = None,
    ) -> CommandResult:
        """Initialize a new AgentFS instance.

        Args:
            agent_id: Unique identifier for the agent
            options: Configuration options for initialization

        Returns:
            CommandResult with initialization output

        Examples:
            >>> # Basic init
            >>> await cli.init("my-agent")

            >>> # Init with overlay
            >>> await cli.init(
            ...     "overlay-agent",
            ...     options=InitOptions(base=Path("/my/project"))
            ... )

            >>> # Init with encryption
            >>> await cli.init(
            ...     "secure-agent",
            ...     options=InitOptions(
            ...         encryption=EncryptionConfig(
            ...             key="0" * 64,
            ...             cipher="aes256gcm"
            ...         )
            ...     )
            ... )
        """
        from agentfs_pydantic.models import InitOptions

        args = ["init", agent_id]

        if options:
            if options.force:
                args.append("--force")

            if options.base:
                args.extend(["--base", str(options.base)])

            if options.encryption:
                args.extend([
                    "--encryption-key", options.encryption.key,
                    "--cipher", options.encryption.cipher
                ])

            if options.sync_config:
                args.extend([
                    "--remote-url", options.sync_config.url,
                ])
                if options.sync_config.auth_token:
                    args.extend(["--auth-token", options.sync_config.auth_token])
                if options.sync_config.partial_prefetch:
                    args.append("--partial-prefetch")

            if options.backend:
                args.extend(["--backend", options.backend])

            if options.command:
                args.append("--")
                args.extend(options.command)

        return await self.binary.execute(args)

    async def init_and_exec(
        self,
        agent_id: str,
        command: list[str],
        *,
        options: Optional["InitOptions"] = None,
    ) -> CommandResult:
        """Initialize agent and immediately run a command.

        Convenience wrapper for init with command option.

        Args:
            agent_id: Unique identifier for the agent
            command: Command to execute after init
            options: Configuration options (command will be added)

        Returns:
            CommandResult from the executed command

        Examples:
            >>> result = await cli.init_and_exec(
            ...     "build-agent",
            ...     ["make", "build"],
            ...     options=InitOptions(base=Path("/my/project"))
            ... )
        """
        from agentfs_pydantic.models import InitOptions

        opts = options or InitOptions()
        opts.command = command

        return await self.init(agent_id, options=opts)

    async def exec(
        self,
        agent_id: str,
        command: list[str],
        *,
        options: Optional["ExecOptions"] = None,
    ) -> CommandResult:
        """Execute a command in an existing AgentFS instance.

        Args:
            agent_id: Agent identifier or database path
            command: Command to execute
            options: Execution options (backend, encryption)

        Returns:
            CommandResult with command output

        Examples:
            >>> # Simple execution
            >>> result = await cli.exec("my-agent", ["ls", "-la"])
            >>> print(result.stdout)

            >>> # With encryption
            >>> result = await cli.exec(
            ...     "secure-agent",
            ...     ["cat", "/secret.txt"],
            ...     options=ExecOptions(
            ...         encryption=EncryptionConfig(
            ...             key="...",
            ...             cipher="aes256gcm"
            ...         )
            ...     )
            ... )
        """
        from agentfs_pydantic.models import ExecOptions

        args = ["exec", agent_id]

        if options:
            if options.backend:
                args.extend(["--backend", options.backend])

            if options.encryption:
                args.extend([
                    "--encryption-key", options.encryption.key,
                    "--cipher", options.encryption.cipher
                ])

        args.append("--")
        args.extend(command)

        return await self.binary.execute(args)

    async def run(
        self,
        command: list[str],
        *,
        options: Optional["SandboxOptions"] = None,
    ) -> CommandResult:
        """Run a command in a sandboxed AgentFS environment.

        Creates a temporary copy-on-write filesystem for the command.

        Args:
            command: Command to execute in sandbox
            options: Sandbox configuration

        Returns:
            CommandResult with command output

        Examples:
            >>> # Basic sandbox
            >>> result = await cli.run(["python", "script.py"])

            >>> # With persistent session
            >>> result = await cli.run(
            ...     ["make", "build"],
            ...     options=SandboxOptions(
            ...         session="build-session",
            ...         allowed_paths=["/home/user/.cache"]
            ...     )
            ... )

            >>> # With strace for debugging
            >>> result = await cli.run(
            ...     ["./test"],
            ...     options=SandboxOptions(strace=True)
            ... )
        """
        from agentfs_pydantic.models import SandboxOptions

        args = ["run"]

        if options:
            if options.session:
                args.extend(["--session", options.session])

            if options.allowed_paths:
                for path in options.allowed_paths:
                    args.extend(["--allowed-path", path])

            if options.no_default_allows:
                args.append("--no-default-allows")

            if options.experimental_sandbox:
                args.append("--experimental-sandbox")

            if options.strace:
                args.append("--strace")

        args.append("--")
        args.extend(command)

        return await self.binary.execute(args)

    async def version(self) -> str:
        """Get AgentFS version.

        Returns:
            Version string

        Examples:
            >>> version = await cli.version()
            >>> print(f"AgentFS {version}")
        """
        result = await self.binary.execute(["version"])
        return result.stdout.strip()
```

### 3.2 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.cli import AgentFSBinary, AgentFSCLI, CommandResult

__all__ = [
    # ... existing ...
    "AgentFSCLI",
]
```

### 3.3 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_cli_operations.py`:

```python
"""Tests for CLI operations (init/exec/run)."""

import pytest
import tempfile
from pathlib import Path

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import (
    InitOptions,
    ExecOptions,
    SandboxOptions,
    EncryptionConfig,
)


@pytest.fixture
def cli():
    """Create CLI instance for testing."""
    return AgentFSCLI()


@pytest.fixture
def temp_agent_id():
    """Generate temporary agent ID."""
    import uuid
    return f"test-{uuid.uuid4().hex[:8]}"


class TestInit:
    """Tests for init operation."""

    @pytest.mark.asyncio
    async def test_basic_init(self, cli, temp_agent_id):
        """Test basic agent initialization."""
        result = await cli.init(temp_agent_id)
        assert result.success

        # Cleanup
        import os
        db_path = Path.home() / ".agentfs" / f"{temp_agent_id}.db"
        if db_path.exists():
            os.remove(db_path)

    @pytest.mark.asyncio
    async def test_init_with_force(self, cli, temp_agent_id):
        """Test init with force flag."""
        # Init once
        await cli.init(temp_agent_id)

        # Init again with force
        result = await cli.init(
            temp_agent_id,
            options=InitOptions(force=True)
        )
        assert result.success

        # Cleanup
        import os
        db_path = Path.home() / ".agentfs" / f"{temp_agent_id}.db"
        if db_path.exists():
            os.remove(db_path)

    @pytest.mark.asyncio
    async def test_init_with_base(self, cli, temp_agent_id):
        """Test init with base directory overlay."""
        with tempfile.TemporaryDirectory() as tmpdir:
            base_path = Path(tmpdir)

            # Create some files in base
            (base_path / "test.txt").write_text("base content")

            # Init with overlay
            result = await cli.init(
                temp_agent_id,
                options=InitOptions(base=base_path)
            )
            assert result.success

            # Cleanup
            import os
            db_path = Path.home() / ".agentfs" / f"{temp_agent_id}.db"
            if db_path.exists():
                os.remove(db_path)


class TestExec:
    """Tests for exec operation."""

    @pytest.mark.asyncio
    async def test_exec_command(self, cli, temp_agent_id):
        """Test executing command in agent."""
        # First init an agent
        await cli.init(temp_agent_id)

        # Execute command
        result = await cli.exec(temp_agent_id, ["echo", "hello"])
        assert result.success
        assert "hello" in result.stdout

        # Cleanup
        import os
        db_path = Path.home() / ".agentfs" / f"{temp_agent_id}.db"
        if db_path.exists():
            os.remove(db_path)

    @pytest.mark.asyncio
    async def test_exec_list_files(self, cli, temp_agent_id):
        """Test listing files in agent."""
        await cli.init(temp_agent_id)

        result = await cli.exec(temp_agent_id, ["ls", "-la"])
        assert result.success

        # Cleanup
        import os
        db_path = Path.home() / ".agentfs" / f"{temp_agent_id}.db"
        if db_path.exists():
            os.remove(db_path)


class TestRun:
    """Tests for run (sandbox) operation."""

    @pytest.mark.asyncio
    async def test_basic_run(self, cli):
        """Test basic sandboxed execution."""
        result = await cli.run(["echo", "sandboxed"])
        assert result.success
        assert "sandboxed" in result.stdout

    @pytest.mark.asyncio
    async def test_run_with_session(self, cli):
        """Test sandbox with named session."""
        result = await cli.run(
            ["echo", "session-test"],
            options=SandboxOptions(session="test-session")
        )
        assert result.success

    @pytest.mark.asyncio
    async def test_run_python_script(self, cli):
        """Test running Python in sandbox."""
        result = await cli.run(
            ["python", "-c", "print('hello from sandbox')"]
        )
        assert result.success
        assert "hello from sandbox" in result.stdout


class TestIntegration:
    """Integration tests combining operations."""

    @pytest.mark.asyncio
    async def test_init_and_exec_workflow(self, cli, temp_agent_id):
        """Test complete init + exec workflow."""
        # Initialize
        init_result = await cli.init(temp_agent_id)
        assert init_result.success

        # Execute commands
        result = await cli.exec(temp_agent_id, ["pwd"])
        assert result.success

        result = await cli.exec(temp_agent_id, ["echo", "test"])
        assert result.success
        assert "test" in result.stdout

        # Cleanup
        import os
        db_path = Path.home() / ".agentfs" / f"{temp_agent_id}.db"
        if db_path.exists():
            os.remove(db_path)

    @pytest.mark.asyncio
    async def test_version(self, cli):
        """Test getting version."""
        version = await cli.version()
        assert len(version) > 0
        assert isinstance(version, str)
```

## Testing

### Manual Testing

```python
import asyncio
from pathlib import Path
from agentfs_pydantic import AgentFSCLI, InitOptions, SandboxOptions

async def main():
    cli = AgentFSCLI()

    # Test version
    version = await cli.version()
    print(f"AgentFS version: {version}")

    # Test init
    print("\n1. Testing init...")
    result = await cli.init("test-agent", options=InitOptions(force=True))
    print(f"Init success: {result.success}")

    # Test exec
    print("\n2. Testing exec...")
    result = await cli.exec("test-agent", ["echo", "Hello from AgentFS"])
    print(f"Output: {result.stdout.strip()}")

    # Test run (sandbox)
    print("\n3. Testing sandbox...")
    result = await cli.run(
        ["python", "-c", "import os; print(f'PID: {os.getpid()}')"],
        options=SandboxOptions(session="test-session")
    )
    print(f"Sandbox output: {result.stdout.strip()}")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_cli_operations.py -v
```

## Success Criteria

- [ ] `AgentFSCLI` class created with init/exec/run methods
- [ ] All options models properly integrated
- [ ] Commands build correctly from options
- [ ] Init operation works (basic and with overlay)
- [ ] Exec operation works in existing agents
- [ ] Run (sandbox) operation works
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Agent database already exists
- **Solution**: Use `force=True` in InitOptions or manually delete `.agentfs/<id>.db`

**Issue**: Command fails in exec
- **Solution**: Ensure agent was initialized first with `init()`

**Issue**: Permission errors in sandbox
- **Solution**: Check allowed_paths configuration

## Next Steps

Once this step is complete:
1. Proceed to [Step 4: AgentFSManager Lifecycle](./DEV_GUIDE-STEP_04.md)
2. These operations will be used by the manager for automated lifecycle control

## Design Notes

- Commands are built incrementally from options
- All operations return `CommandResult` for consistent handling
- Options are validated by Pydantic before CLI construction
- `--` separator used before user commands for safety
