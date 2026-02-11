# AGENT guidance

This repository provides a comprehensive development environment combining AgentFS filesystem sandboxing with devenv.sh-based environment management and a Python library for programmatic access.

## Mission

Provide a modular, declarative `devenv.sh` setup that:
1. Runs an AgentFS database process for sandboxed filesystem workflows
2. Offers a type-safe Python library (`nixbox`) for programmatic AgentFS interaction
3. Creates reproducible, isolated development environments for LLM code agents

## Architecture Overview

### Core Components

1. **AgentFS Process**: SQLite-backed virtual filesystem providing sandboxed file operations
   - Managed by devenv.sh processes
   - Configurable via environment variables
   - Accessible via HTTP API at `http://localhost:8081` (default)

2. **nixbox Python Library** (`src/nixbox/`):
   - Pydantic-based type-safe models for AgentFS SDK
   - View/Query interface for filesystem operations
   - Models: `AgentFSOptions`, `FileEntry`, `FileStats`, `ToolCall`, `KVEntry`
   - Located at `src/nixbox/` (single package, no nested workspaces)

3. **devenv.sh Configuration** (`devenv.nix`):
   - Declarative environment specification
   - Process management (AgentFS server)
   - Nix-based dependency management
   - Helper scripts for common operations

### Filesystem Sandbox Concept

AgentFS provides an **isolated, queryable filesystem** backed by SQLite:

- **Sandboxing**: All file operations occur in an isolated virtual filesystem, preventing accidental modification of host files
- **Persistence**: Files are stored in `.devenv/state/agentfs/sandbox.db` by default
- **Queryability**: Use the `View` class to query files by patterns, size, content, or custom predicates
- **Type Safety**: Pydantic models ensure validated, structured access to filesystem metadata

This enables LLM agents to:
- Read/write files without host filesystem risk
- Query file collections programmatically
- Track tool/function calls with metadata
- Store key-value configuration data

## Editing Rules

When modifying this repository:

1. **Prefer devenv.sh constructs**: Use `env`, `packages`, `processes`, `scripts`, `imports`
2. **Parameterize runtime behavior**: All runtime configuration via environment variables
3. **Avoid absolute paths**: Use `${root}` or relative paths; no host-specific hardcoding
4. **Modular design**: Keep `devenv.nix` ready for extraction into importable modules
5. **Documentation sync**: Update README when variables/commands change
6. **Single package structure**: All Python code in `src/nixbox/`, single `pyproject.toml` at root
7. **Type safety first**: Use Pydantic models for all AgentFS interactions

## Process Contract

`processes.agentfs.exec` is the **single source of truth** for launching the AgentFS runtime.

All AgentFS process configuration must flow through:
- Environment variables (`AGENTFS_*`)
- The `agentfsServe` expression in `devenv.nix`
- The `scripts.agentfs.exec` command for manual invocation

## Development Workflows

### Working with AgentFS

1. **Start the environment**:
   ```bash
   devenv shell  # Enter development shell
   devenv up     # Start background processes (including AgentFS)
   ```

2. **Check AgentFS status**:
   ```bash
   agentfs-info  # Show configuration
   agentfs-url   # Print base URL
   ```

3. **Use the Python library**:
   ```python
   from nixbox import AgentFSOptions, View, ViewQuery
   from agentfs_sdk import AgentFS

   # Open connection
   async with await AgentFS.open(AgentFSOptions(id="my-agent")) as agent:
       # Query files
       view = View(agent=agent, query=ViewQuery(path_pattern="*.py"))
       files = await view.load()
   ```

### Configuration Model

Environment variables (all with `lib.mkDefault`):

| Variable              | Default                          | Purpose                          |
|-----------------------|----------------------------------|----------------------------------|
| `AGENTFS_ENABLED`     | `1`                              | Enable/disable AgentFS process   |
| `AGENTFS_HOST`        | `127.0.0.1`                      | Server bind address              |
| `AGENTFS_PORT`        | `8081`                           | Server port                      |
| `AGENTFS_DATA_DIR`    | `${root}/.devenv/state/agentfs`  | SQLite database directory        |
| `AGENTFS_DB_NAME`     | `sandbox`                        | Database name                    |
| `AGENTFS_LOG_LEVEL`   | `info`                           | Logging verbosity                |
| `AGENTFS_EXTRA_ARGS`  | `""`                             | Additional CLI arguments         |
| `VENDOR_PATH`         | `$HOME/vendor`                   | Source directory for vendoring   |

### Helper Scripts

Available commands in devenv shell:

- `agentfs-info`: Display current AgentFS configuration
- `agentfs-url`: Print the AgentFS base URL
- `agentfs-cli`: Run the upstream agentfs CLI with arguments
- `agentfs`: Run AgentFS server in foreground
- `link-abs-to-repo <name>`: Symlink `$VENDOR_PATH/<name>` to `.devenv/store/vendor/<name>`
- `link-agentfs`: Convenience wrapper for `link-abs-to-repo agentfs`

### Vendoring Upstream AgentFS

To vendor the AgentFS source for local development:

```bash
# Set custom vendor path (optional)
export VENDOR_PATH=/path/to/vendor

# Create symlink
link-agentfs
```

This links `$VENDOR_PATH/agentfs` → `.devenv/store/vendor/agentfs`, which is used by the Nix build.

