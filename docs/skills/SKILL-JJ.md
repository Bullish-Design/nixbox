# SKILL: Jujutsu Integration

This guide covers integrating Cairn with Jujutsu (jj) version control for seamless agent change management.

## Overview

**Jujutsu** is a next-generation VCS that treats all work as changes (not commits). This maps perfectly to Cairn's agent overlay model:

- **Agent overlay** → **jj change**
- **Accept** → **jj squash** (merge into working copy)
- **Reject** → **jj abandon** (discard change)
- **Preview workspace** → **jj edit** (materialize change)

## Installation

Install Jujutsu via Nix:

```nix
# devenv.nix
{
  packages = [ pkgs.jujutsu ];
}
```

Or manually:

```bash
# Via Cargo
cargo install --git https://github.com/martinvonz/jj jj-cli

# Via package manager (if available)
brew install jj  # macOS
```

## Jujutsu Basics

### Key Concepts

**Change** - A description of work (can be empty, evolving)
**Working copy** - Current state of files on disk
**Revision** - A snapshot of a change at a point in time

Unlike git:
- Changes are automatically described
- Working copy is always a change
- Easy to edit/split/squash changes

### Essential Commands

```bash
# Create new change
jj new -m "Description"

# Edit change description
jj describe -m "New description"

# Squash change into parent
jj squash

# Abandon change
jj abandon <change_id>

# View history
jj log

# Edit a specific change
jj edit <change_id>
```

## Cairn + Jujutsu Integration

### Architecture

```
┌─────────────────────────────────────────┐
│ Cairn Agent          Jujutsu Change     │
├─────────────────────────────────────────┤
│ agent-abc123    →    change abc123      │
│                                          │
│ Spawn           →    jj new             │
│ Execute         →    (no VCS ops)       │
│ Submit          →    jj describe        │
│ Accept          →    jj squash          │
│ Reject          →    jj abandon         │
│ Preview         →    jj edit + export   │
└─────────────────────────────────────────┘
```

### Implementation

```python
# cairn/jj.py

import subprocess
from pathlib import Path
from typing import Optional

class JujutsuIntegration:
    """Integrate Cairn agents with Jujutsu VCS"""

    def __init__(self, project_root: Path, enabled: bool = True):
        self.project_root = project_root
        self.enabled = enabled

    async def create_change(self, agent_id: str, task_description: str) -> bool:
        """Create a new jj change for agent"""
        if not self.enabled:
            return False

        result = subprocess.run(
            ["jj", "new", "-m", f"Agent {agent_id}: {task_description}"],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"jj new failed: {result.stderr}")
            return False

        return True

    async def describe_change(
        self,
        agent_id: str,
        description: str
    ) -> bool:
        """Update change description after agent completes"""
        if not self.enabled:
            return False

        result = subprocess.run(
            ["jj", "describe", agent_id, "-m", description],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        return result.returncode == 0

    async def squash_change(self, agent_id: str) -> bool:
        """Squash agent change into working copy (accept)"""
        if not self.enabled:
            return False

        result = subprocess.run(
            ["jj", "squash", "--from", agent_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"jj squash failed: {result.stderr}")
            return False

        return True

    async def abandon_change(self, agent_id: str) -> bool:
        """Abandon agent change (reject)"""
        if not self.enabled:
            return False

        result = subprocess.run(
            ["jj", "abandon", agent_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        return result.returncode == 0

    async def export_change(self, agent_id: str, workspace_path: Path) -> bool:
        """Export change to workspace directory for preview"""
        if not self.enabled:
            return False

        # Edit to the agent's change
        result = subprocess.run(
            ["jj", "edit", agent_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return False

        # Copy working copy to workspace
        # (jj edit updates working copy to the change)
        import shutil
        for item in self.project_root.iterdir():
            if item.name.startswith('.'):
                continue
            dest = workspace_path / item.name
            if item.is_dir():
                shutil.copytree(item, dest)
            else:
                shutil.copy2(item, dest)

        # Edit back to original working copy
        subprocess.run(
            ["jj", "edit", "@"],
            cwd=self.project_root,
        )

        return True

    def get_change_info(self, agent_id: str) -> Optional[dict]:
        """Get information about a change"""
        if not self.enabled:
            return None

        result = subprocess.run(
            ["jj", "log", "-r", agent_id, "--no-graph", "-T", 'description'],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return None

        return {
            "id": agent_id,
            "description": result.stdout.strip()
        }
```

