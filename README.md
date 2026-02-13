# Nixbox

> A modular devenv.sh plugin providing agentic development environments

**Nixbox** enables seamless AI agent collaboration in your development workflow through a composable stack of overlayed filesystems, sandboxed execution, and intelligent workspace management.

## What is Nixbox?

Nixbox is a collection of Nix modules that bring **Cairn** - an interactive agentic workspace - to any devenv-managed project. It provides:

- **AgentFS Process Management** - Local SQLite-based filesystem with overlay semantics
- **Cairn Orchestrator** - Spawn AI agents that propose changes in isolated overlays
- **TMUX Integration** - Hot-swap between your stable workspace and agent previews
- **Neovim Plugin** - Review and merge agent changes with familiar keybindings
- **Jujutsu Integration** - Agent changes map to jj change concepts

## Quick Start

### 1. Add Nixbox to Your Project

```nix
# devenv.nix
{ inputs, ... }:
{
  imports = [
    ./nixbox/modules/agentfs.nix  # Core: AgentFS process
    ./nixbox/modules/cairn.nix    # Optional: Agentic workspace
  ];
}
```

### 2. Enter Development Environment

```bash
devenv shell

# AgentFS starts automatically in background
# Check status:
agentfs-info
```

### 3. Initialize Cairn Workspace

```bash
# Start the orchestrator service (Stage 3)
cairn up
```

> `cairn-init` is still planned and is **not** part of the current Stage 3 CLI surface.

### 4. Install and Load the Neovim Plugin

Use any plugin manager and point it at `nixbox/cairn/nvim` (the plugin root in this repo).

```lua
-- lazy.nvim example
{
  dir = '~/path/to/nixbox/cairn/nvim',
  config = function()
    require('cairn').setup({
      preview_same_location = true,
    })
  end,
}
```

```lua
-- packer.nvim example
use {
  '~/path/to/nixbox/cairn/nvim',
  config = function()
    require('cairn').setup()
  end,
}
```

### 5. Use It

```vim
" In Neovim, queue an agent task
:CairnQueue "Add docstrings to all functions"

" Agent runs in background, shows ghost text when ready
" Press <Leader>a to accept or <Leader>r to reject
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  Your Project (Stable Layer)                │
│  ↓                                           │
│  AgentFS (stable.db)                         │
│  ├── Agentlet 1 (overlay)                   │
│  ├── Agentlet 2 (overlay)                   │
│  └── Agentlet N (overlay)                   │
│                                              │
│  Each agent:                                 │
│  - Reads from stable (copy-on-write)        │
│  - Writes to own overlay                    │
│  - Runs in Monty sandbox                    │
│  - Generates code via LLM                   │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  TMUX Workspace Layout                      │
│  ┌────────────┬────────────┐                │
│  │  Stable    │  Preview   │                │
│  │  Neovim    │  Neovim    │                │
│  │            │            │                │
│  │  Your      │  Agent's   │                │
│  │  Changes   │  Changes   │                │
│  └────────────┴────────────┘                │
│  │ Orchestrator Logs       │                │
│  └─────────────────────────┘                │
└─────────────────────────────────────────────┘
```

## Core Concepts

### The Cairn Metaphor

A **cairn** is a pile of stones that hikers add to over time - each person contributes by adding stones to the top. Similarly, in Cairn workspace:

- **Humans** add changes directly to the stable layer
- **Agents** propose changes in overlays
- **Accept** adds the agent's stones to the cairn (merge)
- **Reject** discards the agent's proposed stones

No complex merging, no state machines - just a growing pile of collaborative changes.

### AgentFS Overlays

Each agent gets its own SQLite database that overlays the stable layer:

```python
# Agent reads file (falls through to stable if not modified)
content = await agent_fs.fs.read_file("main.py")

# Agent writes file (only to its overlay)
await agent_fs.fs.write_file("main.py", new_content)

# Stable layer unchanged until you accept
```

### Monty Sandbox

Agent code runs in a minimal Python interpreter with no access to:
- File system (except via external functions)
- Network (except via external functions)
- Imports (no stdlib or third-party packages)
- Host environment

Agents can only call functions you provide:
```python
read_file(path)
write_file(path, content)
ask_llm(prompt, context)
search_files(pattern)
submit_result(summary, files)
```

### TMUX Hot-Swapping

Instead of ghost text in one editor, run two Neovim instances:

1. **Stable Neovim** - Your main editor, always up
2. **Preview Neovim** - Agent's workspace, materialized on-demand

Switch with `Ctrl-b o` (standard tmux), test changes, run builds, then accept or reject.

## Components

### Nix Modules

- **`modules/agentfs.nix`** - AgentFS process, environment, scripts
- **`modules/cairn.nix`** - Orchestrator, tmux, Python dependencies

### Python Libraries

