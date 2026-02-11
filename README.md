# nixbox

**nixbox** is a comprehensive development environment combining:
- **devenv.sh modular plugin** for running a local [AgentFS](https://docs.turso.tech/agentfs/introduction) database process
- **Python library** (`nixbox`) providing type-safe Pydantic models and query interface for AgentFS SDK

This creates reproducible, sandboxed development environments for LLM code agents and Python applications.

## Features

### DevOps Features
- 🔧 Configurable `agentfs` process managed by devenv.sh
- 🌍 Environment variables for all runtime configuration
- 📦 Nix-based dependency management with reproducible builds
- 🚀 Helper scripts for AgentFS inspection and connection
- 🔌 Modular design ready for extraction into reusable modules

### Python Library Features
- 🎯 **Type-safe models** - Pydantic models for all core AgentFS objects
- 🔍 **Query interface** - Powerful `View` system for querying filesystem with filters
- ✅ **Validation** - Automatic validation of options and data structures
- 🚀 **Async-first** - Built on async/await for optimal performance
- 📦 **Minimal dependencies** - Only requires `pydantic` and `agentfs-sdk`

## Quick Start

### 1. Enter the Development Environment

```bash
# Clone the repository
git clone <repo-url>
cd nixbox

# Enter devenv shell (builds dependencies)
devenv shell
```

### 2. Start AgentFS Process

```bash
# Start background processes
devenv up

# Or run in foreground for debugging
agentfs
```

### 3. Verify Configuration

```bash
# Display current configuration
agentfs-info

# Get AgentFS URL
agentfs-url  # http://127.0.0.1:8081
```

### 4. Use the Python Library

```bash
# Install library for development
uv pip install -e .

# Run example
uv run examples/basic_usage.py
```

## Python Library Usage

```python
import asyncio
from agentfs_sdk import AgentFS
from nixbox import AgentFSOptions, View, ViewQuery

async def main():
    # Create validated options
    options = AgentFSOptions(id="my-agent")

    async with await AgentFS.open(options.model_dump()) as agent:
        # Create some files
        await agent.fs.write_file("/notes/todo.txt", "Task 1\nTask 2")
        await agent.fs.write_file("/config/settings.json", '{"theme": "dark"}')

        # Query filesystem
        view = View(
            agent=agent,
            query=ViewQuery(
                path_pattern="**/*.txt",
                recursive=True,
                include_content=True
            )
        )

        # Load matching files
        files = await view.load()
        for file in files:
            print(f"{file.path}: {file.stats.size} bytes")
            if file.content:
                print(f"Content: {file.content}")

asyncio.run(main())
```

## Configuration Model

All configuration is done through standard devenv functionality (`env`, `packages`, `processes`, `scripts`):

| Variable              | Default                          | Purpose                          |
|-----------------------|----------------------------------|----------------------------------|
| `AGENTFS_ENABLED`     | `1`                              | Toggle process startup (1 = enabled, 0 = disabled) |
| `AGENTFS_HOST`        | `127.0.0.1`                      | Bind host for the AgentFS process |
| `AGENTFS_PORT`        | `8081`                           | Bind port for the AgentFS process |
| `AGENTFS_DATA_DIR`    | `.devenv/state/agentfs`          | Persistent local data directory  |
| `AGENTFS_DB_NAME`     | `sandbox`                        | Logical database name for sandboxing |
| `AGENTFS_LOG_LEVEL`   | `info`                           | Log level (debug, info, warn, error) |
| `AGENTFS_EXTRA_ARGS`  | `""`                             | Additional runtime flags         |
| `VENDOR_PATH`         | `$HOME/vendor`                   | Source directory for vendoring   |

## Python Library API

### Core Models

#### AgentFSOptions
```python
from nixbox import AgentFSOptions

# By agent ID (creates .agentfs/{id}.db)
options = AgentFSOptions(id="my-agent")

# By custom path
options = AgentFSOptions(path="./data/mydb.db")
```

#### FileEntry & FileStats
```python
from nixbox import FileEntry, FileStats
from datetime import datetime

entry = FileEntry(
    path="/notes/todo.txt",
    stats=FileStats(
        size=1024,
        mtime=datetime.now(),
        is_file=True,
        is_directory=False
    ),
    content="Task 1\nTask 2"
)
```

#### ToolCall & ToolCallStats
```python
from nixbox import ToolCall, ToolCallStats

call = ToolCall(
    id=1,
    name="search",
    parameters={"query": "Python"},
    result={"results": ["result1", "result2"]},
    status="success",
    started_at=datetime.now(),
    completed_at=datetime.now()
)

stats = ToolCallStats(
    name="search",
    total_calls=100,
    successful=95,
    failed=5,
    avg_duration_ms=123.45
)
```

### View Query System

Query files with powerful filtering options:

```python
from nixbox import View, ViewQuery

# Basic pattern matching
view = View(agent=agent, query=ViewQuery(
    path_pattern="**/*.py",
    recursive=True
))
python_files = await view.load()

# Size filtering
large_files = View(agent=agent, query=ViewQuery(
    path_pattern="**/*",
    min_size=1_048_576  # 1MB
))

# Regex patterns
view = View(agent=agent, query=ViewQuery(
    path_pattern="**/*",
    regex_pattern=r"^/src/.*\.(ts|tsx)$"
))

# Fluent API
json_files = await (
    View(agent=agent)
    .with_pattern("**/*.json")
    .with_content(True)
    .load()
)

# Custom predicates
from datetime import datetime
today = datetime.now().date()
recent = await view.filter(
    lambda f: f.stats and f.stats.mtime.date() == today
)

# Efficient counting
count = await view.count()
```

### ViewQuery Options

| Option            | Type            | Default | Description                              |
|-------------------|-----------------|---------|------------------------------------------|
| `path_pattern`    | `str`           | `"*"`   | Glob pattern for matching file paths     |
| `recursive`       | `bool`          | `True`  | Search recursively in subdirectories     |
| `include_content` | `bool`          | `False` | Load file contents                       |
| `include_stats`   | `bool`          | `True`  | Include file statistics                  |
| `regex_pattern`   | `Optional[str]` | `None`  | Additional regex pattern for matching    |
| `max_size`        | `Optional[int]` | `None`  | Maximum file size in bytes               |
| `min_size`        | `Optional[int]` | `None`  | Minimum file size in bytes               |

## Helper Commands

Available in devenv shell:

- `agentfs-info` - Display current AgentFS configuration
- `agentfs-url` - Print the AgentFS base URL
- `agentfs-cli` - Run the upstream agentfs CLI with arguments
- `agentfs` - Run AgentFS server in foreground
- `link-abs-to-repo <name>` - Symlink `$VENDOR_PATH/<name>` to `.devenv/store/vendor/<name>`
- `link-agentfs` - Convenience wrapper for `link-abs-to-repo agentfs`

## Development

### Testing

```bash
# Run tests
pytest

# Run with coverage
pytest --cov=nixbox --cov-report=term-missing

# Run examples
uv run examples/basic_usage.py
```

### Project Structure

```
nixbox/
├── devenv.nix              # Main devenv configuration
├── devenv.yaml             # Input sources (nixpkgs, fenix)
├── pyproject.toml          # Python package configuration
├── README.md               # This file
├── AGENT.md                # Agent guidance & architecture docs
├── src/nixbox/             # Python library source
│   ├── __init__.py         # Public API exports
│   ├── models.py           # Pydantic data models
│   ├── view.py             # View query interface
│   └── py.typed            # PEP 561 type marker
├── tests/                  # Test suite
│   ├── conftest.py         # pytest fixtures
│   └── test_models.py      # Model tests
├── examples/               # Usage examples
│   └── basic_usage.py      # Comprehensive examples
├── skills/                 # LLM agent skill definitions
│   ├── FILESYSTEM_QUERY_SKILL.md
│   ├── ENVIRONMENT_SETUP_SKILL.md
│   └── TOOL_TRACKING_SKILL.md
└── scripts/                # Helper utilities
    └── link_abs_to_repo.py # Symlink management
```

## Module Usage Pattern

You can extract this into reusable modules by moving the AgentFS configuration into
`modules/agentfs.nix` and importing it from your own `devenv.nix`:

```nix
{
  imports = [ ./modules/agentfs.nix ];

  # Override defaults
  env.AGENTFS_PORT = "9090";
}
```

## Advanced Usage

### Custom Configuration

```bash
# Use custom port
export AGENTFS_PORT=9090
devenv shell

# Disable AgentFS process
export AGENTFS_ENABLED=0
devenv shell

# Custom vendor path
export VENDOR_PATH=/path/to/vendor
link-agentfs
```

### Vendoring AgentFS Source

To use a local AgentFS source for development:

```bash
# Set vendor path (optional)
export VENDOR_PATH=/path/to/vendor

# Link AgentFS source
link-agentfs

# The build will now use .devenv/store/vendor/agentfs
```

### Pattern Matching

#### Glob Patterns
- `*` - Match any characters except `/`
- `**` - Match any characters including `/` (recursive)
- `?` - Match single character
- `[abc]` - Match any character in brackets

Examples:
- `*.py` - All Python files in current directory
- `**/*.py` - All Python files recursively
- `/data/**/*.json` - All JSON files under /data
- `test_*.py` - Files starting with "test_"

#### Regex Patterns
```python
view = View(agent=agent, query=ViewQuery(
    path_pattern="*",
    regex_pattern=r"^/src/.*\.(py|pyx)$"  # Python/Cython in /src
))
```

## Requirements

### System Requirements
- Nix package manager
- devenv CLI (`nix profile install nixpkgs#devenv`)

### Python Requirements
- Python >= 3.11
- pydantic >= 2.0.0
- agentfs-sdk >= 0.1.0

## Documentation

- [AGENT.md](./AGENT.md) - Comprehensive architecture and agent guidance
- [skills/](./skills/) - LLM agent skill definitions with usage patterns
- [AgentFS Documentation](https://docs.turso.tech/agentfs)
- [AgentFS Python SDK](https://docs.turso.tech/agentfs/python-sdk)

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Notes

- `devenv.nix` builds AgentFS from source using the Fenix Rust toolchain
- The template expects Turso CLI with AgentFS subcommand support
- All runtime configuration is parameterized via environment variables
- The Python library is sandboxed - all file operations occur in AgentFS, not the host filesystem