## Python Library (`nixbox`)

### Installation

```bash
# Development installation
uv pip install -e .

# With dev dependencies
uv pip install -e ".[dev]"
```

### Core Models

- **`AgentFSOptions`**: Connection options (id or path)
- **`FileEntry`**: File path + stats + optional content
- **`FileStats`**: Size, mtime, is_file, is_directory
- **`ViewQuery`**: Query specification (patterns, filters, size constraints)
- **`View`**: Async filesystem query engine
- **`ToolCall`**: Tool/function call tracking with parameters, results, status
- **`KVEntry`**: Key-value store entry

### Query Patterns

```python
# Glob patterns
query = ViewQuery(path_pattern="*.py", recursive=True)

# Regex filtering
query = ViewQuery(regex_pattern=r"^/src/.*\.py$")

# Size filters
query = ViewQuery(min_size=1024, max_size=1048576)

# Content loading
query = ViewQuery(include_content=True)

# Fluent API
files = await (
    View(agent=agent)
    .with_pattern("**/*.json")
    .with_content(True)
    .load()
)

# Custom predicates
today_files = await view.filter(
    lambda f: f.stats and f.stats.mtime.date() == datetime.now().date()
)
```

## Testing

```bash
# Run tests
pytest

# Run with coverage
pytest --cov=nixbox --cov-report=term-missing

# Run examples
uv run examples/basic_usage.py
```

## File Structure

```
nixbox/
├── devenv.nix              # Main devenv configuration
├── devenv.yaml             # Input sources (nixpkgs, fenix)
├── pyproject.toml          # Single Python package config
├── README.md               # Main documentation
├── AGENT.md                # This file
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
└── scripts/                # Helper utilities
    └── link_abs_to_repo.py # Symlink management

Deprecated (to be removed):
└── agentfs-pydantic/       # Old nested package structure
```

## Design Principles

1. **Declarative over imperative**: Use Nix expressions, not shell scripts
2. **Parameterized configuration**: All settings via environment variables
3. **Type safety**: Pydantic models for all data structures
4. **Async-first**: All filesystem operations use async/await
5. **Modular**: Each component (process, library, scripts) is independently useful
6. **Reproducible**: Nix ensures identical environments across machines
7. **Sandboxed**: AgentFS isolates filesystem operations from host
8. **Queryable**: View interface provides powerful file querying capabilities

## Common Patterns for LLM Agents

### Pattern 1: Environment Introspection

```python
from nixbox import AgentFSOptions, View, ViewQuery
from agentfs_sdk import AgentFS

async def analyze_codebase():
    async with await AgentFS.open(AgentFSOptions(id="analyzer")) as agent:
        # Find all Python files
        view = View(agent=agent, query=ViewQuery(
            path_pattern="**/*.py",
            include_content=True
        ))
        files = await view.load()

        # Analyze imports, structure, etc.
        for file in files:
            analyze_file(file.path, file.content)
```

### Pattern 2: Incremental File Processing

```python
async def process_large_files_incrementally():
    async with await AgentFS.open(AgentFSOptions(id="processor")) as agent:
        # First, count files without loading content
        view = View(agent=agent, query=ViewQuery(path_pattern="**/*.txt"))
        total = await view.count()

        # Then load and process in batches
        small_files = await view.filter(lambda f: f.stats.size < 10_000)
        for file in small_files:
            # Process small files
            pass
```

### Pattern 3: Tool Call Tracking

```python
from nixbox import ToolCall
from datetime import datetime

def track_tool_execution(name: str, params: dict):
    call = ToolCall(
        id=generate_id(),
        name=name,
        parameters=params,
        status="pending",
        started_at=datetime.now()
    )
    # Execute tool, then update:
    call.status = "success"
    call.result = {"output": "..."}
    call.completed_at = datetime.now()
    # Store in AgentFS for persistence
```

## Integration with devenv.sh

This repository demonstrates devenv.sh module patterns:

- **Process management**: `processes.agentfs` runs AgentFS as a managed service
- **Environment setup**: `env.*` variables configure runtime behavior
- **Package provisioning**: `packages` ensures dependencies are available
- **Shell initialization**: `enterShell` provides welcome message and context
- **Script helpers**: `scripts.*` expose reusable commands

These patterns can be extracted into separate Nix modules and imported:

```nix
# In another project's devenv.nix
{ inputs, ... }:
{
  imports = [
    inputs.nixbox.devenvModules.agentfs
  ];

  env.AGENTFS_PORT = "9090";  # Override defaults
}
```

## Future Enhancements

Potential improvements for consideration:

1. **Streaming responses**: Support for large file content streaming
2. **Caching layer**: In-memory cache for frequently accessed files
3. **Watch mode**: File change notifications for reactive workflows
4. **Multi-database**: Support for multiple AgentFS instances simultaneously
5. **Export utilities**: Export AgentFS data to zip/tar archives
6. **Import utilities**: Seed AgentFS from existing directories
7. **Query optimization**: Indexed search for faster pattern matching
8. **SKILL.md documents**: Formalized agent skill definitions (see next section)

## SKILL.md Documents

To be created - formalized skill definitions for common agent workflows. These will provide:

- Clear capability boundaries
- Input/output contracts
- Error handling patterns
- Integration examples
- Performance considerations

See the `SKILL.md` files in this repository for specific agent workflow guidance.
