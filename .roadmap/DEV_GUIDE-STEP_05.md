# Step 5: devenv.sh Integration

**Phase**: 1 - Core (MVP)
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: Steps 1-4 (CLI, Models, Operations, Manager)

## Objective

Create seamless integration with devenv.sh environments by:
- Auto-detecting devenv.sh environment variables
- Providing connection helpers for managed AgentFS instances
- Supporting standard devenv.sh configuration patterns

## Why This Matters

The nixbox project is designed for devenv.sh environments. This integration:
- Eliminates manual configuration
- Works with `devenv up` managed processes
- Follows nixbox plugin conventions
- Provides zero-config experience

## Implementation Guide

### 5.1 Create devenv.py Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/devenv.py`:

```python
"""devenv.sh integration for AgentFS.

Provides automatic configuration from devenv environment variables.
"""

import os
from pathlib import Path
from typing import Optional
from pydantic import BaseModel, Field


class DevEnvConfig(BaseModel):
    """Configuration from devenv.sh environment.

    Reads standard devenv.sh environment variables:
    - AGENTFS_HOST
    - AGENTFS_PORT
    - AGENTFS_DATA_DIR
    - AGENTFS_DB_NAME
    - AGENTFS_LOG_LEVEL

    Examples:
        >>> # Auto-detect from environment
        >>> config = DevEnvConfig.from_env()

        >>> # Manual configuration
        >>> config = DevEnvConfig(
        ...     host="127.0.0.1",
        ...     port=8081,
        ...     db_name="sandbox"
        ... )
    """

    host: str = Field(
        default="127.0.0.1",
        description="AgentFS bind host"
    )
    port: int = Field(
        default=8081,
        description="AgentFS bind port",
        gt=0,
        lt=65536
    )
    data_dir: Path = Field(
        default_factory=lambda: Path(".devenv/state/agentfs"),
        description="AgentFS data directory"
    )
    db_name: str = Field(
        default="sandbox",
        description="Database name"
    )
    log_level: str = Field(
        default="info",
        description="Log level"
    )
    enabled: bool = Field(
        default=True,
        description="Whether AgentFS is enabled"
    )

    @classmethod
    def from_env(cls) -> "DevEnvConfig":
        """Create configuration from environment variables.

        Reads devenv.sh standard variables with fallback to defaults.

        Returns:
            DevEnvConfig populated from environment

        Examples:
            >>> config = DevEnvConfig.from_env()
            >>> print(f"Connecting to {config.endpoint}")
        """
        return cls(
            host=os.getenv("AGENTFS_HOST", "127.0.0.1"),
            port=int(os.getenv("AGENTFS_PORT", "8081")),
            data_dir=Path(os.getenv("AGENTFS_DATA_DIR", ".devenv/state/agentfs")),
            db_name=os.getenv("AGENTFS_DB_NAME", "sandbox"),
            log_level=os.getenv("AGENTFS_LOG_LEVEL", "info"),
            enabled=os.getenv("AGENTFS_ENABLED", "1") == "1",
        )

    @property
    def endpoint(self) -> str:
        """Get the HTTP endpoint URL."""
        return f"http://{self.host}:{self.port}"

    @property
    def db_path(self) -> Path:
        """Get the database file path."""
        return self.data_dir / f"{self.db_name}.db"


class DevEnvIntegration:
    """Integration helper for devenv.sh managed AgentFS.

    Provides convenient access to AgentFS instances managed by devenv.sh.

    Examples:
        >>> # Auto-detect configuration
        >>> integration = DevEnvIntegration.from_env()

        >>> # Connect to devenv-managed instance
        >>> async with integration.connect() as agent:
        ...     await agent.fs.write_file("/test.txt", "content")

        >>> # Check if AgentFS is available
        >>> if integration.is_available():
        ...     print("AgentFS is running")
    """

    def __init__(self, config: Optional[DevEnvConfig] = None):
        """Initialize integration.

        Args:
            config: DevEnv configuration (auto-detected if None)
        """
        self.config = config or DevEnvConfig.from_env()

    @classmethod
    def from_env(cls) -> "DevEnvIntegration":
        """Create integration from environment variables.

        Returns:
            DevEnvIntegration with auto-detected configuration

        Examples:
            >>> integration = DevEnvIntegration.from_env()
        """
        return cls(DevEnvConfig.from_env())

    async def connect(self):
        """Connect to devenv-managed AgentFS instance.

        Returns:
            AgentFS client connected to the devenv instance

        Raises:
            RuntimeError: If AgentFS is not enabled in devenv

        Examples:
            >>> async with integration.connect() as agent:
            ...     files = await agent.fs.list_files("/")
            ...     print(f"Found {len(files)} files")
        """
        if not self.config.enabled:
            raise RuntimeError(
                "AgentFS not enabled in devenv.sh. "
                "Set AGENTFS_ENABLED=1 in your devenv.nix"
            )

        from agentfs_sdk import AgentFS

        # Connect using the db_name from config
        return await AgentFS.open({
            "id": self.config.db_name,
            "path": str(self.config.db_path)
        })

    async def is_available(self) -> bool:
        """Check if devenv-managed AgentFS is available.

        Returns:
            True if AgentFS is reachable

        Examples:
            >>> if await integration.is_available():
            ...     print("AgentFS is ready")
            ... else:
            ...     print("Start with: devenv up")
        """
        if not self.config.enabled:
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

    def get_info_script(self) -> str:
        """Get the shell script content for agentfs-info command.

        This matches the script defined in devenv.nix.

        Returns:
            Shell script content

        Examples:
            >>> print(integration.get_info_script())
        """
        return f'''#!/usr/bin/env bash
echo "=== AgentFS Configuration (devenv.sh) ==="
echo "Enabled: {self.config.enabled}"
echo "Host: {self.config.host}"
echo "Port: {self.config.port}"
echo "Data Directory: {self.config.data_dir}"
echo "Database Name: {self.config.db_name}"
echo "Log Level: {self.config.log_level}"
echo "Endpoint: {self.config.endpoint}"
echo "Database Path: {self.config.db_path}"
echo ""
echo "To connect:"
echo "  import asyncio"
echo "  from nixbox import DevEnvIntegration"
echo "  "
echo "  async def main():"
echo "      integration = DevEnvIntegration.from_env()"
echo "      async with integration.connect() as agent:"
echo "          # Use agent..."
echo "  "
echo "  asyncio.run(main())"
'''

    def __repr__(self) -> str:
        return (
            f"DevEnvIntegration("
            f"endpoint={self.config.endpoint}, "
            f"db_name={self.config.db_name}"
            f")"
        )
```

