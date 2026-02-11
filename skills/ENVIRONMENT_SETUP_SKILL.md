# Environment Setup Skill

**Skill ID**: `nixbox.environment.setup`
**Category**: Environment Management
**Complexity**: Beginner

## Description

Initialize and configure a reproducible AgentFS + devenv.sh development environment. This skill handles environment activation, process management, configuration validation, and health checks.

## Capabilities

- Enter devenv.sh shell with all dependencies
- Start/stop AgentFS background process
- Configure environment variables
- Validate AgentFS connectivity
- Display configuration status
- Manage process lifecycle

## Input Contract

### Prerequisites

- Nix package manager installed
- devenv CLI installed (`nix profile install nixpkgs#devenv`)
- Repository cloned locally
- Working directory = repository root

### Configuration Options

Environment variables (all optional, have defaults):

| Variable              | Default                          | Purpose                          |
|-----------------------|----------------------------------|----------------------------------|
| `AGENTFS_ENABLED`     | `1`                              | Enable/disable AgentFS process   |
| `AGENTFS_HOST`        | `127.0.0.1`                      | Server bind address              |
| `AGENTFS_PORT`        | `8081`                           | Server port                      |
| `AGENTFS_DATA_DIR`    | `.devenv/state/agentfs`          | SQLite database directory        |
| `AGENTFS_DB_NAME`     | `sandbox`                        | Database name                    |
| `AGENTFS_LOG_LEVEL`   | `info`                           | Logging verbosity                |
| `AGENTFS_EXTRA_ARGS`  | `""`                             | Additional CLI arguments         |
| `VENDOR_PATH`         | `$HOME/vendor`                   | Source directory for vendoring   |

## Output Contract

### Success Indicators

- Shell prompt changes (indicates devenv activation)
- AgentFS info displayed on shell entry
- Health check returns HTTP 200 from AgentFS URL
- All helper commands available (`agentfs-info`, `agentfs-url`, etc.)

### Error Conditions

- **Nix not installed**: `command not found: nix`
- **devenv not installed**: `command not found: devenv`
- **Build failure**: Nix build errors for AgentFS package
- **Port conflict**: Port 8081 already in use
- **Permission error**: Cannot create `.devenv/state/agentfs`

## Usage Examples

### Basic Shell Entry

```bash
# Enter development shell
cd /path/to/nixbox
devenv shell

# You'll see:
# --------------------------------------------------------
#
#  AgentFS development environment
#
#  Useful commands:
#    agentfs-info   # show current AgentFS config
#    agentfs-url    # print the base URL
#    ...
# --------------------------------------------------------
```

### Start Background Processes

```bash
# Start all managed processes (including AgentFS)
devenv up

# Output:
# 17:03:32 system | agentfs.1 started (pid=12345)
# 17:03:32 agentfs.1 | [INFO] AgentFS listening on http://127.0.0.1:8081
```

### Check Configuration

```bash
# Display current configuration
agentfs-info

# Output:
# AgentFS process configuration
# -----------------------------
# Repo root: /home/user/nixbox
# Enabled:   1 (shell), yes (eval)
# Host:      127.0.0.1
# Port:      8081
# Data dir:  /home/user/nixbox/.devenv/state/agentfs
# DB name:   sandbox
# Log level: info
# Extra:
```

### Health Check

```bash
# Get AgentFS base URL
URL=$(agentfs-url)
echo "AgentFS running at: $URL"

# Test connectivity
curl -s "$URL/health" || echo "AgentFS not responding"
```

### Custom Configuration

```bash
# Override port before entering shell
export AGENTFS_PORT=9090

# Enter shell
devenv shell

# Verify
agentfs-info  # Should show Port: 9090
```

### Disable AgentFS

```bash
# Disable AgentFS process (useful for testing)
export AGENTFS_ENABLED=0
devenv shell

# AgentFS process won't start, but library is still available
```

## Step-by-Step Workflow

### Initial Setup (First Time)

```bash
# 1. Clone repository
git clone <repo-url>
cd nixbox

# 2. Enter devenv shell (builds dependencies)
devenv shell

# 3. Verify AgentFS is available
which agentfs  # Should show Nix store path

# 4. (Optional) Run tests
pytest

# 5. (Optional) Run example
uv run examples/basic_usage.py
```

### Daily Development

```bash
# 1. Enter shell
cd nixbox
devenv shell

# 2. Start processes in background
devenv up

# 3. Develop (edit code, run tests, etc.)
pytest
uv run examples/basic_usage.py

# 4. When done, stop processes
# Press Ctrl+C in the devenv up terminal
```

### Troubleshooting Workflow

```bash
# 1. Check if AgentFS process is running
agentfs-info

# 2. Test AgentFS directly
agentfs-cli --help

# 3. Run AgentFS in foreground for debugging
agentfs  # Press Ctrl+C to stop

# 4. Check logs
tail -f .devenv/state/agentfs/*.log  # If logs exist

# 5. Verify port availability
netstat -tuln | grep 8081
```

