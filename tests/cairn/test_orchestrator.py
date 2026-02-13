"""Stage 3 integration tests for Cairn orchestrator lifecycle contracts."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Any

import pytest

from cairn.agent import AgentState
from cairn.executor import ExecutionResult
from cairn.orchestrator import CairnOrchestrator, OrchestratorConfig
from cairn.queue import TaskPriority


class FakeCodeGenerator:
    async def generate(self, task: str) -> str:
        await asyncio.sleep(0.01)
        return f"# generated for: {task}"


class FakeExecutor:
    def validate_code(self, code: str) -> tuple[bool, str | None]:
        return True, None

    async def execute(self, code: str, external_functions: dict[str, Any], agent_id: str) -> ExecutionResult:
        await asyncio.sleep(0.01)
        return ExecutionResult(success=True, return_value=True, agent_id=agent_id)


class BlockingExecutor(FakeExecutor):
    def __init__(self) -> None:
        self.started = asyncio.Event()
        self.release = asyncio.Event()

    async def execute(self, code: str, external_functions: dict[str, Any], agent_id: str) -> ExecutionResult:
        self.started.set()
        await self.release.wait()
        return await super().execute(code, external_functions, agent_id)


async def _wait_for_state(orch: CairnOrchestrator, agent_id: str, state: AgentState, timeout: float = 2.0) -> None:
    async with asyncio.timeout(timeout):
        while orch.active_agents[agent_id].state != state:
            await asyncio.sleep(0.02)


@pytest.mark.asyncio
async def test_initialize_creates_directories(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )

    await orch.initialize()

    assert (tmp_path / ".agentfs").exists()
    assert (tmp_path / ".cairn" / "workspaces").exists()
    assert (tmp_path / ".cairn" / "signals").exists()
    assert (tmp_path / ".cairn" / "state").exists()


@pytest.mark.asyncio
async def test_spawn_agent_creates_overlay_and_tracks_active_agent(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()

    agent_id = await orch.spawn_agent("Add docstrings")

    assert agent_id.startswith("agent-")
    assert agent_id in orch.active_agents
    assert (tmp_path / ".agentfs" / f"{agent_id}.db").exists()


@pytest.mark.asyncio
async def test_agent_lifecycle_reaches_reviewing(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()

    agent_id = await orch.spawn_agent("Test task")

    assert orch.active_agents[agent_id].state in {AgentState.QUEUED, AgentState.SPAWNING, AgentState.GENERATING}
    await _wait_for_state(orch, agent_id, AgentState.REVIEWING)

    assert orch.active_agents[agent_id].state == AgentState.REVIEWING


@pytest.mark.asyncio
async def test_accept_merges_overlay_to_stable_and_cleans_agent(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()
    assert orch.stable is not None

    await orch.stable.fs.write_file("test.txt", b"original")
    agent_id = await orch.spawn_agent("Modify test.txt")
    await _wait_for_state(orch, agent_id, AgentState.REVIEWING)

    await orch.active_agents[agent_id].agent_fs.fs.write_file("test.txt", b"modified")
    await orch.active_agents[agent_id].agent_fs.kv.set(
        "submission",
        json.dumps({"summary": "Modified", "changed_files": ["test.txt"]}),
    )

    await orch.accept_agent(agent_id)

    assert await orch.stable.fs.read_file("test.txt") == b"modified"
    assert agent_id not in orch.active_agents


@pytest.mark.asyncio
async def test_reject_removes_agent_without_merging_overlay(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()
    assert orch.stable is not None

    await orch.stable.fs.write_file("test.txt", b"stable")
    agent_id = await orch.spawn_agent("Try changes")
    await _wait_for_state(orch, agent_id, AgentState.REVIEWING)

    await orch.active_agents[agent_id].agent_fs.fs.write_file("test.txt", b"overlay")
    await orch.reject_agent(agent_id)

    assert await orch.stable.fs.read_file("test.txt") == b"stable"
    assert agent_id not in orch.active_agents


@pytest.mark.asyncio
async def test_multiple_agents_spawn_concurrently(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()

    agent_ids = [await orch.spawn_agent(f"Task {idx}") for idx in range(3)]
    for agent_id in agent_ids:
        await _wait_for_state(orch, agent_id, AgentState.REVIEWING)

    assert len(orch.active_agents) == 3
    assert set(agent_ids) == set(orch.active_agents)


@pytest.mark.asyncio
async def test_agents_are_isolated_until_accept(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()
    assert orch.stable is not None

    await orch.stable.fs.write_file("shared.txt", b"stable")

    agent1 = await orch.spawn_agent("Task 1")
    agent2 = await orch.spawn_agent("Task 2")
    await _wait_for_state(orch, agent1, AgentState.REVIEWING)
    await _wait_for_state(orch, agent2, AgentState.REVIEWING)

    await orch.active_agents[agent1].agent_fs.fs.write_file("shared.txt", b"agent1")
    await orch.active_agents[agent2].agent_fs.fs.write_file("shared.txt", b"agent2")

    assert await orch.active_agents[agent1].agent_fs.fs.read_file("shared.txt") == b"agent1"
    assert await orch.active_agents[agent2].agent_fs.fs.read_file("shared.txt") == b"agent2"
    assert await orch.stable.fs.read_file("shared.txt") == b"stable"


@pytest.mark.asyncio
async def test_concurrency_gate_keeps_second_agent_queued_until_slot_is_free(tmp_path: Path) -> None:
    executor = BlockingExecutor()
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        config=OrchestratorConfig(max_concurrent_agents=1),
        code_generator=FakeCodeGenerator(),
        executor=executor,
    )
    await orch.initialize()

    agent1 = await orch.spawn_agent("Long task")
    await executor.started.wait()
    agent2 = await orch.spawn_agent("Queued task", priority=TaskPriority.HIGH)

    await asyncio.sleep(0.05)
    assert orch.active_agents[agent2].state == AgentState.QUEUED

    executor.release.set()
    await _wait_for_state(orch, agent1, AgentState.REVIEWING)
    await _wait_for_state(orch, agent2, AgentState.REVIEWING)