- **`agentfs-pydantic`** - Type-safe models for AgentFS SDK
  - Published to PyPI independently
  - Pydantic models + View query interface
  - Optional CLI tools (`pip install agentfs-pydantic[cli]`)

### Orchestrator

- **`cairn/orchestrator.py`** - Main process managing agents
- **`cairn/queue.py`** - Task queue with priorities
- **`cairn/gc.py`** - Workspace garbage collection
- **`cairn/jj.py`** - Jujutsu integration

### Neovim Plugin

- **`cairn/nvim/plugin/cairn.lua`** - User command registration
- **`cairn/nvim/lua/cairn/init.lua`** - Setup + keymap wiring
- **`cairn/nvim/lua/cairn/commands.lua`** - Queue/accept/reject/list/select handlers
- **`cairn/nvim/lua/cairn/tmux.lua`** - TMUX preview pane management
- **`cairn/nvim/lua/cairn/watcher.lua`** - Stage 4 REVIEWING watcher + ghost trigger

### TMUX Config

- **`cairn/tmux/.tmuxp.yaml`** - Initial workspace layout

## Requirements

- **NixOS** or Nix with devenv
- **Python 3.11+**
- **Neovim 0.10+**
- **TMUX 3.0+**
- **Jujutsu** (optional, for VCS integration)
- **LLM Provider** (local via Ollama, or remote via API)

## Installation

### As a Submodule

```bash
cd your-project
git submodule add https://github.com/yourusername/nixbox.git
```

### Direct Clone

```bash
cd your-project
git clone https://github.com/yourusername/nixbox.git
```

### Import Modules

```nix
# devenv.nix
{ inputs, ... }:
{
  imports = [
    ./nixbox/modules/agentfs.nix
    ./nixbox/modules/cairn.nix
  ];

  # Optional: customize
  env.CAIRN_MAX_CONCURRENT_AGENTS = "3";
  env.CAIRN_LLM_MODEL = "gpt-4";
}
```

## Configuration

### Environment Variables

```bash
# AgentFS
AGENTFS_HOST=127.0.0.1
AGENTFS_PORT=8081
AGENTFS_DATA_DIR=.devenv/state/agentfs

# Cairn
CAIRN_HOME=~/.cairn
CAIRN_MAX_CONCURRENT_AGENTS=5
CAIRN_LLM_MODEL=gpt-4
CAIRN_LLM_PROVIDER=openai  # or 'ollama'
```

### LLM Configuration

