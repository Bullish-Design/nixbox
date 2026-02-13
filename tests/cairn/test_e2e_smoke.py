"""Optional Stage 3 smoke test for spawn -> reviewing -> accept/reject flow."""

from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Any

import pytest

from cairn.agent import AgentState
from cairn.executor import ExecutionResult
from cairn.orchestrator import CairnOrchestrator


class FakeCodeGenerator:
    async def generate(self, task: str) -> str:
        return f"# generated for {task}"


class FakeExecutor:
    def validate_code(self, code: str) -> tuple[bool, str | None]:
        return True, None

    async def execute(self, code: str, external_functions: dict[str, Any], agent_id: str) -> ExecutionResult:
        return ExecutionResult(success=True, return_value=True, agent_id=agent_id)


async def _wait_for_state(orch: CairnOrchestrator, agent_id: str, state: AgentState) -> None:
    async with asyncio.timeout(2):
        while orch.active_agents[agent_id].state != state:
            await asyncio.sleep(0.02)


@pytest.mark.asyncio
async def test_e2e_smoke_spawn_review_accept_reject(tmp_path: Path) -> None:
    orch = CairnOrchestrator(
        project_root=tmp_path,
        cairn_home=tmp_path / ".cairn",
        code_generator=FakeCodeGenerator(),
        executor=FakeExecutor(),
    )
    await orch.initialize()

    accept_id = await orch.spawn_agent("accept flow")
    reject_id = await orch.spawn_agent("reject flow")

    await _wait_for_state(orch, accept_id, AgentState.REVIEWING)
    await _wait_for_state(orch, reject_id, AgentState.REVIEWING)

    await orch.accept_agent(accept_id)
    await orch.reject_agent(reject_id)

    assert accept_id not in orch.active_agents
    assert reject_id not in orch.active_agents
