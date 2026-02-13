# AgentFS Chimera: Minimal MVP Architecture

## Core Insight: Skip the FUSE Layer (For Now)

The concept document assumes FUSE mounts for everything, but for an MVP, we can work directly with AgentFS SQLite databases and UNIX tools. This dramatically simplifies the implementation.

## System Components

### 1. The Stable Layer
**What:** A single AgentFS database representing the human's ground truth.

**Implementation:**
```bash
# Just a SQLite file
.agentfs/stable.db
```

**Operations:**
- Human edits files via normal filesystem
- On save, a watcher syncs changes into stable.db via AgentFS SDK
- No FUSE mount needed - just inotify + AgentFS.fs.write_file()

### 2. Agentlet Sandboxes
**What:** Individual AgentFS databases, one per agentlet.

**Implementation:**
```bash
.agentfs/agent-{uuid}.db  # Each agentlet gets its own DB
```

**Key insight:** AgentFS already supports overlay semantics via the SDK. We don't need FUSE overlays - we can:
1. Read from stable.db when the file doesn't exist in agent.db
2. Write to agent.db (never touches stable.db)
3. Use whiteouts table for deletions

**Operations:**
```python
# Agentlet reads a file
content = await agent_fs.fs.read_file(path)
# Falls through to stable layer automatically via SDK

# Agentlet writes a file
await agent_fs.fs.write_file(path, new_content)
# Writes only to agent.db
```

### 3. The Orchestrator
**What:** Single Python asyncio process managing everything.

**Implementation:**
```python
# chimera.py - the entire orchestrator in one file
```

**Responsibilities:**
- Spawn agentlets (create new AgentFS database)
- Generate agent code via Ollama
- Run agent code in Monty sandbox
- Provide external functions to Monty (read_file, write_file, ask_llm, etc.)
- Collect results in agent's kv_store
- Watch for accept/reject signals
- Garbage collect dead agentlets

### 4. Monty Runtime
**What:** Sandboxed Python interpreter for running agent code.

**Implementation:**
Use pydantic-monty directly - no modifications needed.

**Agent Code Pattern:**
```python
# What the LLM generates - runs in Monty
task = get_task()  # External function
files = search_files("*.py")  # External function

for file in files:
    content = read_file(file)  # External function
    if "TODO" in content:
        new_content = ask_llm(f"Add docstrings to {file}", content)
        write_file(file, new_content)  # External function

submit_result("Added docstrings", files)  # External function
```

## UNIX Primitives Leveraged

### File Watching (inotify)
```bash
# Watch project directory for changes
inotifywait -m -r -e modify,create,delete /path/to/project
```

Human edits → inotify event → sync to stable.db

### Process Management
```bash
# Just Python asyncio, no containers
asyncio.create_task(run_agentlet(agent_id))
```

### File-Based IPC (Simple)
```bash
# Accept/reject signals
~/.chimera/signals/accept-{agent-id}  # Touch to accept
~/.chimera/signals/reject-{agent-id}  # Touch to reject
```

Orchestrator polls these files. Neovim writes them.

### Diffing (for Ghost Text)
```bash
# Generate diff between stable and agent overlay
diff -u <(sqlite3 stable.db "SELECT content FROM...") \
        <(sqlite3 agent-123.db "SELECT content FROM...")
```

Or use Python difflib - same idea.

### Text Processing
```bash
# Agent uses standard UNIX tools via subprocess
grep -r "TODO" .
find . -name "*.py"
```

These become external functions in Monty.

## Data Flow

```
┌─────────────────────────────────────────────────────┐
│ Human edits file in Neovim                          │
│ ↓                                                   │
│ inotify detects change                              │
│ ↓                                                   │
│ Orchestrator: await stable.fs.write_file(path, ...) │
│ ↓                                                   │
│ stable.db updated                                   │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Orchestrator spawns agentlet                        │
│ ↓                                                   │
│ Creates agent-{uuid}.db via AgentFS.open()          │
│ ↓                                                   │
│ Generates Python code via Ollama                    │
│ ↓                                                   │
│ Runs code in Monty with external functions          │
│ ↓                                                   │
│ Agentlet reads from agent.db (falls through to      │
│ stable.db via SDK overlay logic)                    │
│ ↓                                                   │
│ Agentlet writes to agent.db only                    │
│ ↓                                                   │
│ Calls submit_result(summary, files)                 │
│ ↓                                                   │
│ Orchestrator stores result in agent.kv              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Orchestrator generates ghost text                   │
│ ↓                                                   │
│ Diff between stable.db and agent.db                 │
│ ↓                                                   │
│ Write diff to ~/.chimera/previews/{agent-id}.diff   │
│ ↓                                                   │
│ Neovim plugin polls this file                       │
│ ↓                                                   │
│ Shows inline ghost text                             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Human presses <Leader>a in Neovim                   │
│ ↓                                                   │
│ Writes ~/.chimera/signals/accept-{agent-id}         │
│ ↓                                                   │
│ Orchestrator detects signal file                    │
│ ↓                                                   │
│ Copies files from agent.db to stable.db             │
│ ↓                                                   │
│ Deletes agent-{uuid}.db                             │
│ ↓                                                   │
│ Deletes signal file                                 │
└─────────────────────────────────────────────────────┘
```

## Minimal File Structure

