# Chimera MVP - Minimal Implementation

An absolutely minimal implementation of the Chimera shared-state agentic workspace.

## Architecture

This implementation follows the "Unix-first" principle:
- **No FUSE mounts** - Direct AgentFS SDK usage
- **No custom filesystems** - Just SQLite + inotify
- **No complex IPC** - File-based signals
- **No containers** - Monty provides sandboxing
- **Single process** - Python asyncio

See [mvp_architecture.md](mvp_architecture.md) for full design details.

## Quick Start

### 1. Setup Environment

```bash
# Enter development environment (NixOS + devenv)
devenv shell

# Pull the LLM model
pull-model

# Initialize stable layer from current project
init-stable
```

### 2. Run Chimera

```bash
# Start the orchestrator
chimera
```

This will:
- Initialize `.agentfs/stable.db` from your project
- Watch for file changes and sync to stable layer
- Spawn test agentlets
- Listen for accept/reject signals

### 3. Setup Neovim Plugin

Add to your Neovim config:

```lua
-- In ~/.config/nvim/init.lua or lua/plugins/chimera.lua
require('chimera').setup()
```

Copy `chimera.lua` to your Neovim runtime path:

```bash
mkdir -p ~/.config/nvim/lua
cp chimera.lua ~/.config/nvim/lua/
```

### 4. Use It

1. Edit a file in your project
2. Save it (syncs to stable layer)
3. Wait for agentlets to suggest changes
4. Ghost text appears inline
5. Press `<Leader>a` to accept or `<Leader>r` to reject

## File Structure

```
.
├── .agentfs/
│   ├── stable.db          # Your ground truth
│   ├── agent-abc123.db    # Agentlet overlays
│   └── bin.db             # GC tracker
├── ~/.chimera/
│   ├── previews/          # Diff files for ghost text
│   │   └── agent-abc123.diff
│   └── signals/           # Accept/reject signals
│       ├── accept-abc123
│       └── reject-abc123
├── chimera.py             # Main orchestrator
├── chimera.lua            # Neovim plugin
├── init_stable.py         # Initialize stable layer
├── devenv.nix             # NixOS configuration
└── pyproject.toml         # Python dependencies
```

## How It Works

### Stable Layer

The stable layer is your project's ground truth stored in `.agentfs/stable.db`:

```python
stable = await AgentFS.open(AgentFSOptions(id="stable"))
```

Any changes you make to files are automatically synced via file watcher:

```python
async for changes in awatch(project_root):
    await stable.fs.write_file(path, content)
```

### Agentlets

Each agentlet gets its own AgentFS database:

```python
agent_fs = await AgentFS.open(AgentFSOptions(id=f"agent-{uuid}"))
```

Reads fall through to stable layer automatically:

```python
# Agentlet reads a file
content = await agent_fs.fs.read_file("main.py")
# → Checks agent.db first, falls back to stable.db
```

Writes go only to the agent's overlay:

```python
# Agentlet writes a file
await agent_fs.fs.write_file("main.py", new_content)
# → Only writes to agent.db, stable.db untouched
```

### Monty Sandbox

Agent code runs in a restricted Python interpreter:

```python
# What the LLM generates
content = read_file("main.py")  # External function
new_content = ask_llm("Add docstrings", content)  # External function
write_file("main.py", new_content)  # External function
submit_result("Added docstrings", ["main.py"])  # External function
```

The orchestrator provides these functions:

```python
external_funcs = {
    "read_file": lambda path: agent_fs.fs.read_file(path),
    "write_file": lambda path, content: agent_fs.fs.write_file(path, content),
    "ask_llm": lambda prompt, ctx: call_ollama(prompt, ctx),
    # ...
}
```

### Ghost Text

The orchestrator generates diffs:

```python
# Compare stable.db and agent.db
diff = generate_diff(stable, agent_fs, file_path)

# Write to preview file
preview_path = f"~/.chimera/previews/{agent_id}.diff"
preview_path.write_text(diff)
```

Neovim polls these files:

```lua
-- Every 500ms
local diff_content = read_preview(agent_id)
local changes = parse_diff(diff_content)
show_ghost_text(bufnr, changes)
```

### Accept/Reject

User presses `<Leader>a`:

```lua
-- Neovim writes signal file
io.open("~/.chimera/signals/accept-{agent_id}", "w"):close()
```

Orchestrator polls signals:

```python
for signal_file in signals_dir.glob("accept-*"):
    agent_id = extract_id(signal_file)
    await accept_agentlet(agent_id)
```

Accept merges changes:

```python
async def accept_agentlet(agent_id):
    # Copy files from agent.db to stable.db
    for path in changed_files:
        content = await agent_fs.fs.read_file(path)
        await stable.fs.write_file(path, content)

    # Clean up
    await trash_agentlet(agent_id)
```

## External Functions Available to Agents

Agents can call these functions from their Monty code:

- `read_file(path: str) -> str` - Read a file (overlay-aware)
- `write_file(path: str, content: str) -> bool` - Write a file
- `list_dir(path: str) -> list[str]` - List directory
- `search_files(pattern: str) -> list[str]` - Search (via ripgrep)
- `ask_llm(prompt: str, context: str) -> str` - Query LLM
- `submit_result(summary: str, files: list[str]) -> bool` - Submit
- `log(message: str) -> bool` - Debug logging

## Example Agent Code

This is what the LLM generates and Monty executes:

```python
# Get list of Python files
files = search_files("*.py")

for file_path in files:
    # Read the file
    content = read_file(file_path)

    # Check if it needs docstrings
    if "def " in content and '"""' not in content:
        # Ask LLM to add docstrings
        new_content = ask_llm(
            f"Add docstrings to all functions in this file",
            content
        )

        # Write the modified content
        write_file(file_path, new_content)
        log(f"Added docstrings to {file_path}")

# Submit the results
submit_result(
    "Added docstrings to functions",
    files
)
```

## Dependencies

### Runtime
- Python 3.11+
- SQLite 3.35+
- Ollama (for LLM)

### Python Packages
- agentfs-sdk - Filesystem layer
- pydantic-monty - Sandboxed execution
- httpx - HTTP client for Ollama
- watchfiles - File watching

### System Tools
- inotify-tools - File monitoring (Linux)
- ripgrep - Fast searching (optional)
- tree - Directory visualization (optional)

## Limitations

This is a minimal MVP:

❌ No FUSE mounts
❌ No multi-machine support
❌ No CRDT merging
❌ No sophisticated conflict detection
❌ No test execution
❌ No persistent agent sessions
❌ Single developer only

## Next Steps

After getting the MVP working:

1. **Test interaction model** - Is ghost text useful?
2. **Evaluate agent quality** - Can 7B models generate good code?
3. **Measure latency** - Is end-to-end <5s achievable?
4. **Identify pain points** - What's missing?
5. **Iterate** - Add features based on actual usage

## Security

Monty provides the sandbox:
- No `import` statements
- No filesystem access except external functions
- No network access
- Time and memory limits
- No `open()`, `exec()`, `eval()`

Worst case: Agent wastes CPU and generates garbage. Can't damage your project.

## License

MIT