Cairn uses the [`llm`](https://llm.datasette.io/) library for LLM access:

```bash
# Install a model
llm install llm-gpt4all
llm models default gpt4all-falcon

# Or use OpenAI
export OPENAI_API_KEY=sk-...
llm models default gpt-4

# Or use Ollama
llm install llm-ollama
llm models default ollama/qwen2.5-coder:7b
```

### Cairn Config

```toml
# ~/.cairn/config.toml

[orchestrator]
max_concurrent_agents = 5
auto_materialize = true

[gc]
max_age_hours = 1
max_workspaces = 10
cleanup_on_accept = true
cleanup_on_reject = true

[tmux]
auto_create_session = true
layout = "main-vertical"

[llm]
provider = "openai"
model = "gpt-4"
temperature = 0.2
```

## Usage

### Stage 3 CLI Status (Implemented)

The following orchestrator commands are functional in Stage 3:

```bash
# 1) Start the headless orchestrator service
cairn --project-root . --cairn-home ~/.cairn up

# 2) Queue work
cairn --cairn-home ~/.cairn spawn "Add docstrings to public functions"  # high priority
cairn --cairn-home ~/.cairn queue "Refactor long functions"              # normal priority

# 3) Inspect state
cairn --cairn-home ~/.cairn list-agents
cairn --cairn-home ~/.cairn status agent-<id>

# 4) Resolve review outcome
cairn --cairn-home ~/.cairn accept agent-<id>
cairn --cairn-home ~/.cairn reject agent-<id>
```

Command behavior notes:
- `up` runs the long-lived orchestrator loop.
- `spawn`, `queue`, `accept`, and `reject` enqueue JSON signal files under `$CAIRN_HOME/signals`.
- `list-agents` and `status` read orchestrator snapshots from `$CAIRN_HOME/state/orchestrator.json`.

Not yet implemented in Stage 3:
- `cairn-init`
- Neovim/TMUX UI commands (`:CairnQueue`, ghost text workflow) are Stage 4 scope.

### Stage 4 Neovim Plugin Installation Notes

- The plugin is loaded from `cairn/nvim` (not from repository root).
- `plugin/cairn.lua` auto-registers user commands on startup.
- Call `require('cairn').setup({...})` in your plugin manager `config` callback to apply custom keymaps/config.
- Keep `plenary.nvim` installed for running the Stage 4 test suite under `cairn/nvim/tests/`.

### Stage 4 Neovim Test Invocation

Run the Neovim plugin contract tests headlessly with Plenary/busted:

```bash
PLENARY_PATH=/path/to/plenary.nvim \
  nvim --headless -u cairn/nvim/tests/minimal_init.lua \
  -c "set rtp+=$PLENARY_PATH" \
  -c "PlenaryBustedDirectory cairn/nvim/tests { minimal_init = 'cairn/nvim/tests/minimal_init.lua' }" \
  -c "qa"
```

This validates Stage 4 UI contracts (command wiring, config/keymaps, tmux preview behavior, ghost extmarks, and watcher parsing/REVIEWING detection).

### Queue Agent Tasks

```vim
" In Neovim
:CairnQueue "Add type hints to all functions"
:CairnQueue! "Urgent: fix failing CI check"
:CairnListTasks
```

### Review Changes

```vim
" Ghost text appears when agent finishes
" Press <Leader>p to open preview workspace

" In preview tmux pane:
" - Edit files
" - Run tests
" - Check builds

" Accept or reject
:CairnAccept
:CairnReject
```

### Multiple Agents

```vim
" List active agents
:CairnListAgents

" Select agent to preview
:CairnSelectAgent agent-abc123

" Open preview for selected/latest agent
:CairnPreview
```

### Jujutsu Integration

```bash
# Each agent creates a jj change
jj log
# ○ agent-abc123: Add docstrings
# ○ agent-def456: Add type hints
# @ working_copy: Your changes

# Accept merges agent change into working copy
:CairnAccept  # → jj squash agent-abc123

# Reject abandons the change
:CairnReject  # → jj abandon agent-def456
```

## Development

### Project Structure

```
nixbox/
├── modules/              # Nix modules
│   ├── agentfs.nix
│   └── cairn.nix
├── agentfs-pydantic/    # Pydantic library
│   ├── src/
│   ├── tests/
│   └── pyproject.toml
├── cairn/               # Orchestrator
│   ├── orchestrator.py
│   ├── queue.py
│   ├── gc.py
│   ├── jj.py
│   ├── nvim/           # Neovim plugin
│   └── tmux/           # TMUX config
├── examples/           # Example configurations
└── docs/              # Documentation
    ├── CONCEPT.md
    ├── SPEC.md
    ├── AGENT.md
    └── skills/
```

### Contributing

See [AGENT.md](AGENT.md) for instructions on working with AI agents on this codebase.

### Skills Documentation

Developer-focused guides for specific subsystems:

- [SKILL-AGENTFS.md](docs/skills/SKILL-AGENTFS.md) - Working with AgentFS SDK
- [SKILL-MONTY.md](docs/skills/SKILL-MONTY.md) - Monty sandbox integration
- [SKILL-TMUX.md](docs/skills/SKILL-TMUX.md) - TMUX workspace patterns
- [SKILL-NEOVIM.md](docs/skills/SKILL-NEOVIM.md) - Neovim plugin development
- [SKILL-JJ.md](docs/skills/SKILL-JJ.md) - Jujutsu VCS integration
- [SKILL-DEVENV.md](docs/skills/SKILL-DEVENV.md) - Nix/devenv module patterns

## Why Nixbox?

### Traditional Development
```
Human writes code → Commit → Test → Deploy
```

### AI-Assisted Development (Copilot, Cursor)
```
Human + AI writes code → Commit → Test → Deploy
```

### Agentic Development (Nixbox/Cairn)
```
Human writes code ─┐
                   ├→ Stable Layer → Review → Commit → Test → Deploy
Agent proposes ───┘
```

**Key Difference:** Agents work independently in overlays, humans review and merge. No interruption to flow, no fighting with AI over cursor control.

## Comparison

| Feature | Copilot/Cursor | Devin | Nixbox/Cairn |
|---------|----------------|-------|--------------|
| **Execution** | Inline suggestions | Cloud containers | Local Monty sandbox |
| **Review** | Accept/reject inline | Chat/watch | Dedicated preview workspace |
| **Safety** | Code in your editor | Isolated environment | Isolated overlay + sandbox |
| **Tooling** | Works with your files | Limited access | Full tooling in preview |
| **Cost** | Subscription | Pay per task | Local LLM or API |
| **Privacy** | Code sent to cloud | Code sent to cloud | Local-first option |
| **Speed** | Instant | Minutes | Seconds |

## License

MIT

## Links

- [Documentation](docs/)
- [AgentFS Specification](https://docs.turso.tech/agentfs)
- [Monty Sandbox](https://github.com/pydantic/monty)
- [llm library](https://llm.datasette.io/)
- [devenv](https://devenv.sh/)
- [Jujutsu VCS](https://github.com/martinvonz/jj)

## Support

- [Issues](https://github.com/yourusername/nixbox/issues)
- [Discussions](https://github.com/yourusername/nixbox/discussions)

---

**Built with ❤️ for developers who want AI assistants that know their place (in overlays).**