```
project/
├── .agentfs/
│   ├── stable.db           # Human's ground truth
│   ├── agent-001.db        # Agentlet 1's overlay
│   ├── agent-002.db        # Agentlet 2's overlay
│   └── bin.db              # Garbage collection tracker
├── ~/.chimera/
│   ├── previews/           # Diffs for ghost text
│   │   ├── agent-001.diff
│   │   └── agent-002.diff
│   └── signals/            # Accept/reject signals
│       ├── accept-001
│       └── reject-002
├── chimera.py              # The orchestrator (single file)
└── src/                    # Actual project files
    └── main.py
```

## External Functions for Monty

These are the ONLY operations an agentlet can perform:

```python
# File operations (maps to AgentFS SDK)
read_file(path: str) -> str
write_file(path: str, content: str) -> bool
list_dir(path: str) -> list[str]
file_exists(path: str) -> bool

# Context gathering (UNIX tools via subprocess)
search_files(pattern: str) -> list[str]  # Uses grep
get_file_tree() -> str                   # Uses find or tree

# LLM access (HTTP to Ollama)
ask_llm(prompt: str, context: str) -> str

# Output
submit_result(summary: str, changed_files: list[str]) -> bool
log(message: str) -> bool  # Writes to agent.tools table
```

## What We're NOT Building (Yet)

❌ FUSE mounts - Use AgentFS SDK directly
❌ OverlayFS - AgentFS handles this in SQLite
❌ Complex Neovim plugins - Just file polling
❌ Distributed agents - Single machine only
❌ CRDTs - Just "pile" model (last write wins)
❌ Sophisticated conflict detection
❌ Real test execution - Mock it with placeholders
❌ Multi-user - Single developer only

## MVP Feature Set

### Phase 1: Core Loop (1-2 days)
✅ Create stable.db from existing project
✅ Spawn one agentlet with its own .db
✅ Generate simple Python code via Ollama
✅ Run code in Monty with external functions
✅ Store result in agent's kv_store
✅ Accept change manually (copy files from agent.db to stable.db)

### Phase 2: Basic UI (1 day)
✅ inotify watcher for project files → stable.db
✅ Simple Neovim Lua plugin (50 lines):
  - Poll ~/.chimera/previews/*.diff
  - Show as virtual text / floating window
  - <Leader>a writes accept signal
  - <Leader>r writes reject signal
✅ Orchestrator polls signal files

### Phase 3: Multi-Agent (1 day)
✅ Spawn 3 agentlets concurrently
✅ Track them in bin.db kv_store
✅ Garbage collect on reject/timeout
✅ Simple task queue (list in stable.kv)

## Technology Stack

### Core
- **Python 3.11+** - Orchestrator runtime
- **asyncio** - Concurrency (no threads)
- **pydantic-monty** - Sandboxed execution
- **agentfs-sdk** - Storage layer
- **httpx** - Ollama API calls

### UNIX Tools
- **inotify-tools** (inotifywait) - File watching
- **grep/find** - Search operations
- **diff/difflib** - Change detection
- **SQLite** - Via AgentFS, no raw SQL

### Neovim
- **Lua** - Minimal plugin
- **vim.fn.readfile()** - Poll preview files
- **vim.api.nvim_buf_set_extmark()** - Ghost text

### LLM
- **Ollama** - Local model server
- **qwen2.5-coder:7b** - Fast, code-focused

## NixOS/devenv.sh Configuration

```nix
{ pkgs, ... }: {
  packages = [
    pkgs.python311
    pkgs.uv
    pkgs.inotify-tools
    pkgs.sqlite
    pkgs.tree
    pkgs.ripgrep
    pkgs.fd
    pkgs.ollama
  ];

  languages.python = {
    enable = true;
    version = "3.11";
  };

  processes = {
    ollama.exec = "ollama serve";
  };

  scripts = {
    chimera.exec = "uv run chimera.py";
    pull-model.exec = "ollama pull qwen2.5-coder:7b";
  };
}
```

## Why This Is Minimal

1. **No FUSE complexity** - AgentFS SDK handles overlay logic in SQLite
2. **No custom FS** - Just SQLite + inotify
3. **No complex IPC** - Touch files in ~/.chimera/signals/
4. **No containers** - Monty is the sandbox
5. **No networking** - Ollama on localhost
6. **No persistence** - Agentlets are ephemeral
7. **No state machine** - Simple task queue
8. **Single process** - Python asyncio only

## Critical Dependencies

All dependencies are pure Python or UNIX standard:

```toml
# pyproject.toml
[project]
dependencies = [
    "agentfs-sdk>=0.6.0",
    "pydantic-monty>=0.1.0",
    "httpx>=0.27.0",
    "watchfiles>=0.21.0",  # Better than raw inotify
]
```

## What Makes This Work

1. **AgentFS SDK already implements overlay semantics** - We don't need to reinvent it
2. **Monty already implements sandboxing** - We don't need containers
3. **SQLite is fast** - Read/write operations are sub-millisecond
4. **File-based IPC is simple** - No sockets, no pipes, just touch/poll
5. **UNIX tools are powerful** - grep, find, diff are better than reinventing

## Next Steps

1. Implement `chimera.py` orchestrator (~300 lines)
2. Implement Monty external functions (~100 lines)
3. Write minimal Neovim plugin (~50 lines Lua)
4. Test with single agentlet
5. Test with 3 concurrent agentlets
6. Iterate on agent code generation prompts
7. Evaluate if this interaction model is actually useful

## Success Criteria

The MVP succeeds if:
- Human can edit file
- Change syncs to stable.db
- Agentlet spawns and makes a useful change
- Ghost text appears in Neovim
- Human can accept the change with <Leader>a
- Change merges into stable.db
- Human can see the result immediately

All in <5 seconds end-to-end.
