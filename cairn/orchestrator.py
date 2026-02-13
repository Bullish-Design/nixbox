"""Core Cairn orchestrator for agent lifecycle management."""

from __future__ import annotations

import asyncio
import json
import shutil
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

from agentfs_pydantic import AgentFSOptions
from agentfs_sdk import AgentFS

from cairn.agent import AgentContext, AgentState
from cairn.code_generator import CodeGenerator
from cairn.executor import AgentExecutor
from cairn.external_functions import create_external_functions
from cairn.queue import TaskPriority, TaskQueue
from cairn.signals import SignalHandler
from cairn.watcher import FileWatcher
from cairn.workspace import WorkspaceMaterializer


@dataclass
class OrchestratorConfig:
    """Runtime configuration for orchestrator services."""

    max_concurrent_agents: int = 5


class CairnOrchestrator:
    """Main orchestrator managing agent lifecycle."""

    def __init__(
        self,
        project_root: Path | str = ".",
        cairn_home: Path | str | None = None,
        config: OrchestratorConfig | None = None,
        code_generator: CodeGenerator | None = None,
        executor: AgentExecutor | None = None,
        external_functions_factory: Callable[[str, AgentFS, AgentFS, Any], dict[str, Any]]
        | None = None,
    ):
        self.project_root = Path(project_root).resolve()
        self.agentfs_dir = self.project_root / ".agentfs"
        self.cairn_home = Path(cairn_home or Path.home() / ".cairn").expanduser()
        self.config = config or OrchestratorConfig()

        self.stable: AgentFS | None = None
        self.bin: AgentFS | None = None
        self.active_agents: dict[str, AgentContext] = {}
        self.queue = TaskQueue()
        self._worker_task: asyncio.Task[None] | None = None
        self._semaphore = asyncio.Semaphore(self.config.max_concurrent_agents)
        self._running_tasks: set[asyncio.Task[None]] = set()

        self.llm = code_generator or CodeGenerator()
        self.executor = executor or AgentExecutor()
        self.external_functions_factory = external_functions_factory or create_external_functions

        self.watcher: FileWatcher | None = None
        self.signals: SignalHandler | None = None
        self.materializer: WorkspaceMaterializer | None = None
        self.state_file = self.cairn_home / "state" / "orchestrator.json"

    async def initialize(self) -> None:
        """Initialize orchestrator directories and AgentFS instances."""
        self.agentfs_dir.mkdir(parents=True, exist_ok=True)
        for directory in ("workspaces", "signals", "state"):
            (self.cairn_home / directory).mkdir(parents=True, exist_ok=True)

        self.stable = await AgentFS.open(
            AgentFSOptions(path=str(self.agentfs_dir / "stable.db")).model_dump()
        )
        self.bin = await AgentFS.open(
            AgentFSOptions(path=str(self.agentfs_dir / "bin.db")).model_dump()
        )

        self.watcher = FileWatcher(self.project_root, self.stable)
        self.signals = SignalHandler(self.cairn_home, self)
        self.materializer = WorkspaceMaterializer(self.cairn_home, stable_fs=self.stable)
        if self._worker_task is None or self._worker_task.done():
            self._worker_task = asyncio.create_task(self._worker_loop())
        await self.persist_state()

    async def run(self) -> None:
        """Run orchestrator service loops."""
        if self.watcher is None or self.signals is None:
            await self.initialize()

        assert self.watcher is not None
        assert self.signals is not None

        await asyncio.gather(
            self.watcher.watch(),
            self.signals.watch(),
        )

    async def spawn_agent(
        self,
        task: str,
        priority: TaskPriority = TaskPriority.NORMAL,
    ) -> str:
        """Spawn and enqueue a new agent task."""
        if self.stable is None:
            raise RuntimeError("Orchestrator not initialized")

        agent_id = f"agent-{uuid.uuid4().hex[:8]}"
        agent_db = self.agentfs_dir / f"{agent_id}.db"
        agent_fs = await AgentFS.open(AgentFSOptions(path=str(agent_db)).model_dump())

        ctx = AgentContext(
            agent_id=agent_id,
            task=task,
            priority=priority,
            state=AgentState.QUEUED,
            agent_fs=agent_fs,
        )
        self.active_agents[agent_id] = ctx

        await self.queue.enqueue(agent_id, priority)
        await self.persist_state()
        return agent_id

    async def accept_agent(self, agent_id: str) -> None:
        """Accept agent changes and merge overlay content into stable."""
        ctx = self._get_agent(agent_id)
        ctx.transition(AgentState.ACCEPTED)

        if self.stable is None:
            raise RuntimeError("Stable AgentFS not initialized")

        await self._merge_overlay_to_stable(ctx.agent_fs, self.stable)
        await self.trash_agent(agent_id)
        await self.persist_state()

    async def reject_agent(self, agent_id: str) -> None:
        """Reject agent changes and cleanup overlay."""
        ctx = self._get_agent(agent_id)
        ctx.transition(AgentState.REJECTED)
        await self.trash_agent(agent_id)
        await self.persist_state()

    async def trash_agent(self, agent_id: str) -> None:
        """Move agent to bin metadata and cleanup runtime artifacts."""
        ctx = self._get_agent(agent_id)
        if self.bin is not None:
            await self.bin.kv.set(
                f"agent:{agent_id}",
                json.dumps(
                    {
                        "agent_id": agent_id,
                        "task": ctx.task,
                        "final_state": ctx.state.value,
                        "trashed_at": time.time(),
                    }
                ),
            )

        if self.materializer is not None:
            await self.materializer.cleanup(agent_id)

        await ctx.agent_fs.close()

        agent_db = self.agentfs_dir / f"{agent_id}.db"
        if agent_db.exists():
            bin_copy = self.agentfs_dir / f"bin-{agent_id}.db"
            shutil.move(agent_db, bin_copy)

        self.active_agents.pop(agent_id, None)
        await self.persist_state()

    async def _worker_loop(self) -> None:
        """Continuously dispatch queued tasks through a semaphore-gated runner."""
        while True:
            queued = await self.queue.dequeue_wait()
            agent_id = queued.task
            await self._semaphore.acquire()
            task = asyncio.create_task(self._run_agent(agent_id))
            self._running_tasks.add(task)
            task.add_done_callback(self._running_tasks.discard)

    async def _run_agent(self, agent_id: str) -> None:
        """Run one agent through generation/execution/submission lifecycle."""
        ctx = self.active_agents.get(agent_id)

        try:
            if ctx is None:
                return

            async def transition(new_state: AgentState) -> None:
                ctx.transition(new_state)
                await self.persist_state()

            await transition(AgentState.SPAWNING)
            await transition(AgentState.GENERATING)
            generated = await self.llm.generate(ctx.task)
            ctx.generated_code = generated

            is_valid, error = self.executor.validate_code(generated)
            if not is_valid:
                raise RuntimeError(error or "generated code failed validation")

            if self.stable is None:
                raise RuntimeError("Stable AgentFS not initialized")

            await transition(AgentState.EXECUTING)
            functions = self.external_functions_factory(agent_id, ctx.agent_fs, self.stable, self.llm)
            execution_result = await self.executor.execute(generated, functions, agent_id)
            ctx.execution_result = execution_result
            if execution_result.failed:
                raise RuntimeError(execution_result.error or "execution failed")

            await transition(AgentState.SUBMITTING)
            submission_raw = await ctx.agent_fs.kv.get("submission")
            if submission_raw:
                ctx.submission = json.loads(submission_raw)

            if self.materializer is not None:
                await self.materializer.materialize(agent_id, ctx.agent_fs)

            await transition(AgentState.REVIEWING)
        except Exception as exc:
            ctx.error = str(exc)
            await transition(AgentState.ERRORED)
        finally:
            self._semaphore.release()
            await self.persist_state()

    async def persist_state(self) -> None:
        """Persist a JSON snapshot used by CLI consumers."""
        state_dir = self.state_file.parent
        state_dir.mkdir(parents=True, exist_ok=True)

        payload = {
            "project_root": str(self.project_root),
            "updated_at": time.time(),
            "queue": {
                "pending": self.queue.size(),
                "running": sum(
                    1
                    for ctx in self.active_agents.values()
                    if ctx.state
                    in {
                        AgentState.SPAWNING,
                        AgentState.GENERATING,
                        AgentState.EXECUTING,
                        AgentState.SUBMITTING,
                    }
                ),
            },
            "agents": {
                agent_id: {
                    "agent_id": ctx.agent_id,
                    "task": ctx.task,
                    "priority": int(ctx.priority),
                    "state": ctx.state.value,
                    "created_at": ctx.created_at,
                    "state_changed_at": ctx.state_changed_at,
                    "submission": ctx.submission,
                    "error": ctx.error,
                }
                for agent_id, ctx in self.active_agents.items()
            },
        }
        self.state_file.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

    def _get_agent(self, agent_id: str) -> AgentContext:
        ctx = self.active_agents.get(agent_id)
        if ctx is None:
            raise KeyError(f"Unknown agent_id: {agent_id}")
        return ctx

    async def _merge_overlay_to_stable(self, source: AgentFS, target: AgentFS, src_path: str = "/") -> None:
        """Copy source overlay files into stable AgentFS recursively."""
        for base in (src_path, src_path.lstrip("/") or "."):
            try:
                entries = await source.fs.readdir(base)
                break
            except FileNotFoundError:
                entries = []
        for entry in entries:
            name = getattr(entry, "name", None)
            if not name:
                continue

            source_child = f"{src_path.rstrip('/')}/{name}" if src_path != "/" else f"/{name}"
            source_child_rel = source_child.lstrip("/")
            if self._is_directory_entry(entry):
                await self._merge_overlay_to_stable(source, target, source_child)
                continue

            file_bytes = await source.fs.read_file(source_child)
            await target.fs.write_file(source_child_rel, file_bytes)

    def _is_directory_entry(self, entry: Any) -> bool:
        entry_type = getattr(entry, "type", None)
        return bool(
            entry_type == "directory"
            or entry_type == "dir"
            or getattr(entry, "is_directory", False)
            or getattr(entry, "is_dir", False)
        )
