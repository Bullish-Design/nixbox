# Cairn Technical Specification

Version: 1.0 (MVP)
Status: Stage 3 Implemented (Orchestration Core complete)
Updated: 2026-02-13

## Overview

Cairn is an agentic development environment built on three layers:

1. **Storage Layer** - AgentFS (SQLite-based filesystem with overlays)
2. **Execution Layer** - Monty (sandboxed Python interpreter)
3. **Orchestration Layer** - Cairn Orchestrator (Python asyncio process)

This specification defines the interfaces, data flows, and guarantees of each layer.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Developer                             │
│                    (Neovim + TMUX)                           │
└────────────┬──────────────────────────────┬─────────────────┘
             │                               │
             ↓                               ↓
    ┌────────────────┐              ┌────────────────┐
    │ Stable Neovim  │              │ Preview Neovim │
    │                │              │                │
    │ Editing        │              │ Testing        │
    │ ~/.cairn/      │←── signals ─→│ agent workspace│
    └────────┬───────┘              └────────┬───────┘
             │                               │
             ↓                               ↓
    ┌────────────────────────────────────────────────┐
    │          Cairn Orchestrator (Python)           │
    │  ┌──────────┬──────────┬──────────┬─────────┐ │
    │  │ Watcher  │ Spawner  │ Executor │   GC    │ │
    │  └──────────┴──────────┴──────────┴─────────┘ │
    └──────┬──────────────────────────────┬─────────┘
           │                               │
           ↓                               ↓
    ┌────────────────┐              ┌────────────────┐
    │   AgentFS      │              │  Monty         │
    │   (Storage)    │              │  (Sandbox)     │
    └────────────────┘              └────────────────┘
           │                               │
           ↓                               ↓
    ┌─────────────────────────────────────────────┐
    │          .agentfs/ SQLite DBs               │
    │  stable.db  agent-*.db  bin.db              │
    └─────────────────────────────────────────────┘
```

## Storage Layer: AgentFS

### Schema

AgentFS provides three tables (per the AgentFS spec):

1. **tool_calls** - Audit log of tool invocations
2. **fs_*** tables - Virtual filesystem (inodes, directory entries, chunks)
3. **kv_store** - Key-value pairs for metadata

### Overlay Semantics

```python
# stable.db - Ground truth
stable = await AgentFS.open(AgentFSOptions(id="stable"))

# agent.db - Overlay
agent = await AgentFS.open(AgentFSOptions(id="agent-abc123"))

# Read operation (falls through)
content = await agent.fs.read_file("main.py")
# 1. Check agent.db inodes/entries
# 2. If not found, check stable.db
# 3. Return content from first hit

# Write operation (overlay only)
await agent.fs.write_file("main.py", new_content)
# 1. Write to agent.db only
# 2. stable.db unchanged
```

### File Operations

```python
# Required operations
await agent_fs.fs.read_file(path: str) -> bytes
await agent_fs.fs.write_file(path: str, content: bytes) -> None
await agent_fs.fs.readdir(path: str) -> list[DirEntry]
await agent_fs.fs.stat(path: str) -> FileStat
await agent_fs.fs.remove(path: str) -> None
await agent_fs.fs.mkdir(path: str) -> None

# KV operations
await agent_fs.kv.get(key: str) -> str | None
await agent_fs.kv.set(key: str, value: str) -> None
await agent_fs.kv.delete(key: str) -> None
await agent_fs.kv.list(prefix: str) -> list[KVEntry]
```

### Data Directory Structure

```
$PROJECT_ROOT/.agentfs/
├── stable.db           # Human's ground truth (initialized from project files)
├── agent-{uuid}.db     # Per-agent overlay (ephemeral)
└── bin.db              # Garbage collection tracker

$CAIRN_HOME/ (default: ~/.cairn/)
├── workspaces/
│   ├── agent-{uuid}/   # Materialized workspace (on-demand)
│   └── ...
├── previews/
│   ├── agent-{uuid}.diff
│   └── ...
├── signals/
│   ├── accept-{uuid}
│   ├── reject-{uuid}
│   └── ...
└── state/
    ├── latest_agent
    ├── active_agents.json
    └── config.toml