### 5.2 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.devenv import DevEnvConfig, DevEnvIntegration

__all__ = [
    # ... existing ...
    "DevEnvConfig",
    "DevEnvIntegration",
]
```

### 5.3 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_devenv.py`:

```python
"""Tests for devenv.sh integration."""

import pytest
import os
from pathlib import Path

from agentfs_pydantic.devenv import DevEnvConfig, DevEnvIntegration


class TestDevEnvConfig:
    """Tests for DevEnvConfig model."""

    def test_default_values(self):
        """Test default configuration values."""
        config = DevEnvConfig()
        assert config.host == "127.0.0.1"
        assert config.port == 8081
        assert config.db_name == "sandbox"
        assert config.enabled is True

    def test_from_env_with_defaults(self, monkeypatch):
        """Test from_env with no environment variables."""
        # Clear any existing vars
        for key in ["AGENTFS_HOST", "AGENTFS_PORT", "AGENTFS_DB_NAME"]:
            monkeypatch.delenv(key, raising=False)

        config = DevEnvConfig.from_env()
        assert config.host == "127.0.0.1"
        assert config.port == 8081
        assert config.db_name == "sandbox"

    def test_from_env_with_custom_values(self, monkeypatch):
        """Test from_env with custom environment variables."""
        monkeypatch.setenv("AGENTFS_HOST", "0.0.0.0")
        monkeypatch.setenv("AGENTFS_PORT", "9000")
        monkeypatch.setenv("AGENTFS_DB_NAME", "custom-db")
        monkeypatch.setenv("AGENTFS_LOG_LEVEL", "debug")

        config = DevEnvConfig.from_env()
        assert config.host == "0.0.0.0"
        assert config.port == 9000
        assert config.db_name == "custom-db"
        assert config.log_level == "debug"

    def test_enabled_flag(self, monkeypatch):
        """Test AGENTFS_ENABLED flag."""
        # Enabled
        monkeypatch.setenv("AGENTFS_ENABLED", "1")
        config = DevEnvConfig.from_env()
        assert config.enabled is True

        # Disabled
        monkeypatch.setenv("AGENTFS_ENABLED", "0")
        config = DevEnvConfig.from_env()
        assert config.enabled is False

    def test_endpoint_property(self):
        """Test endpoint URL generation."""
        config = DevEnvConfig(host="192.168.1.1", port=3000)
        assert config.endpoint == "http://192.168.1.1:3000"

    def test_db_path_property(self):
        """Test database path computation."""
        config = DevEnvConfig(
            data_dir=Path("/tmp/agentfs"),
            db_name="test-db"
        )
        assert config.db_path == Path("/tmp/agentfs/test-db.db")


class TestDevEnvIntegration:
    """Tests for DevEnvIntegration."""

    def test_init_with_config(self):
        """Test initialization with explicit config."""
        config = DevEnvConfig(port=9000)
        integration = DevEnvIntegration(config)
        assert integration.config.port == 9000

    def test_from_env(self, monkeypatch):
        """Test from_env class method."""
        monkeypatch.setenv("AGENTFS_PORT", "8888")

        integration = DevEnvIntegration.from_env()
        assert integration.config.port == 8888

    def test_get_info_script(self):
        """Test info script generation."""
        integration = DevEnvIntegration()
        script = integration.get_info_script()

        assert "AgentFS Configuration" in script
        assert "from nixbox import DevEnvIntegration" in script
        assert integration.config.endpoint in script

    @pytest.mark.asyncio
    async def test_connect_when_disabled(self):
        """Test that connect raises when disabled."""
        config = DevEnvConfig(enabled=False)
        integration = DevEnvIntegration(config)

        with pytest.raises(RuntimeError, match="not enabled"):
            async with integration.connect() as agent:
                pass

    @pytest.mark.asyncio
    async def test_is_available_when_disabled(self):
        """Test that is_available returns False when disabled."""
        config = DevEnvConfig(enabled=False)
        integration = DevEnvIntegration(config)

        available = await integration.is_available()
        assert available is False
```

