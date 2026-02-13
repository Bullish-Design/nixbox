# TMUX Enhancement Concept: Parallel Neovim “Agent Preview” Workspaces

This concept adds a **tmux-driven preview lane** to a `devenv.sh`-managed environment so a human can keep their main Neovim session stable while concurrently loading and testing an **agent-produced code/config variant** in a second Neovim instance.

## Goal

Enable a fast loop:

1. Human edits in **stable workspace** (main Neovim).
2. Agent produces changes in an **overlay** (agent workspace).
3. Human launches a **preview Neovim** in tmux against the agent workspace (mount or materialized directory).
4. Human runs tests/builds in preview.
5. Human **accepts** (merge overlay → stable) or **rejects** (discard overlay).

Key property: **two editors remain live**; switching is instant via tmux window/pane navigation.

---

## Core Ideas

### 1) Two concurrent “truths”
- **Stable truth**: your primary working directory (what you’re currently editing).
- **Agent truth**: a workspace that reflects “stable + agent overlay”, exposed as a **real directory** for tooling compatibility.

### 2) Workspace exposure strategy
Agents must produce a directory view that tools can read:

- **Materialize**: export “stable + overlay” into `~/.chimera/workspaces/<agent-id>/`
  - Simple, predictable, works everywhere.
  - Snapshot semantics; refresh by re-export.
- **Mount** (optional later): FUSE overlay mount at `~/.chimera/mounts/<agent-id>/`
  - Live semantics; more complex operations/cleanup.

MVP recommendation: **Materialize on demand**.

### 3) tmux as the UI router
tmux provides:
- a stable Neovim window/pane
- a preview Neovim window/pane (agent workspace)
- optional panes for logs, test watcher, agent output

tmuxp optionally codifies this layout for reproducibility.

---

## Expected UX

### Stable editor
- Run `devenv shell`
- Launch stable Neovim as usual (`nvim`), editing the real repo.

### Agent preview editor
- One command (or mapping) opens a tmux window/pane running:
  - `nvim` with `cwd` set to the agent workspace directory.

### Switching
- Switching between stable and preview is:
  - tmux window switch / pane focus
  - no editor restart required

---

## Required Capabilities (Agent Framework Contract)

To support tmux preview, the agent framework **must** provide:

1. **Agent workspace ID**
   - A stable identifier for the active suggestion (e.g., `agent-<timestamp>`).

2. **Materialize command**
   - Given an agent ID, produce a directory tree representing “stable + overlay”.
   - Output path is deterministic:
     - `CHIMERA_WORKSPACES/<agent-id>/` (default `~/.chimera/workspaces/<agent-id>/`)

3. **Latest suggestion pointer**
   - A single file or IPC key indicating the “current” agent ID:
     - `~/.chimera/state/latest_agent`

4. **Accept/Reject**
   - Accept merges overlay into stable (and optionally into the real filesystem).
   - Reject discards the overlay (and can garbage-collect materialized workspaces).

---

## devenv.sh Integration Requirements

The development environment must include:

- `tmux` and (optionally) `tmuxp`
- a `chimera` CLI (or scripts) providing:
  - `chimera materialize <agent-id>` (or equivalent)
  - `chimera latest-agent` (reads pointer)
  - `chimera accept <agent-id>` / `chimera reject <agent-id>`

Environment variables:
- `CHIMERA_HOME=~/.chimera`
- `CHIMERA_WORKSPACES=$CHIMERA_HOME/workspaces`

---

## Neovim Integration Requirements

Neovim should provide a small “control plane”:

### Commands / mappings
- `:ChimeraPreviewOpen [agent-id]`
  - Resolves agent-id (argument or latest pointer)
  - Ensures workspace exists (materialize if needed)
  - Opens tmux window/pane with `cwd=<workspace>`
- `:ChimeraAccept [agent-id]`
- `:ChimeraReject [agent-id]`

### Optional ergonomics
- “Open same file/line in preview”
  - Translate current file path relative to repo into the agent workspace path
  - Launch preview Neovim at the same location

---

## Lifecycle + Cleanup

### Workspace lifecycle
- Materialized workspace is considered **ephemeral**.
- It can be recreated at any time from stable + overlay.

### Garbage collection
- Keep last N agent workspaces or expire by age.
- On `reject`, delete the overlay and its materialized workspace.
- On `accept`, delete the overlay; keep or delete the workspace (policy).

---

## Success Criteria

- Human can keep stable Neovim running indefinitely.
- Preview Neovim loads quickly and runs tooling against agent changes without path hacks.
- Switching between stable and preview is instant.
- Accept/reject is deterministic and leaves no stale mounts/workspaces behind.

---

## Non-Goals (MVP)

- Live two-way editing synchronization between stable and preview editors.
- Complex multi-agent merge UIs beyond accept/reject of one selected overlay.
- Always-on exporting for every agent write (prefer on-demand or on-submit).