## Python Integration

### Connection Validation

```python
from nixbox import AgentFSOptions
from agentfs_sdk import AgentFS

async def validate_connection():
    """Check if AgentFS is accessible."""
    try:
        async with await AgentFS.open(AgentFSOptions(id="health-check")) as agent:
            # Perform simple operation
            await agent.fs.write_file("/test.txt", "hello")
            content = await agent.fs.read_file("/test.txt")
            assert content == "hello"
            print("✓ AgentFS connection validated")
            return True
    except Exception as e:
        print(f"✗ AgentFS connection failed: {e}")
        return False
```

### Environment-Aware Configuration

```python
import os
from nixbox import AgentFSOptions

def get_agentfs_options() -> AgentFSOptions:
    """Create AgentFS options from environment."""
    # Check if custom path specified
    custom_path = os.getenv("AGENTFS_CUSTOM_DB_PATH")
    if custom_path:
        return AgentFSOptions(path=custom_path)

    # Use default ID-based approach
    agent_id = os.getenv("AGENTFS_AGENT_ID", "default")
    return AgentFSOptions(id=agent_id)
```

## Error Handling Patterns

### Missing Dependencies

```bash
#!/bin/bash
# check-dependencies.sh

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed"
        echo "Install with: $2"
        exit 1
    fi
}

check_command "nix" "curl -L https://nixos.org/nix/install | sh"
check_command "devenv" "nix profile install nixpkgs#devenv"

echo "✓ All dependencies installed"
```

### Port Conflict Resolution

```bash
# Check if port is in use
PORT=${AGENTFS_PORT:-8081}
if netstat -tuln | grep -q ":$PORT "; then
    echo "Port $PORT is in use"
    echo "Options:"
    echo "  1. Stop the process using port $PORT"
    echo "  2. Use a different port: export AGENTFS_PORT=9090"
    exit 1
fi
```

### Build Failures

```bash
# Clean build artifacts and retry
rm -rf .devenv
devenv shell --rebuild

# If still failing, check Nix cache
nix-collect-garbage
devenv shell --rebuild
```

## Integration Examples

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Nix
        uses: cachix/install-nix-action@v20

      - name: Install devenv
        run: nix profile install nixpkgs#devenv

      - name: Run tests in devenv
        run: |
          devenv shell pytest
```

### Container Build

```dockerfile
# Dockerfile
FROM nixos/nix:latest

WORKDIR /app
COPY . .

RUN nix profile install nixpkgs#devenv
RUN devenv shell --impure  # Build dependencies

CMD ["devenv", "up"]
```

### Automated Setup Script

```bash
#!/bin/bash
# setup-nixbox.sh - Automated environment setup

set -e

echo "Setting up nixbox development environment..."

# Check prerequisites
if ! command -v nix &> /dev/null; then
    echo "Installing Nix..."
    curl -L https://nixos.org/nix/install | sh
    source ~/.nix-profile/etc/profile.d/nix.sh
fi

if ! command -v devenv &> /dev/null; then
    echo "Installing devenv..."
    nix profile install nixpkgs#devenv
fi

# Enter devenv and run tests
echo "Building environment..."
devenv shell pytest

echo "✓ Setup complete!"
echo "To start developing:"
echo "  devenv shell  # Enter environment"
echo "  devenv up     # Start processes"
```

## Best Practices

1. **Use devenv shell for development**: Always work inside the shell for dependency consistency
2. **Start processes with devenv up**: Don't run AgentFS manually unless debugging
3. **Check configuration with agentfs-info**: Verify settings before coding
4. **Use environment variables for config**: Never hardcode ports, paths, etc.
5. **Clean rebuilds occasionally**: Run `rm -rf .devenv && devenv shell` monthly
6. **Document custom variables**: If adding new env vars, update README and AGENT.md
7. **Test in clean environment**: Verify setup works on fresh clone periodically

## Performance Considerations

### Shell Startup Time

- **First time**: 2-5 minutes (builds AgentFS from source)
- **Subsequent**: 5-10 seconds (cached builds)
- **Optimization**: Use `nix-direnv` for automatic activation

### Nix Store Usage

- AgentFS build: ~500MB (Rust dependencies)
- Total store impact: ~1-2GB
- Cleanup: `nix-collect-garbage` to remove old builds

### AgentFS Resource Usage

- Memory: ~50-100MB per instance
- CPU: Minimal when idle
- Disk: SQLite database size (grows with data)

## Related Skills

- `nixbox.filesystem.query` - Query AgentFS after setup
- `nixbox.tool.tracking` - Track operations in AgentFS
- `nixbox.data.migration` - Migrate data between environments

## Version History

- **v0.1.0** (2024-01): Initial skill definition
  - Basic shell entry
  - Process management
  - Configuration validation
  - Health checks
