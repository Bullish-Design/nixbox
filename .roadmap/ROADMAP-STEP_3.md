# Stage 3: Orchestration Core

**Goal**: Complete agent lifecycle without UI (testable via CLI/API)

**Status**: ⚪ Not Started
**Estimated Duration**: 3-4 weeks
**Dependencies**: Stage 1 (agentfs-pydantic), Stage 2 (Monty execution)

---

## Overview

This stage implements the Cairn Orchestrator - the central process that manages agent lifecycles, watches for filesystem changes, handles accept/reject operations, and maintains the task queue. This is the "brain" of the system.

The key insight: **Build the orchestrator as a headless service first, testable via CLI commands. UI comes later.**

---

## Deliverables

### 1. Orchestrator Core

**File**: `cairn/orchestrator.py`

**Requirements**:
Main orchestrator class that coordinates all components.

```python
from pathlib import Path
import asyncio
from agentfs_sdk import AgentFS
from agentfs_pydantic import AgentFSOptions

class CairnOrchestrator:
    """Main orchestrator managing agent lifecycle"""

    def __init__(
        self,
        project_root: Path | str = ".",
        cairn_home: Path | str | None = None,
        config: OrchestratorConfig | None = None,
    ):
        self.project_root = Path(project_root)
        self.agentfs_dir = self.project_root / ".agentfs"
        self.cairn_home = Path(cairn_home or Path.home() / ".cairn")

        self.stable: AgentFS | None = None
        self.bin: AgentFS | None = None
        self.active_agents: dict[str, AgentContext] = {}
        self.queue: TaskQueue
        self.gc: WorkspaceGC
        self.llm: CodeGenerator
        self.executor: AgentExecutor

    async def initialize(self) -> None:
        """Initialize orchestrator (create directories, open databases)"""
        ...

    async def run(self) -> None:
        """Main event loop"""
        await asyncio.gather(
            self.watch_file_changes(),
            self.watch_signals(),
            self.auto_spawn_loop(),
            self.gc_loop(),
        )

    async def spawn_agent(self, task: str, priority: TaskPriority = TaskPriority.NORMAL) -> str:
        """Spawn new agent with task"""
        ...

    async def accept_agent(self, agent_id: str) -> None:
        """Accept agent changes and merge to stable"""
        ...

    async def reject_agent(self, agent_id: str) -> None:
        """Reject agent changes and cleanup"""
        ...

    async def trash_agent(self, agent_id: str) -> None:
        """Move agent to bin (for GC)"""
        ...
```