```

## Execution Layer: Monty

### Sandbox Constraints

Monty provides a minimal Python interpreter with:

**Allowed:**
- Variables, functions, loops, conditionals
- Basic types: int, float, str, bool, list, dict, tuple, set
- Type hints (for typechecking)
- Async/await
- f-strings, comprehensions

**Disallowed:**
- `import` statements (no stdlib, no third-party)
- `open()`, `eval()`, `exec()`
- File I/O (except via external functions)
- Network access (except via external functions)
- Subprocess calls
- Class definitions (MVP - support coming)
- Match statements (support coming)

### External Function Interface

Agents can ONLY interact with host via external functions:

```python
# Required external functions for Cairn

# Filesystem operations (via AgentFS)
def read_file(path: str) -> str:
    """Read file from agent overlay (falls through to stable)"""

def write_file(path: str, content: str) -> bool:
    """Write file to agent overlay only"""

def list_dir(path: str) -> list[str]:
    """List directory contents"""

def file_exists(path: str) -> bool:
    """Check if file exists"""

# Search operations (UNIX tools via subprocess)
def search_files(pattern: str) -> list[str]:
    """Find files matching glob pattern (uses ripgrep or find)"""

def search_content(pattern: str, path: str = ".") -> list[dict]:
    """Search file contents (uses ripgrep)"""
    # Returns: [{"file": "main.py", "line": 42, "text": "..."}]

# LLM operations (via llm library)
def ask_llm(prompt: str, context: str = "") -> str:
    """Query LLM for assistance"""

# Submission
def submit_result(summary: str, changed_files: list[str]) -> bool:
    """Submit agent results for review"""

# Debugging
def log(message: str) -> bool:
    """Log debug message"""
```

### Execution Model

```python
# Orchestrator creates Monty instance
m = pydantic_monty.Monty(
    agent_code,
    inputs=[],  # No CLI inputs
    external_functions=list(external_funcs.keys()),
    script_name=f"{agent_id}.py",
    max_execution_time=60,  # 1 minute timeout
    max_memory_bytes=100 * 1024 * 1024,  # 100MB limit
)

# Run async
result = await pydantic_monty.run_monty_async(
    m,
    inputs={},
    external_functions=external_funcs  # Dict of callable implementations
)
```

### Code Generation Prompt

```python
AGENT_CODE_PROMPT = """Write a short Python script to accomplish this task:
{task}

Available functions (the ONLY things you can call):
- read_file(path: str) -> str
- write_file(path: str, content: str) -> bool
- list_dir(path: str) -> list[str]
- file_exists(path: str) -> bool
- search_files(pattern: str) -> list[str]
- search_content(pattern: str, path: str = ".") -> list[dict]
- ask_llm(prompt: str, context: str = "") -> str
- submit_result(summary: str, changed_files: list[str]) -> bool
- log(message: str) -> bool

Constraints:
- You CANNOT: import anything, define classes, use open(), use print()
- Write simple procedural Python: variables, functions, loops, conditionals only
- Always call submit_result() at the end with summary and list of changed files
- Use log() to debug

Respond with ONLY the Python code. No markdown, no explanation.
"""
```

## Orchestration Layer: Cairn (Implemented Stage 3)

### Main Components

```python
from dataclasses import dataclass
from pathlib import Path

from agentfs_sdk import AgentFS

from cairn.agent import AgentContext
from cairn.code_generator import CodeGenerator
from cairn.executor import AgentExecutor
from cairn.queue import TaskQueue
from cairn.signals import SignalHandler
from cairn.watcher import FileWatcher
from cairn.workspace import WorkspaceMaterializer


@dataclass
class OrchestratorConfig:
    max_concurrent_agents: int = 5


class CairnOrchestrator:
    def __init__(self, project_root: Path | str = ".", cairn_home: Path | str | None = None):
        self.project_root = Path(project_root).resolve()
        self.agentfs_dir = self.project_root / ".agentfs"
        self.cairn_home = Path(cairn_home or Path.home() / ".cairn").expanduser()

        self.stable: AgentFS | None = None
        self.bin: AgentFS | None = None
        self.active_agents: dict[str, AgentContext] = {}
        self.queue = TaskQueue(max_concurrent=5)

        self.llm = CodeGenerator()
        self.executor = AgentExecutor()

        self.watcher: FileWatcher | None = None
        self.signals: SignalHandler | None = None
        self.materializer: WorkspaceMaterializer | None = None
