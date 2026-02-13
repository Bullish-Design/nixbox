# Stage 5: Integration & Polish

**Goal**: Production-ready system with all integrations and optimizations

**Status**: ⚪ Not Started
**Estimated Duration**: 3-4 weeks
**Dependencies**: All previous stages (1-4 complete)

---

## Overview

This is the final stage where we tie everything together, add remaining integrations (Jujutsu, GC), optimize performance, create Nix modules, and polish the entire system for production use.

The key insight: **A production system needs more than just working code - it needs reliability, performance, and great developer experience.**

---

## Deliverables

### 1. Jujutsu Integration

**File**: `cairn/jj.py`

**Requirements**:
Map agent overlays to Jujutsu changes.

```python
import subprocess
from pathlib import Path

class JujutsuIntegration:
    """Integrate Cairn agents with Jujutsu VCS"""

    def __init__(self, project_root: Path, enabled: bool = True):
        self.project_root = project_root
        self.enabled = enabled

    async def create_change(self, agent_id: str, description: str) -> bool:
        """Create a new jj change for agent"""
        if not self.enabled:
            return True

        result = subprocess.run(
            ["jj", "new", "-m", f"Agent: {description}"],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"jj error: {result.stderr}")
            return False

        # Get the change ID
        change_id = self._get_change_id()

        # Store mapping
        await self._store_mapping(agent_id, change_id)

        return True

    async def squash_change(self, agent_id: str) -> bool:
        """Squash agent change into working copy"""
        if not self.enabled:
            return True

        change_id = await self._get_change_id_for_agent(agent_id)
        if not change_id:
            return False

        result = subprocess.run(
            ["jj", "squash", "--from", change_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        return result.returncode == 0

    async def abandon_change(self, agent_id: str) -> bool:
        """Abandon agent change"""
        if not self.enabled:
            return True

        change_id = await self._get_change_id_for_agent(agent_id)
        if not change_id:
            return False

        result = subprocess.run(
            ["jj", "abandon", change_id],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        return result.returncode == 0

    async def describe_change(self, agent_id: str, description: str) -> bool:
        """Update change description"""
        if not self.enabled:
            return True

        change_id = await self._get_change_id_for_agent(agent_id)
        if not change_id:
            return False

        result = subprocess.run(
            ["jj", "describe", change_id, "-m", description],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        return result.returncode == 0

    def _get_change_id(self) -> str | None:
        """Get the current change ID"""
        result = subprocess.run(
            ["jj", "log", "-r", "@", "--no-graph", "-T", "change_id"],
            cwd=self.project_root,
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            return result.stdout.strip()
        return None

    async def _store_mapping(self, agent_id: str, change_id: str) -> None:
        """Store agent_id → change_id mapping"""
        mapping_file = self.project_root / ".agentfs" / "jj_mappings.json"
        mappings = {}

        if mapping_file.exists():
            mappings = json.loads(mapping_file.read_text())

        mappings[agent_id] = change_id
        mapping_file.write_text(json.dumps(mappings, indent=2))

    async def _get_change_id_for_agent(self, agent_id: str) -> str | None:
        """Get change_id for agent_id"""
        mapping_file = self.project_root / ".agentfs" / "jj_mappings.json"

        if not mapping_file.exists():
            return None

        mappings = json.loads(mapping_file.read_text())
        return mappings.get(agent_id)
```