### Orchestrator Integration

```python
# cairn/orchestrator.py

class CairnOrchestrator:
    def __init__(self, project_root: str, config: CairnConfig):
        self.project_root = Path(project_root)
        self.jj = JujutsuIntegration(
            self.project_root,
            enabled=config.jj_integration
        )

    async def spawn_agentlet(self, task: str) -> str:
        """Spawn agentlet with jj integration"""
        agent_id = f"agent-{uuid.uuid4().hex[:8]}"

        # Create AgentFS overlay
        agent_fs = await AgentFS.open(AgentFSOptions(id=agent_id))
        self.active_agents[agent_id] = agent_fs

        # Create jj change
        if self.jj.enabled:
            await self.jj.create_change(agent_id, task)

        # Run agentlet
        asyncio.create_task(self.run_agentlet(agent_id, agent_fs, task))

        return agent_id

    async def accept_agent(self, agent_id: str):
        """Accept agent and squash jj change"""
        # Merge overlay to stable (AgentFS)
        await self.merge_overlay(agent_id)

        # Squash change (Jujutsu)
        if self.jj.enabled:
            await self.jj.squash_change(agent_id)

        # Cleanup
        await self.trash_agent(agent_id)

    async def reject_agent(self, agent_id: str):
        """Reject agent and abandon jj change"""
        # Abandon change (Jujutsu)
        if self.jj.enabled:
            await self.jj.abandon_change(agent_id)

        # Cleanup overlay (AgentFS)
        await self.trash_agent(agent_id)
```

## Workflow Examples

### Basic Agent Workflow

```bash
# Initial state
$ jj log
@  working_copy: Your work
◉  main: Previous commits

# Cairn spawns agent
$ cairn queue "Add docstrings"
# Creates: agent-abc123

$ jj log
◉  agent-abc123: Agent abc123: Add docstrings
│ @  working_copy: Your work
├─╯
◉  main: Previous commits

# Agent completes, you accept
$ cairn accept agent-abc123

$ jj log
@  working_copy: Your work + docstrings
◉  main: Previous commits
```

### Multiple Agents

```bash
# Initial state
$ jj log
@  working_copy: Your work

# Spawn multiple agents
$ cairn queue "Add docstrings"
$ cairn queue "Add type hints"
$ cairn queue "Add tests"

$ jj log
◉  agent-ghi789: Agent ghi789: Add tests
│ ◉  agent-def456: Agent def456: Add type hints
├─╯
│ ◉  agent-abc123: Agent abc123: Add docstrings
├─╯
@  working_copy: Your work

# Accept one, reject another
$ cairn accept agent-abc123
$ cairn reject agent-def456

$ jj log
◉  agent-ghi789: Agent ghi789: Add tests
│ @  working_copy: Your work + docstrings
├─╯
◉  main: Previous commits
```

### Preview Workspace

```bash
# Open preview for agent
$ cairn preview agent-abc123

# This:
# 1. Runs: jj edit agent-abc123
# 2. Copies working copy to ~/.cairn/workspaces/agent-abc123/
# 3. Runs: jj edit @  (back to your working copy)
# 4. Opens Neovim in preview workspace

# You can now:
# - Edit files in preview
# - Run tests
# - Check builds

# Accept if good
$ cairn accept agent-abc123
```

## Configuration

```toml
# ~/.cairn/config.toml

[jj]
enabled = true

# Create jj change when agent spawns
create_change_on_spawn = true

# Auto-describe change when agent submits
auto_describe = true

# Squash after accept (vs keep as separate revision)
squash_on_accept = true

# Abandon after reject (vs keep in history)
abandon_on_reject = true
```

## Advanced Patterns

### Cherry-Pick from Agent

```bash
# Agent made multiple changes, you only want some

$ jj edit agent-abc123
# Manually edit files to keep only desired changes

$ jj describe -m "Partial changes from agent"
$ jj edit @

$ cairn accept agent-abc123
# Squashes your curated version
```

### Rebase Agent Changes

```bash
# Your working copy moved forward, rebase agent

$ jj rebase -s agent-abc123 -d @
# Agent changes now based on latest working copy

$ cairn accept agent-abc123
```

### Split Agent Changes

```bash
# Agent changed multiple files, you want to review separately

$ jj edit agent-abc123
$ jj split
# Interactive split of changes

# Now have:
# - agent-abc123-1: First part
# - agent-abc123-2: Second part

# Accept one, reject another
$ cairn accept agent-abc123-1
$ cairn reject agent-abc123-2
```