```

### Agent Lifecycle

```
┌─────────────────────────────────────┐
│ 1. QUEUED                           │
│    Task in queue, waiting           │
└──────────┬──────────────────────────┘
           ↓
┌──────────────────────────────────────┐
│ 2. SPAWNING                          │
│    Create AgentFS overlay            │
│    Store task in agent.kv            │
└──────────┬───────────────────────────┘
           ↓
┌──────────────────────────────────────┐
│ 3. GENERATING                        │
│    LLM generates Python code         │
│    Store code in agent.kv            │
└──────────┬───────────────────────────┘
           ↓
┌──────────────────────────────────────┐
│ 4. EXECUTING                         │
│    Run code in Monty sandbox         │
│    Provide external functions        │
└──────────┬───────────────────────────┘
           ↓
┌──────────────────────────────────────┐
│ 5. SUBMITTING                        │
│    Agent calls submit_result()       │
│    Store submission in agent.kv      │
│    Materialize workspace             │
│    Generate diff                     │
└──────────┬───────────────────────────┘
           ↓
┌──────────────────────────────────────┐
│ 6. REVIEWING                         │
│    Ghost text shown in Neovim        │
│    Preview available in tmux         │
│    Wait for accept/reject signal     │
└──────────┬───────────────────────────┘
           ↓
      ┌────┴────┐
      ↓         ↓
┌──────────┐ ┌──────────┐
│ ACCEPTED │ │ REJECTED │
│          │ │          │
│ Merge to │ │ Delete   │
│ stable   │ │ overlay  │
└──────────┘ └──────────┘
      ↓         ↓
┌──────────────────┐
│ 7. GARBAGE       │
│    COLLECTED     │
│                  │
│    Delete agent  │
│    database      │
└──────────────────┘
```

### Background Tasks

```python
class CairnOrchestrator:
    async def run(self) -> None:
        if self.watcher is None or self.signals is None:
            await self.initialize()

        await asyncio.gather(
            self.watcher.watch(),
            self.signals.watch(),
            self.auto_spawn_loop(),
        )
```

### File Watching

```python
from watchfiles import Change


class FileWatcher:
    async def handle_change(self, change_type: Change, path: Path) -> None:
        if self.should_ignore(path) or path.is_dir():
            return

        rel_path = path.relative_to(self.project_root).as_posix()

        if change_type == Change.deleted:
            await self._delete_from_stable(rel_path)
            return

        if path.exists():
            await self.stable.fs.write_file(rel_path, path.read_bytes())
```

### Signal Handling

```python
class SignalHandler:
    async def watch(self) -> None:
        while True:
            await asyncio.sleep(0.5)

            for signal_file in sorted(self.signals_dir.glob("accept-*")):
                payload = self._load_payload(signal_file)
                agent_id = payload.get("agent_id") or signal_file.stem.replace("accept-", "")
                await self.orchestrator.accept_agent(agent_id)
                signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("reject-*")):
                payload = self._load_payload(signal_file)
                agent_id = payload.get("agent_id") or signal_file.stem.replace("reject-", "")
                await self.orchestrator.reject_agent(agent_id)
                signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("spawn-*")):
                payload = self._load_payload(signal_file)
                if payload.get("task"):
                    await self.orchestrator.spawn_agent(payload["task"], TaskPriority(payload.get("priority", 3)))
                signal_file.unlink(missing_ok=True)
```

### Accept/Reject Logic

```python
async def accept_agent(self, agent_id: str) -> None:
    ctx = self._get_agent(agent_id)
    ctx.transition(AgentState.ACCEPTED)

    await self._merge_overlay_to_stable(ctx.agent_fs, self.stable)
    await self.trash_agent(agent_id)


async def reject_agent(self, agent_id: str) -> None:
    ctx = self._get_agent(agent_id)
    ctx.transition(AgentState.REJECTED)
    await self.trash_agent(agent_id)