**Contracts**:
```python
# Contract 1: Initialize creates directories
async def test_initialize_creates_directories():
    project_root = Path("/tmp/test-project")
    orch = CairnOrchestrator(project_root)

    await orch.initialize()

    assert (project_root / ".agentfs").exists()
    assert (Path.home() / ".cairn" / "workspaces").exists()
    assert (Path.home() / ".cairn" / "signals").exists()
    assert (Path.home() / ".cairn" / "state").exists()

# Contract 2: Spawn agent creates overlay
async def test_spawn_agent_creates_overlay():
    orch = CairnOrchestrator("/tmp/test-project")
    await orch.initialize()

    agent_id = await orch.spawn_agent("Add docstrings")

    assert agent_id.startswith("agent-")
    assert agent_id in orch.active_agents
    assert (Path("/tmp/test-project/.agentfs") / f"{agent_id}.db").exists()

# Contract 3: Agent goes through lifecycle states
async def test_agent_lifecycle():
    orch = CairnOrchestrator("/tmp/test-project")
    await orch.initialize()

    agent_id = await orch.spawn_agent("Test task")

    # Initial state
    ctx = orch.active_agents[agent_id]
    assert ctx.state == AgentState.QUEUED

    # Wait for states to progress
    await asyncio.sleep(1)
    assert ctx.state in [AgentState.GENERATING, AgentState.EXECUTING, AgentState.SUBMITTING]

    # Eventually reaches REVIEWING
    while ctx.state != AgentState.REVIEWING:
        await asyncio.sleep(0.1)

    assert ctx.state == AgentState.REVIEWING

# Contract 4: Accept merges overlay to stable
async def test_accept_merges_to_stable():
    orch = CairnOrchestrator("/tmp/test-project")
    await orch.initialize()

    # Write to stable
    await orch.stable.fs.write_file("test.txt", b"original")

    # Spawn agent
    agent_id = await orch.spawn_agent("Modify test.txt")
    ctx = orch.active_agents[agent_id]

    # Wait for agent to finish
    while ctx.state != AgentState.REVIEWING:
        await asyncio.sleep(0.1)

    # Agent modified the file
    await ctx.agent_fs.fs.write_file("test.txt", b"modified")
    await ctx.agent_fs.kv.set(
        "submission",
        json.dumps({"summary": "Modified", "changed_files": ["test.txt"]})
    )

    # Accept
    await orch.accept_agent(agent_id)

    # Verify merged to stable
    content = await orch.stable.fs.read_file("test.txt")
    assert content == b"modified"

    # Agent should be trashed
    assert agent_id not in orch.active_agents

# Contract 5: Reject cleans up overlay
async def test_reject_cleans_up():
    orch = CairnOrchestrator("/tmp/test-project")
    await orch.initialize()

    agent_id = await orch.spawn_agent("Test task")

    # Wait for agent to finish
    ctx = orch.active_agents[agent_id]
    while ctx.state != AgentState.REVIEWING:
        await asyncio.sleep(0.1)

    # Reject
    await orch.reject_agent(agent_id)

    # Agent should be trashed
    assert agent_id not in orch.active_agents

# Contract 6: Multiple agents run concurrently
async def test_multiple_agents_concurrent():
    orch = CairnOrchestrator("/tmp/test-project")
    await orch.initialize()

    # Spawn 3 agents
    agent1 = await orch.spawn_agent("Task 1")
    agent2 = await orch.spawn_agent("Task 2")
    agent3 = await orch.spawn_agent("Task 3")

    # All should be active
    assert len(orch.active_agents) == 3
    assert agent1 in orch.active_agents
    assert agent2 in orch.active_agents
    assert agent3 in orch.active_agents

# Contract 7: Agents are isolated
async def test_agents_isolated():
    orch = CairnOrchestrator("/tmp/test-project")
    await orch.initialize()

    # Write to stable
    await orch.stable.fs.write_file("shared.txt", b"stable")

    # Spawn 2 agents
    agent1 = await orch.spawn_agent("Task 1")
    agent2 = await orch.spawn_agent("Task 2")

    ctx1 = orch.active_agents[agent1]
    ctx2 = orch.active_agents[agent2]

    # Each writes different content
    await ctx1.agent_fs.fs.write_file("shared.txt", b"agent1")
    await ctx2.agent_fs.fs.write_file("shared.txt", b"agent2")

    # Verify isolation
    content1 = await ctx1.agent_fs.fs.read_file("shared.txt")
    content2 = await ctx2.agent_fs.fs.read_file("shared.txt")
    stable_content = await orch.stable.fs.read_file("shared.txt")

    assert content1 == b"agent1"
    assert content2 == b"agent2"
    assert stable_content == b"stable"
```

---

### 2. Agent Lifecycle

**File**: `cairn/agent.py`

**Requirements**:
Define agent states and lifecycle transitions.

```python
from enum import Enum
from dataclasses import dataclass
from agentfs_sdk import AgentFS

class AgentState(Enum):
    """Agent lifecycle states"""
    QUEUED = "queued"
    SPAWNING = "spawning"
    GENERATING = "generating"
    EXECUTING = "executing"
    SUBMITTING = "submitting"
    REVIEWING = "reviewing"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    ERRORED = "errored"

@dataclass
class AgentContext:
    """Context for a running agent"""
    agent_id: str
    task: str
    priority: TaskPriority
    state: AgentState
    agent_fs: AgentFS
    generated_code: str | None = None
    execution_result: ExecutionResult | None = None
    submission: dict | None = None
    error: str | None = None
    created_at: float = 0.0
    state_changed_at: float = 0.0

    def transition(self, new_state: AgentState) -> None:
        """Transition to new state"""
        self.state = new_state
        self.state_changed_at = time.time()
```