**Contracts**:
```python
# Contract 1: Create change creates jj change
async def test_create_change():
    jj = JujutsuIntegration(Path("/tmp/test-repo"))

    success = await jj.create_change("agent-123", "Add docstrings")

    assert success is True

    # Verify change exists
    result = subprocess.run(
        ["jj", "log", "--no-graph", "-r", "all()"],
        cwd="/tmp/test-repo",
        capture_output=True,
        text=True
    )

    assert "Agent: Add docstrings" in result.stdout

# Contract 2: Squash merges change
async def test_squash_change():
    jj = JujutsuIntegration(Path("/tmp/test-repo"))

    # Create change
    await jj.create_change("agent-123", "Test change")

    # Get initial commit count
    initial_log = subprocess.run(
        ["jj", "log", "--no-graph"],
        cwd="/tmp/test-repo",
        capture_output=True,
        text=True
    )

    # Squash
    await jj.squash_change("agent-123")

    # Change should be squashed
    final_log = subprocess.run(
        ["jj", "log", "--no-graph"],
        cwd="/tmp/test-repo",
        capture_output=True,
        text=True
    )

    # Should have fewer changes after squash
    assert len(final_log.stdout.split('\n')) < len(initial_log.stdout.split('\n'))

# Contract 3: Abandon removes change
async def test_abandon_change():
    jj = JujutsuIntegration(Path("/tmp/test-repo"))

    await jj.create_change("agent-123", "Test change")
    await jj.abandon_change("agent-123")

    # Change should be abandoned
    result = subprocess.run(
        ["jj", "log", "--no-graph", "-r", "all()"],
        cwd="/tmp/test-repo",
        capture_output=True,
        text=True
    )

    # Should not appear in log (or marked as abandoned)
    assert "Test change" not in result.stdout or "abandoned" in result.stdout.lower()

# Contract 4: Disabled mode is safe
async def test_disabled_mode():
    jj = JujutsuIntegration(Path("/tmp/test-repo"), enabled=False)

    # All operations should succeed without doing anything
    assert await jj.create_change("agent-123", "Test") is True
    assert await jj.squash_change("agent-123") is True
    assert await jj.abandon_change("agent-123") is True
```

---

### 2. Garbage Collection

**File**: `cairn/gc.py`

**Requirements**:
Clean up old workspaces, overlays, and trashed agents.

```python
import time
import shutil
from pathlib import Path
from agentfs_sdk import AgentFS

class WorkspaceGC:
    """Garbage collect old workspaces and overlays"""

    def __init__(
        self,
        cairn_home: Path,
        agentfs_dir: Path,
        config: GCConfig | None = None,
    ):
        self.cairn_home = cairn_home
        self.agentfs_dir = agentfs_dir
        self.config = config or GCConfig()

    async def run(self) -> GCStats:
        """Run garbage collection"""
        stats = GCStats()

        # Clean old workspaces
        stats.workspaces_removed = await self._clean_workspaces()

        # Clean old agent databases
        stats.databases_removed = await self._clean_databases()

        # Clean old preview diffs
        stats.previews_removed = await self._clean_previews()

        # Clean old signal files
        stats.signals_removed = await self._clean_signals()

        return stats

    async def _clean_workspaces(self) -> int:
        """Remove old materialized workspaces"""
        workspace_dir = self.cairn_home / "workspaces"
        if not workspace_dir.exists():
            return 0

        removed = 0
        total_size = 0

        # Get all workspaces sorted by age
        workspaces = []
        for ws in workspace_dir.iterdir():
            if not ws.is_dir():
                continue

            stat = ws.stat()
            workspaces.append((ws, stat.st_mtime, self._get_dir_size(ws)))

        workspaces.sort(key=lambda x: x[1])  # Sort by mtime

        # Remove by age
        now = time.time()
        for ws, mtime, size in workspaces:
            age_hours = (now - mtime) / 3600

            if age_hours > self.config.max_age_hours:
                shutil.rmtree(ws)
                removed += 1
                continue

            total_size += size

        # Remove by count (keep latest N)
        if len(workspaces) - removed > self.config.max_workspaces:
            excess = len(workspaces) - removed - self.config.max_workspaces
            for ws, _, _ in workspaces[:excess]:
                if ws.exists():
                    shutil.rmtree(ws)
                    removed += 1

        # Remove by size
        if total_size > self.config.max_total_size_mb * 1024 * 1024:
            for ws, _, size in workspaces:
                if not ws.exists():
                    continue
                if total_size <= self.config.max_total_size_mb * 1024 * 1024:
                    break

                shutil.rmtree(ws)
                total_size -= size
                removed += 1

        return removed

    async def _clean_databases(self) -> int:
        """Remove trashed agent databases"""
        removed = 0

        # Open bin database
        bin = await AgentFS.open(AgentFSOptions(path=self.agentfs_dir / "bin.db"))

        # Get trashed agents
        trashed = await bin.kv.list("trashed:")

        now = time.time()
        for entry in trashed:
            agent_id = entry.key.replace("trashed:", "")
            trashed_at = float(entry.value)

            age_hours = (now - trashed_at) / 3600

            if age_hours > self.config.max_age_hours:
                # Remove database
                db_path = self.agentfs_dir / f"{agent_id}.db"
                if db_path.exists():
                    db_path.unlink()
                    removed += 1

                # Remove from bin
                await bin.kv.delete(entry.key)

        return removed

    async def _clean_previews(self) -> int:
        """Remove old preview diffs"""
        preview_dir = self.cairn_home / "previews"
        if not preview_dir.exists():
            return 0

        removed = 0
        now = time.time()

        for preview in preview_dir.glob("*.diff"):
            age_hours = (now - preview.stat().st_mtime) / 3600

            if age_hours > self.config.max_age_hours:
                preview.unlink()
                removed += 1

        return removed

    async def _clean_signals(self) -> int:
        """Remove old signal files"""
        signals_dir = self.cairn_home / "signals"
        if not signals_dir.exists():
            return 0

        removed = 0
        now = time.time()

        for signal in signals_dir.iterdir():
            age_minutes = (now - signal.stat().st_mtime) / 60

            # Signals older than 5 minutes are likely stale
            if age_minutes > 5:
                signal.unlink()
                removed += 1

        return removed

    def _get_dir_size(self, path: Path) -> int:
        """Get total size of directory"""
        total = 0
        for item in path.rglob("*"):
            if item.is_file():
                total += item.stat().st_size
        return total
```