## Testing

### Manual Testing in devenv.sh

1. **Enter devenv shell**:
```bash
cd /home/user/nixbox
devenv shell
```

2. **Test configuration detection**:
```python
from agentfs_pydantic.devenv import DevEnvConfig

config = DevEnvConfig.from_env()
print(f"Host: {config.host}")
print(f"Port: {config.port}")
print(f"DB Name: {config.db_name}")
print(f"Endpoint: {config.endpoint}")
```

3. **Test integration**:
```python
import asyncio
from agentfs_pydantic.devenv import DevEnvIntegration

async def main():
    integration = DevEnvIntegration.from_env()

    print(f"Available: {await integration.is_available()}")

    if await integration.is_available():
        async with integration.connect() as agent:
            await agent.fs.write_file("/devenv-test.txt", "Hello from devenv!")
            print("Successfully wrote file via devenv integration")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_devenv.py -v
```

## Success Criteria

- [ ] `DevEnvConfig` model created with environment variable support
- [ ] `DevEnvIntegration` class created with connect() method
- [ ] Auto-detection from environment works
- [ ] Configuration matches devenv.nix variables
- [ ] Connection to devenv-managed instance works
- [ ] Availability check works
- [ ] Info script generation works
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Integration with nixbox devenv.nix

The devenv.nix file should define these environment variables:

```nix
env = {
  AGENTFS_ENABLED = "1";
  AGENTFS_HOST = "127.0.0.1";
  AGENTFS_PORT = "8081";
  AGENTFS_DATA_DIR = ".devenv/state/agentfs";
  AGENTFS_DB_NAME = "sandbox";
  AGENTFS_LOG_LEVEL = "info";
};
```

## Common Issues

**Issue**: Configuration not detected
- **Solution**: Ensure you're running inside `devenv shell`

**Issue**: Connection fails
- **Solution**: Ensure `devenv up` is running to start AgentFS process

**Issue**: Import errors
- **Solution**: Run `uv sync` to install dependencies

## Next Steps

Once Phase 1 is complete:
1. **Test the complete workflow** - init, exec, manage, connect from devenv
2. Proceed to [Phase 2: Essential Operations](./DEV_GUIDE-STEP_06.md)

## Design Notes

- Environment variables match nixbox devenv.nix conventions
- Zero-config experience when running in devenv.sh
- Falls back to sensible defaults
- Integration is optional - can use CLI directly