**Contracts**:
```python
# Contract 1: Valid state transitions
def test_valid_state_transitions():
    ctx = AgentContext(agent_id="test", task="Test", priority=TaskPriority.NORMAL)

    # Valid progression
    ctx.transition(AgentState.SPAWNING)
    assert ctx.state == AgentState.SPAWNING

    ctx.transition(AgentState.GENERATING)
    assert ctx.state == AgentState.GENERATING

# Contract 2: State timestamp updated
def test_state_timestamp_updated():
    ctx = AgentContext(agent_id="test", task="Test", priority=TaskPriority.NORMAL)

    time1 = ctx.state_changed_at
    time.sleep(0.01)

    ctx.transition(AgentState.SPAWNING)
    time2 = ctx.state_changed_at

    assert time2 > time1
```

---

### 3. File Watching

**File**: `cairn/watcher.py`

**Requirements**:
Watch project files and sync changes to stable layer.

```python
from watchfiles import awatch, Change

class FileWatcher:
    """Watch filesystem and sync to stable layer"""

    def __init__(self, project_root: Path, stable: AgentFS):
        self.project_root = project_root
        self.stable = stable
        self.ignore_patterns = [".agentfs", ".git", ".jj", "__pycache__", "node_modules"]

    async def watch(self) -> None:
        """Watch for changes and sync to stable"""
        async for changes in awatch(self.project_root):
            for change_type, path_str in changes:
                await self.handle_change(change_type, Path(path_str))

    async def handle_change(self, change_type: Change, path: Path) -> None:
        """Handle a single file change"""
        ...

    def should_ignore(self, path: Path) -> bool:
        """Check if path should be ignored"""
        ...
```

**Contracts**:
```python
# Contract 1: File creation synced to stable
async def test_file_creation_synced():
    project_root = Path("/tmp/test-project")
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    watcher = FileWatcher(project_root, stable)

    # Start watcher in background
    watch_task = asyncio.create_task(watcher.watch())

    # Create file
    test_file = project_root / "new.txt"
    test_file.write_text("hello")

    # Wait for sync
    await asyncio.sleep(0.5)

    # Should be in stable
    content = await stable.fs.read_file("new.txt")
    assert content == b"hello"

    watch_task.cancel()

# Contract 2: File modification synced
async def test_file_modification_synced():
    # Similar to creation test...

# Contract 3: File deletion synced
async def test_file_deletion_synced():
    # Similar to creation test...

# Contract 4: Ignored patterns not synced
async def test_ignored_patterns():
    project_root = Path("/tmp/test-project")
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    watcher = FileWatcher(project_root, stable)

    watch_task = asyncio.create_task(watcher.watch())

    # Create ignored file
    git_file = project_root / ".git" / "config"
    git_file.parent.mkdir(exist_ok=True)
    git_file.write_text("ignored")

    await asyncio.sleep(0.5)

    # Should NOT be in stable
    with pytest.raises(FileNotFoundError):
        await stable.fs.read_file(".git/config")

    watch_task.cancel()

# Contract 5: Sync is fast (< 10ms latency)
async def test_sync_latency():
    project_root = Path("/tmp/test-project")
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    watcher = FileWatcher(project_root, stable)

    watch_task = asyncio.create_task(watcher.watch())

    test_file = project_root / "test.txt"

    start = time.time()
    test_file.write_text("hello")

    # Poll until synced
    while True:
        try:
            await stable.fs.read_file("test.txt")
            break
        except FileNotFoundError:
            await asyncio.sleep(0.001)

    latency = (time.time() - start) * 1000  # ms

    assert latency < 10, f"Sync latency {latency:.2f}ms exceeds 10ms target"

    watch_task.cancel()
```

---

### 4. Workspace Materialization

**File**: `cairn/workspace.py`

**Requirements**:
Materialize agent overlays to disk for preview.

```python
class WorkspaceMaterializer:
    """Materialize agent workspaces to disk"""

    def __init__(self, cairn_home: Path):
        self.workspace_dir = cairn_home / "workspaces"

    async def materialize(self, agent_id: str, agent_fs: AgentFS) -> Path:
        """Copy agent overlay to disk"""
        workspace = self.workspace_dir / agent_id

        # Clear existing
        if workspace.exists():
            shutil.rmtree(workspace)
        workspace.mkdir(parents=True)

        # Copy all files
        await self._copy_recursive(agent_fs, "/", workspace)

        return workspace

    async def _copy_recursive(
        self,
        agent_fs: AgentFS,
        src_path: str,
        dest_path: Path
    ) -> None:
        """Recursively copy files from AgentFS to disk"""
        ...

    async def cleanup(self, agent_id: str) -> None:
        """Remove materialized workspace"""
        ...
```