**Contracts**:
```python
# Contract 1: Removes old workspaces
async def test_removes_old_workspaces():
    cairn_home = Path("/tmp/.cairn")
    gc = WorkspaceGC(cairn_home, Path("/tmp/.agentfs"), GCConfig(max_age_hours=1))

    # Create old workspace
    workspace = cairn_home / "workspaces" / "old-agent"
    workspace.mkdir(parents=True)
    (workspace / "test.txt").write_text("old")

    # Set old mtime (2 hours ago)
    old_time = time.time() - (2 * 3600)
    os.utime(workspace, (old_time, old_time))

    # Run GC
    stats = await gc.run()

    assert stats.workspaces_removed >= 1
    assert not workspace.exists()

# Contract 2: Keeps recent workspaces
async def test_keeps_recent_workspaces():
    cairn_home = Path("/tmp/.cairn")
    gc = WorkspaceGC(cairn_home, Path("/tmp/.agentfs"), GCConfig(max_age_hours=1))

    # Create recent workspace
    workspace = cairn_home / "workspaces" / "recent-agent"
    workspace.mkdir(parents=True)
    (workspace / "test.txt").write_text("recent")

    # Run GC
    stats = await gc.run()

    assert workspace.exists()

# Contract 3: Respects max workspace count
async def test_respects_max_count():
    cairn_home = Path("/tmp/.cairn")
    gc = WorkspaceGC(
        cairn_home,
        Path("/tmp/.agentfs"),
        GCConfig(max_workspaces=3, max_age_hours=100)  # Don't clean by age
    )

    # Create 5 workspaces
    for i in range(5):
        workspace = cairn_home / "workspaces" / f"agent-{i}"
        workspace.mkdir(parents=True)
        (workspace / "test.txt").write_text(f"agent {i}")

        # Stagger mtimes
        mtime = time.time() - (i * 60)
        os.utime(workspace, (mtime, mtime))

    # Run GC
    stats = await gc.run()

    # Should remove 2 (5 - 3)
    assert stats.workspaces_removed == 2

    # Should keep 3 most recent
    remaining = list((cairn_home / "workspaces").iterdir())
    assert len(remaining) == 3

# Contract 4: Cleans trashed databases
async def test_cleans_trashed_databases():
    agentfs_dir = Path("/tmp/.agentfs")
    bin = await AgentFS.open(AgentFSOptions(path=agentfs_dir / "bin.db"))

    # Mark agent as trashed (2 hours ago)
    await bin.kv.set("trashed:agent-123", str(time.time() - (2 * 3600)))

    # Create agent database
    agent_db = agentfs_dir / "agent-123.db"
    agent_db.touch()

    gc = WorkspaceGC(Path("/tmp/.cairn"), agentfs_dir, GCConfig(max_age_hours=1))

    # Run GC
    stats = await gc.run()

    assert stats.databases_removed >= 1
    assert not agent_db.exists()
```