## Comparison: Git vs Jujutsu

### Git Workflow (Without Cairn)

```bash
# Create branch for each experiment
git checkout -b experiment-1
# ... make changes ...
git commit -m "Experiment 1"

git checkout main
git checkout -b experiment-2
# ... make changes ...
git commit -m "Experiment 2"

# Merge good ones
git checkout main
git merge experiment-1
git branch -d experiment-2
```

**Problems:**
- Branches diverge from different points
- Merge conflicts
- Stale branches clutter repo
- Context switching required

### Jujutsu Workflow (With Cairn)

```bash
# Agents create changes on top of current work
cairn queue "Experiment 1"
cairn queue "Experiment 2"

# Changes are independent overlays
jj log
# ◉  agent-2: Experiment 2
# │ ◉  agent-1: Experiment 1
# ├─╯
# @  working_copy

# Squash good ones, abandon bad ones
cairn accept agent-1
cairn reject agent-2

# Clean history
jj log
# @  working_copy (includes experiment 1)
```

**Benefits:**
- No merge conflicts (overlays copy, don't merge)
- No stale branches (abandoned changes disappear)
- No context switching (work continues in working_copy)
- Changes always based on current state

## Troubleshooting

### Agent Change Not Created

```bash
# Check if jj is initialized
jj status
# Error: Not in a jj repository

# Initialize jj
jj init --git  # If migrating from git
jj init        # For new repo
```

### Squash Fails

```bash
# Check change exists
jj log -r agent-abc123

# If change is empty
jj abandon agent-abc123  # Instead of squash

# If change conflicts
jj edit agent-abc123
# Manually resolve conflicts
jj edit @
jj squash --from agent-abc123
```

### Lost Agent Changes

```bash
# Jujutsu never loses data
# View all changes (including abandoned)
jj log --all

# Restore abandoned change
jj new <change_hash>
jj describe -m "Restored agent change"
```

## Testing

### Unit Tests

```python
import pytest
from cairn.jj import JujutsuIntegration

@pytest.mark.asyncio
async def test_create_change(tmp_path):
    """Test creating jj change"""
    # Initialize jj repo
    subprocess.run(["jj", "init"], cwd=tmp_path)

    jj = JujutsuIntegration(tmp_path, enabled=True)
    success = await jj.create_change("agent-123", "Test task")

    assert success

    # Verify change exists
    result = subprocess.run(
        ["jj", "log", "-r", "agent-123"],
        cwd=tmp_path,
        capture_output=True
    )
    assert result.returncode == 0
```

### Integration Tests

```python
@pytest.mark.asyncio
async def test_full_workflow(tmp_path):
    """Test complete agent workflow with jj"""
    subprocess.run(["jj", "init"], cwd=tmp_path)

    orch = CairnOrchestrator(tmp_path, config_with_jj_enabled)

    # Spawn
    agent_id = await orch.spawn_agentlet("Test task")

    # Verify jj change created
    info = orch.jj.get_change_info(agent_id)
    assert info is not None

    # Accept
    await orch.accept_agent(agent_id)

    # Verify change squashed
    result = subprocess.run(
        ["jj", "log", "-r", agent_id],
        cwd=tmp_path,
        capture_output=True
    )
    # Change should no longer exist as separate revision
```

## Performance

### Overhead

- `jj new`: <50ms
- `jj squash`: <50ms
- `jj abandon`: <50ms
- `jj edit` + copy: <500ms

**Total overhead per agent:** ~100ms (negligible)

### Optimization

```python
# Batch operations if possible
async def accept_multiple_agents(agent_ids: list[str]):
    """Accept multiple agents in one jj operation"""
    if not self.jj.enabled:
        return

    # Squash all at once
    for agent_id in agent_ids:
        await self.jj.squash_change(agent_id)

    # OR: Create a combined change
    # jj new
    # for each agent: jj squash --from agent_id
```

## References

- [Jujutsu Documentation](https://github.com/martinvonz/jj)
- [Jujutsu Tutorial](https://github.com/martinvonz/jj/blob/main/docs/tutorial.md)
- [SPEC.md](../../SPEC.md) - Cairn architecture
- [CONCEPT.md](../../CONCEPT.md) - Philosophy

## See Also

- [SKILL-AGENTFS.md](SKILL-AGENTFS.md) - Overlay semantics
- [SKILL-TMUX.md](SKILL-TMUX.md) - Preview workspaces