**Contracts**:
```python
# Contract 1: Materialize creates workspace directory
async def test_materialize_creates_workspace():
    cairn_home = Path("/tmp/.cairn")
    materializer = WorkspaceMaterializer(cairn_home)

    agent_fs = await AgentFS.open(AgentFSOptions(id="test-agent"))
    await agent_fs.fs.write_file("test.txt", b"hello")

    workspace = await materializer.materialize("test-agent", agent_fs)

    assert workspace.exists()
    assert (workspace / "test.txt").exists()
    assert (workspace / "test.txt").read_text() == "hello"

# Contract 2: Materialize handles nested directories
async def test_materialize_nested_directories():
    cairn_home = Path("/tmp/.cairn")
    materializer = WorkspaceMaterializer(cairn_home)

    agent_fs = await AgentFS.open(AgentFSOptions(id="test-agent"))
    await agent_fs.fs.mkdir("src")
    await agent_fs.fs.write_file("src/main.py", b"print('hello')")

    workspace = await materializer.materialize("test-agent", agent_fs)

    assert (workspace / "src" / "main.py").exists()

# Contract 3: Materialize is fast (< 500ms for 100 files)
async def test_materialize_performance():
    cairn_home = Path("/tmp/.cairn")
    materializer = WorkspaceMaterializer(cairn_home)

    agent_fs = await AgentFS.open(AgentFSOptions(id="test-agent"))

    # Create 100 files
    for i in range(100):
        await agent_fs.fs.write_file(f"file_{i}.txt", b"content")

    start = time.time()
    workspace = await materializer.materialize("test-agent", agent_fs)
    duration = (time.time() - start) * 1000

    assert duration < 500, f"Materialization took {duration:.2f}ms"
    assert len(list(workspace.glob("*.txt"))) == 100

# Contract 4: Cleanup removes workspace
async def test_cleanup_removes_workspace():
    cairn_home = Path("/tmp/.cairn")
    materializer = WorkspaceMaterializer(cairn_home)

    # Create workspace
    workspace = cairn_home / "workspaces" / "test-agent"
    workspace.mkdir(parents=True)
    (workspace / "test.txt").write_text("hello")

    # Cleanup
    await materializer.cleanup("test-agent")

    assert not workspace.exists()
```

---

### 5. Task Queue

**File**: `cairn/queue.py`

**Requirements**:
Priority queue for agent tasks.

```python
from enum import Enum
from dataclasses import dataclass
import asyncio

class TaskPriority(Enum):
    LOW = 1
    NORMAL = 2
    HIGH = 3
    URGENT = 4

@dataclass
class QueuedTask:
    task: str
    priority: TaskPriority
    created_at: float

class TaskQueue:
    """Priority queue for agent tasks"""

    def __init__(self, max_concurrent: int = 5):
        self.max_concurrent = max_concurrent
        self.queue: list[QueuedTask] = []
        self.active_count = 0

    async def enqueue(self, task: str, priority: TaskPriority = TaskPriority.NORMAL) -> None:
        """Add task to queue"""
        ...

    async def dequeue(self) -> QueuedTask | None:
        """Get next task (None if queue empty or at max concurrency)"""
        ...

    def size(self) -> int:
        """Get queue size"""
        ...
```

**Contracts**:
```python
# Contract 1: Higher priority tasks dequeued first
async def test_priority_ordering():
    queue = TaskQueue()

    await queue.enqueue("Low task", TaskPriority.LOW)
    await queue.enqueue("High task", TaskPriority.HIGH)
    await queue.enqueue("Normal task", TaskPriority.NORMAL)

    task1 = await queue.dequeue()
    task2 = await queue.dequeue()
    task3 = await queue.dequeue()

    assert task1.priority == TaskPriority.HIGH
    assert task2.priority == TaskPriority.NORMAL
    assert task3.priority == TaskPriority.LOW

# Contract 2: Max concurrency enforced
async def test_max_concurrency():
    queue = TaskQueue(max_concurrent=2)

    await queue.enqueue("Task 1")
    await queue.enqueue("Task 2")
    await queue.enqueue("Task 3")

    task1 = await queue.dequeue()
    task2 = await queue.dequeue()
    task3 = await queue.dequeue()

    assert task1 is not None
    assert task2 is not None
    assert task3 is None  # At max concurrency

# Contract 3: Active count updated
async def test_active_count():
    queue = TaskQueue()

    await queue.enqueue("Task 1")
    task = await queue.dequeue()

    assert queue.active_count == 1

    queue.mark_complete(task)
    assert queue.active_count == 0
```