---

### 3. Performance Optimization

**File**: `cairn/profiler.py`

**Requirements**:
Profile and optimize critical paths.

```python
import time
import functools
from typing import Any, Callable

class PerformanceProfiler:
    """Profile performance of operations"""

    def __init__(self):
        self.metrics: dict[str, list[float]] = {}

    def measure(self, operation: str):
        """Decorator to measure operation duration"""
        def decorator(func: Callable) -> Callable:
            @functools.wraps(func)
            async def wrapper(*args, **kwargs) -> Any:
                start = time.time()
                try:
                    return await func(*args, **kwargs)
                finally:
                    duration = (time.time() - start) * 1000  # ms

                    if operation not in self.metrics:
                        self.metrics[operation] = []
                    self.metrics[operation].append(duration)

            return wrapper
        return decorator

    def get_stats(self, operation: str) -> dict[str, float]:
        """Get statistics for operation"""
        durations = self.metrics.get(operation, [])
        if not durations:
            return {}

        return {
            "count": len(durations),
            "avg_ms": sum(durations) / len(durations),
            "min_ms": min(durations),
            "max_ms": max(durations),
            "p50_ms": sorted(durations)[len(durations) // 2],
            "p95_ms": sorted(durations)[int(len(durations) * 0.95)],
        }

    def report(self) -> str:
        """Generate performance report"""
        lines = ["Performance Report", "=" * 50, ""]

        for operation in sorted(self.metrics.keys()):
            stats = self.get_stats(operation)
            lines.append(f"{operation}:")
            lines.append(f"  Count: {stats['count']}")
            lines.append(f"  Avg:   {stats['avg_ms']:.2f}ms")
            lines.append(f"  Min:   {stats['min_ms']:.2f}ms")
            lines.append(f"  Max:   {stats['max_ms']:.2f}ms")
            lines.append(f"  P50:   {stats['p50_ms']:.2f}ms")
            lines.append(f"  P95:   {stats['p95_ms']:.2f}ms")
            lines.append("")

        return "\n".join(lines)
```

**Target Optimizations**:
1. Agent spawn < 1s
2. File sync < 10ms
3. Query operations < 50ms
4. Workspace materialize < 500ms
5. Accept/reject < 50ms
6. Preview open < 100ms

---

### 4. Nix Modules

**File**: `modules/agentfs.nix`