```

### Workspace Materialization

```python
class WorkspaceMaterializer:
    async def materialize(self, agent_id: str, agent_fs: AgentFS) -> Path:
        workspace = self.workspace_dir / agent_id
        if workspace.exists():
            shutil.rmtree(workspace)
        workspace.mkdir(parents=True, exist_ok=True)

        if self.stable_fs is not None:
            await self._copy_recursive(self.stable_fs, "/", workspace)

        await self._copy_recursive(agent_fs, "/", workspace)
        return workspace
```

## UI Layer: Neovim + TMUX

### Neovim Plugin Architecture

```lua
-- cairn/nvim/plugin/cairn.lua

local M = {}

M.config = {
  cairn_home = vim.fn.expand('~/.cairn'),
  preview_same_location = true,  -- Open preview at same file:line
  auto_reload = false,            -- Conservative: don't auto-reload (MVP)
}

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})

  -- Setup watchers
  require('cairn.watcher').setup(M.config)

  -- Setup tmux integration
  require('cairn.tmux').setup(M.config)

  -- Setup keymaps
  vim.keymap.set('n', '<leader>a', M.accept, { desc = 'Accept Cairn changes' })
  vim.keymap.set('n', '<leader>r', M.reject, { desc = 'Reject Cairn changes' })
  vim.keymap.set('n', '<leader>p', M.preview, { desc = 'Open Cairn preview' })

  -- Setup commands
  vim.api.nvim_create_user_command('CairnQueue', M.queue_task, { nargs = '+' })
  vim.api.nvim_create_user_command('CairnListTasks', M.list_tasks, {})
  vim.api.nvim_create_user_command('CairnPreview', M.preview, {})
  vim.api.nvim_create_user_command('CairnAccept', M.accept, {})
  vim.api.nvim_create_user_command('CairnReject', M.reject, {})
end

return M
```

### TMUX Integration

```lua
-- cairn/nvim/lua/cairn/tmux.lua

local M = {}

function M.open_preview(agent_id, file_path, line_num)
  -- Get agent workspace path
  local workspace = vim.fn.expand('~/.cairn/workspaces/' .. agent_id)

  if vim.fn.isdirectory(workspace) == 0 then
    vim.notify('Workspace not materialized yet', vim.log.levels.WARN)
    return
  end

  -- Build tmux command
  local target_file = workspace .. '/' .. file_path
  local nvim_cmd = string.format('nvim +%d %s', line_num, vim.fn.shellescape(target_file))

  -- Check if preview pane exists
  local preview_pane = vim.fn.system('tmux list-panes -F "#{pane_title}" | grep "cairn-preview"')

  if preview_pane ~= '' then
    -- Update existing pane
    vim.fn.system(string.format('tmux send-keys -t cairn-preview C-z "%s" Enter', nvim_cmd))
  else
    -- Create new preview pane
    vim.fn.system(string.format(
      'tmux split-window -h -t {next} -c %s "tmux select-pane -T cairn-preview; %s"',
      vim.fn.shellescape(workspace),
      nvim_cmd
    ))
  end
end

return M
```

### Ghost Text Display

```lua
-- cairn/nvim/lua/cairn/ghost.lua

local M = {}
local ns = vim.api.nvim_create_namespace('cairn_ghost')

function M.show_ghost_text(bufnr, agent_id, changes)
  -- Clear existing
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local rel_path = vim.fn.fnamemodify(buf_name, ':.')

  local file_changes = changes[rel_path]
  if not file_changes then
    return
  end

  -- Show virtual lines for additions
  for _, change in ipairs(file_changes) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, change.line - 1, 0, {
      virt_lines = {{
        {string.format(' + %s', change.text), 'Comment'}
      }},
      virt_lines_above = false,
    })
  end

  -- Show notification
  vim.notify(
    string.format('Agent %s has suggestions (press <Leader>p to preview)',
      agent_id:sub(1, 8)),
    vim.log.levels.INFO
  )
end

return M
```

## LLM Integration

### LLM Library Usage

```python
import llm

from cairn.code_generator import CodeGenerator