---

### 6. Signal Handling

**File**: `cairn/signals.py`

**Requirements**:
Watch for accept/reject signal files from Neovim.

```python
class SignalHandler:
    """Handle accept/reject signals"""

    def __init__(self, cairn_home: Path, orchestrator: CairnOrchestrator):
        self.signals_dir = cairn_home / "signals"
        self.orchestrator = orchestrator

    async def watch(self) -> None:
        """Poll for signal files"""
        while True:
            await asyncio.sleep(0.5)  # Check every 500ms

            # Accept signals
            for signal_file in self.signals_dir.glob("accept-*"):
                agent_id = signal_file.stem.replace("accept-", "")
                try:
                    await self.orchestrator.accept_agent(agent_id)
                finally:
                    signal_file.unlink()

            # Reject signals
            for signal_file in self.signals_dir.glob("reject-*"):
                agent_id = signal_file.stem.replace("reject-", "")
                try:
                    await self.orchestrator.reject_agent(agent_id)
                finally:
                    signal_file.unlink()
```

**Contracts**:
```python
# Contract 1: Accept signal triggers accept
async def test_accept_signal():
    cairn_home = Path("/tmp/.cairn")
    orch = CairnOrchestrator()
    handler = SignalHandler(cairn_home, orch)

    # Create signal file
    signals_dir = cairn_home / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    (signals_dir / "accept-agent123").touch()

    # Start handler
    watch_task = asyncio.create_task(handler.watch())

    # Wait for processing
    await asyncio.sleep(1)

    # Signal file should be removed
    assert not (signals_dir / "accept-agent123").exists()

    watch_task.cancel()

# Contract 2: Reject signal triggers reject
async def test_reject_signal():
    # Similar to accept test...
```

---

## Test Suite Requirements

### Unit Tests (60% of tests)
- Test orchestrator methods in isolation
- Test agent lifecycle transitions
- Test queue operations
- Test watcher logic
- Mock AgentFS and LLM

### Integration Tests (30% of tests)
- Test full agent spawn → execute → submit flow
- Test file watching with real filesystem
- Test workspace materialization
- Test signal handling
- Test multiple concurrent agents

### End-to-End Tests (10% of tests)
- Test complete workflow: spawn agent, wait for submission, accept
- Test with real AgentFS databases
- Test with real filesystem watching

---

## Exit Criteria

### Functionality
- [ ] Can spawn agent via CLI: `cairn spawn "Add docstrings"`
- [ ] Agent executes and reaches REVIEWING state
- [ ] File changes sync to stable.db within 10ms
- [ ] Accept merges overlay to stable correctly
- [ ] Reject cleans up overlay
- [ ] Multiple agents (3+) run concurrently without issues

### Testing
- [ ] 90%+ test coverage
- [ ] All contracts verified
- [ ] Stress test: 10 concurrent agents
- [ ] Performance: All targets met

### Performance
- [ ] Agent spawn < 1s
- [ ] File sync < 10ms
- [ ] Workspace materialize < 500ms
- [ ] Accept/reject < 50ms

### Documentation
- [ ] Orchestrator architecture documented
- [ ] CLI usage documented
- [ ] State machine diagram
- [ ] Example workflows

---

## Success Metrics

At the end of Stage 3, we should be able to (via CLI):

1. **Start orchestrator**: `cairn up`
2. **Queue task**: `cairn queue "Add docstrings to all functions"`
3. **List agents**: `cairn list-agents`
4. **Check status**: `cairn status agent-abc123`
5. **Accept changes**: `cairn accept agent-abc123`
6. **Reject changes**: `cairn reject agent-abc123`

**The orchestrator should work completely headlessly, testable without Neovim.**

**If all exit criteria are met, proceed to Stage 4.**