**Requirements**:
Nix module for AgentFS process.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.agentfs;
in {
  options.services.agentfs = {
    enable = mkEnableOption "AgentFS process";

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host to bind to";
    };

    port = mkOption {
      type = types.int;
      default = 8081;
      description = "Port to bind to";
    };

    dataDir = mkOption {
      type = types.str;
      default = ".devenv/state/agentfs";
      description = "Data directory for AgentFS databases";
    };
  };

  config = mkIf cfg.enable {
    env.AGENTFS_HOST = cfg.host;
    env.AGENTFS_PORT = toString cfg.port;
    env.AGENTFS_DATA_DIR = cfg.dataDir;

    packages = [
      pkgs.agentfs
    ];

    processes.agentfs = {
      exec = "agentfs serve --host ${cfg.host} --port ${toString cfg.port} --data-dir ${cfg.dataDir}";
    };

    scripts.agentfs-info.exec = ''
      echo "AgentFS Status"
      echo "============="
      echo "Host: ${cfg.host}"
      echo "Port: ${toString cfg.port}"
      echo "Data Dir: ${cfg.dataDir}"
      echo ""
      echo "Databases:"
      ls -lh ${cfg.dataDir}/*.db 2>/dev/null || echo "  (none)"
    '';
  };
}
```

**File**: `modules/cairn.nix`

**Requirements**:
Nix module for Cairn orchestrator.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cairn;
in {
  options.services.cairn = {
    enable = mkEnableOption "Cairn orchestrator";

    projectRoot = mkOption {
      type = types.str;
      default = ".";
      description = "Project root directory";
    };

    cairnHome = mkOption {
      type = types.str;
      default = "~/.cairn";
      description = "Cairn home directory";
    };

    maxConcurrentAgents = mkOption {
      type = types.int;
      default = 5;
      description = "Maximum concurrent agents";
    };

    llmModel = mkOption {
      type = types.str;
      default = "gpt-4";
      description = "LLM model to use";
    };

    jjIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Jujutsu integration";
    };
  };

  config = mkIf cfg.enable {
    env.CAIRN_HOME = cfg.cairnHome;
    env.CAIRN_MAX_CONCURRENT_AGENTS = toString cfg.maxConcurrentAgents;
    env.CAIRN_LLM_MODEL = cfg.llmModel;
    env.CAIRN_JJ_INTEGRATION = if cfg.jjIntegration then "1" else "0";

    packages = [
      pkgs.python311
      pkgs.tmux
      pkgs.neovim
    ] ++ optional cfg.jjIntegration pkgs.jujutsu;

    processes.cairn = {
      exec = "uv run python cairn/orchestrator.py --project-root ${cfg.projectRoot}";
    };

    scripts = {
      cairn-init.exec = ''
        echo "Initializing Cairn workspace..."
        mkdir -p ${cfg.cairnHome}/{workspaces,previews,signals,state,queue}
        echo "Cairn initialized at ${cfg.cairnHome}"
      '';

      cairn-queue.exec = ''
        task="$1"
        priority="''${2:-NORMAL}"
        echo "{\"task\": \"$task\", \"priority\": \"$priority\", \"created_at\": $(date +%s)}" >> ${cfg.cairnHome}/queue/tasks.json
        echo "Task queued: $task"
      '';

      cairn-accept.exec = ''
        agent_id=$(cat ${cfg.cairnHome}/state/latest_agent 2>/dev/null || echo "")
        if [ -z "$agent_id" ]; then
          echo "No agent to accept"
          exit 1
        fi
        touch ${cfg.cairnHome}/signals/accept-$agent_id
        echo "Accepting agent $agent_id"
      '';

      cairn-reject.exec = ''
        agent_id=$(cat ${cfg.cairnHome}/state/latest_agent 2>/dev/null || echo "")
        if [ -z "$agent_id" ]; then
          echo "No agent to reject"
          exit 1
        fi
        touch ${cfg.cairnHome}/signals/reject-$agent_id
        echo "Rejecting agent $agent_id"
      '';
    };
  };
}
```

---

### 5. Documentation

**Requirements**:
Complete and polish all documentation.

**Files to Update**:
- [ ] README.md - Complete overview, quick start, examples
- [ ] SPEC.md - Finalize technical spec with all implementation details
- [ ] CONCEPT.md - Ensure philosophy is clear
- [ ] AGENT.md - Complete development guidelines
- [ ] All SKILL-*.md files - Update with final patterns

**New Documentation**:
- [ ] DEPLOYMENT.md - How to deploy in production
- [ ] TROUBLESHOOTING.md - Common issues and solutions
- [ ] PERFORMANCE.md - Performance tuning guide
- [ ] CHANGELOG.md - Version history

---

### 6. Example Configurations

**Directory**: `examples/`

**Requirements**:
Provide working example configurations.

```
examples/
├── minimal/
│   ├── devenv.nix          # Minimal AgentFS only
│   └── README.md
├── full-cairn/
│   ├── devenv.nix          # Full Cairn setup
│   ├── .tmuxp.yaml         # TMUX layout
│   └── README.md
├── python-project/
│   ├── devenv.nix          # Python project with Cairn
│   ├── pyproject.toml
│   └── README.md
└── rust-project/
    ├── devenv.nix          # Rust project with Cairn
    ├── Cargo.toml
    └── README.md
```

---

## Test Suite Requirements

### Integration Tests (40% of tests)
- Test Jujutsu integration with real git repo
- Test GC with real workspaces
- Test Nix modules (in devenv shell)

### End-to-End Tests (40% of tests)
- Complete workflow: spawn → execute → review → accept
- Test with real LLM, real Neovim, real TMUX
- Performance benchmarks for all targets

### Stress Tests (20% of tests)
- 10+ concurrent agents
- Large files (100MB+)
- Large repositories (10,000+ files)
- Long-running agents (5+ minutes)

---

## Exit Criteria

### Functionality
- [ ] Jujutsu integration works (create, squash, abandon)
- [ ] GC runs automatically and cleans up old workspaces
- [ ] All performance targets met
- [ ] Nix modules work in real devenv projects
- [ ] All documentation complete

### Quality
- [ ] 85%+ overall test coverage
- [ ] All tests pass
- [ ] No known critical bugs
- [ ] Security audit complete

### Performance
- [ ] Agent spawn < 1s (average)
- [ ] File sync < 10ms (p95)
- [ ] Workspace materialize < 500ms (average)
- [ ] Accept/reject < 50ms (average)
- [ ] Preview open < 100ms (average)

### Documentation
- [ ] README clear and comprehensive
- [ ] All SKILL guides updated
- [ ] API documentation complete
- [ ] Example configurations work

### Production Readiness
- [ ] Error handling comprehensive
- [ ] Logging configured
- [ ] Monitoring hooks available
- [ ] Graceful shutdown
- [ ] Data backup/restore documented

---

## Success Metrics

At the end of Stage 5, the system should be:

1. **Production-ready**: Can be used in real projects without issues
2. **Performant**: All performance targets consistently met
3. **Reliable**: Handles errors gracefully, doesn't lose data
4. **Well-documented**: Anyone can install and use it
5. **Maintainable**: Code is clean, tested, documented

**Final validation**: Use Cairn to develop a real feature in a real project, from start to finish, with no major issues.

---

## Release Checklist

Before releasing v1.0:

### Code
- [ ] All stages (1-4) complete and working
- [ ] All Stage 5 deliverables complete
- [ ] No TODO comments in production code
- [ ] Code formatted and linted
- [ ] Type checking passes

### Testing
- [ ] All tests pass
- [ ] Coverage targets met
- [ ] Performance benchmarks met
- [ ] Security audit complete
- [ ] Manual testing complete

### Documentation
- [ ] README.md finalized
- [ ] CHANGELOG.md created
- [ ] All guides complete
- [ ] Examples work

### Deployment
- [ ] Nix modules tested
- [ ] PyPI package published (agentfs-pydantic)
- [ ] GitHub release created
- [ ] Documentation site deployed

### Community
- [ ] Announcement blog post written
- [ ] Demo video created
- [ ] Example projects published
- [ ] Community channels set up

---

**If all exit criteria are met, the project is ready for v1.0 release! 🎉**