class CodeGenerator:
    def __init__(self, model: str | None = None):
        self.model = llm.get_model(model) if model else llm.get_default_model()

    async def generate(self, task: str) -> str:
        prompt = self.PROMPT_TEMPLATE.format(task=task)
        response = self.model.prompt(prompt)
        return self.extract_code(response.text())

    def extract_code(self, response: str) -> str:
        lines = response.strip().split("\n")
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        return "\n".join(lines).strip()
```

### Configuration

```python
# Via llm CLI
$ llm models list
$ llm models default gpt-4

# Or in code
import llm

# Use OpenAI
model = llm.get_model("gpt-4")

# Use local Ollama
model = llm.get_model("ollama/qwen2.5-coder:7b")

# Use default
model = llm.get_default_model()
```

## Jujutsu Integration

### Change Mapping

```
Cairn Agent      →  Jujutsu Change
─────────────────────────────────────
agent-abc123     →  change abc123
Accept           →  jj squash abc123
Reject           →  jj abandon abc123
Preview          →  jj edit abc123 + materialize
```

### Implementation

```python
# cairn/jj.py

import subprocess
from pathlib import Path

class JujutsuIntegration:
    """Integrate Cairn agents with Jujutsu VCS"""

    def __init__(self, project_root: Path):
        self.project_root = project_root

    async def create_change(self, agent_id: str, description: str) -> bool:
        """Create a new jj change for agent"""
        # jj new -m "Agent: {description}"
        result = subprocess.run(
            ["jj", "new", "-m", f"Agent: {description}"],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )
        return result.returncode == 0

    async def squash_change(self, agent_id: str) -> bool:
        """Squash agent change into working copy"""
        # jj squash --from <change_id>
        result = subprocess.run(
            ["jj", "squash", "--from", agent_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )
        return result.returncode == 0

    async def abandon_change(self, agent_id: str) -> bool:
        """Abandon agent change"""
        # jj abandon <change_id>
        result = subprocess.run(
            ["jj", "abandon", agent_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )
        return result.returncode == 0

    async def describe_change(self, agent_id: str, description: str) -> bool:
        """Update change description"""
        # jj describe <change_id> -m <description>
        result = subprocess.run(
            ["jj", "describe", agent_id, "-m", description],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )
        return result.returncode == 0
```

## Performance Targets

| Operation | Target | Measurement |
|-----------|--------|-------------|
| Agent spawn | <1s | Create overlay + generate code |
| Code execution | <5s | Monty runtime |
| Preview open | <100ms | TMUX pane + Neovim launch |
| Accept/reject | <50ms | Copy files or delete overlay |
| File sync | <10ms | inotify → stable.db write |
| Workspace materialize | <500ms | Copy overlay to disk |
| GC scan | <10ms | Check 10 workspaces |

## Security Model

### Threat Model

**Trusted:**
- Developer (you)
- LLM provider (with API key)
- Nix/devenv (system packages)

**Untrusted:**
- Agent-generated code
- Agent file modifications

**Attacks We Prevent:**
- ❌ File exfiltration (no file I/O except via functions)
- ❌ Network exfiltration (no network except via functions)
- ❌ Code injection (Monty sandbox)
- ❌ Stable layer corruption (overlays can't write to stable)
- ❌ Resource exhaustion (timeouts + memory limits)

**Attacks We Don't Prevent:**
- ⚠️ Bad code (you review before accepting)
- ⚠️ LLM prompt injection (you set tasks)
- ⚠️ Disk exhaustion (workspace materialization uses disk)

### Monty Sandbox Guarantees

- **No imports**: Can't load stdlib or third-party packages
- **No file I/O**: Can't use `open()`, `read()`, `write()`
- **No exec**: Can't use `eval()`, `exec()`, `compile()`
- **No subprocess**: Can't shell out
- **Time limit**: 60s execution timeout
- **Memory limit**: 100MB RAM
- **Stack limit**: 1000 frames

### AgentFS Isolation

- Each agent has own SQLite database
- Agents can't read each other's overlays
- Agents can't write to stable layer
- Overlays deleted on accept/reject
- Database files are standard SQLite (inspectable)

## Configuration Schema

```toml
# ~/.cairn/config.toml

[orchestrator]
max_concurrent_agents = 5
auto_spawn = true

[llm]
provider = "openai"         # or "ollama", "anthropic"
model = "gpt-4"
temperature = 0.2
max_tokens = 2000

[agentfs]
data_dir = ".agentfs"
enable_fuse = false         # Future: FUSE mounts

[monty]
timeout_seconds = 60
max_memory_mb = 100
max_stack_depth = 1000

[gc]
max_age_hours = 1
max_workspaces = 10
max_total_size_mb = 1000
cleanup_on_accept = true
cleanup_on_reject = true
keep_latest = 3

[tmux]
auto_create_session = true
layout = "main-vertical"    # or "even-horizontal", "tiled"
preview_pane_size = "50%"

[jj]
enabled = true
create_change_on_spawn = true
auto_describe = true

[ui]
ghost_text = true
auto_reload = false         # Conservative for MVP
preview_same_location = true
```

## Error Handling

### Agent Execution Errors

```python
try:
    result = await run_monty_async(m, inputs={}, external_functions=funcs)
except pydantic_monty.TimeoutError:
    await agent_fs.kv.set("error", "Execution timeout (>60s)")
except pydantic_monty.MemoryError:
    await agent_fs.kv.set("error", "Memory limit exceeded (>100MB)")
except pydantic_monty.SyntaxError as e:
    await agent_fs.kv.set("error", f"Syntax error: {e}")
except Exception as e:
    await agent_fs.kv.set("error", f"Runtime error: {e}")
finally:
    # Always store result/error in agent.kv for inspection
    pass
```

### LLM Errors

```python
try:
    code = await llm_provider.generate_agent_code(task)
except llm.ModelNotFoundError:
    # Fallback to default model
    code = await fallback_provider.generate_agent_code(task)
except llm.RateLimitError:
    # Queue task for retry
    await task_queue.enqueue(task, priority=TaskPriority.HIGH)
except Exception as e:
    # Log and fail gracefully
    logger.error(f"LLM error: {e}")
    return None
```

## Testing Strategy

### Unit Tests

- AgentFS operations (read, write, overlay fallthrough)
- Monty sandbox (external function calls, timeouts)
- Task queue (enqueue, dequeue, priorities)
- GC (age-based, count-based cleanup)

### Integration Tests

- Full agent lifecycle (spawn → execute → submit → accept)
- Multi-agent concurrency
- File watching (project changes → stable.db)
- Signal handling (accept/reject)

### End-to-End Tests

- Real LLM integration (with test model)
- TMUX preview workspace
- Neovim plugin commands
- Jujutsu integration

## Deployment

### Via devenv.nix

```nix
{ inputs, ... }:
{
  imports = [
    ./nixbox/modules/agentfs.nix
    ./nixbox/modules/cairn.nix
  ];

  packages = [
    # Added automatically by cairn.nix:
    # - agentfs
    # - python311 + uv
    # - tmux
    # - jujutsu
    # - neovim (if not already present)
  ];

  env = {
    CAIRN_LLM_MODEL = "gpt-4";
    CAIRN_MAX_CONCURRENT_AGENTS = "3";
  };

  processes.cairn = {
    exec = "cairn up";
  };
}
```

### Manual Installation

```bash
# 1. Install dependencies
nix-env -iA nixpkgs.python311 nixpkgs.tmux nixpkgs.jujutsu

# 2. Install Python packages
uv pip install agentfs-sdk pydantic-monty llm watchfiles

# 3. Clone nixbox
git clone https://github.com/yourusername/nixbox.git

# 4. Install Neovim plugin
mkdir -p ~/.config/nvim/lua
cp -r nixbox/cairn/nvim/lua/cairn ~/.config/nvim/lua/

# 5. Configure LLM
llm models default gpt-4

# 6. Run orchestrator
cd your-project
python nixbox/cairn/orchestrator.py
```

## Next Steps

See:
- [AGENT.md](AGENT.md) - For contributing and AI agent instructions
- [SKILL-*.md](docs/skills/) - For subsystem-specific development guides
- [CONCEPT.md](CONCEPT.md) - For philosophical background

---

**Status:** This spec defines the MVP (Phase 1). Features like persistent sessions, hunk-level accept/reject, and multi-repo support are Phase 2+.
