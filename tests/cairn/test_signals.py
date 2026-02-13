"""Tests for signal polling and dispatch behavior."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import pytest

from cairn.queue import TaskPriority
from cairn.signals import SignalHandler


class StubOrchestrator:
    def __init__(self) -> None:
        self.spawns: list[tuple[str, TaskPriority]] = []

    async def spawn_agent(self, task: str, priority: TaskPriority) -> str:
        self.spawns.append((task, priority))
        return "agent-test"

    async def accept_agent(self, agent_id: str) -> None:  # pragma: no cover - not used
        return None

    async def reject_agent(self, agent_id: str) -> None:  # pragma: no cover - not used
        return None


@pytest.mark.asyncio
async def test_spawn_signal_triggers_spawn(tmp_path: Path) -> None:
    orch = StubOrchestrator()
    handler = SignalHandler(tmp_path, orch)
    signals_dir = tmp_path / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    (signals_dir / "spawn-1.json").write_text(
        json.dumps({"task": "Add docs", "priority": int(TaskPriority.HIGH)}),
        encoding="utf-8",
    )

    task = asyncio.create_task(handler.watch())
    await asyncio.sleep(0.7)
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task

    assert orch.spawns == [("Add docs", TaskPriority.HIGH)]
    assert not (signals_dir / "spawn-1.json").exists()
