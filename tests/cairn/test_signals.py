"""Stage 3 integration tests for signal processing semantics."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import pytest

from cairn.commands import CommandType
from cairn.queue import TaskPriority
from cairn.signals import SignalHandler


class StubOrchestrator:
    def __init__(self) -> None:
        self.commands: list[tuple[CommandType, str | None, str | None, TaskPriority | None]] = []

    async def submit_command(self, command) -> object:
        self.commands.append((command.type, command.agent_id, command.task, command.priority))
        return object()


async def _run_watcher_once(handler: SignalHandler) -> None:
    task = asyncio.create_task(handler.watch())
    await asyncio.sleep(0.7)
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task


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

    await _run_watcher_once(handler)

    assert orch.commands == [(CommandType.QUEUE, None, "Add docs", TaskPriority.HIGH)]
    assert not (signals_dir / "spawn-1.json").exists()


@pytest.mark.asyncio
async def test_accept_and_reject_signals_dispatch_and_cleanup(tmp_path: Path) -> None:
    orch = StubOrchestrator()
    handler = SignalHandler(tmp_path, orch)
    signals_dir = tmp_path / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    (signals_dir / "accept-agent-a.json").write_text(json.dumps({"agent_id": "agent-a"}), encoding="utf-8")
    (signals_dir / "reject-agent-b.json").write_text(json.dumps({"agent_id": "agent-b"}), encoding="utf-8")

    await _run_watcher_once(handler)

    assert orch.commands == [
        (CommandType.ACCEPT, "agent-a", None, None),
        (CommandType.REJECT, "agent-b", None, None),
    ]
    assert not (signals_dir / "accept-agent-a.json").exists()
    assert not (signals_dir / "reject-agent-b.json").exists()


@pytest.mark.asyncio
async def test_queue_signal_uses_default_priority_when_omitted(tmp_path: Path) -> None:
    orch = StubOrchestrator()
    handler = SignalHandler(tmp_path, orch)
    signals_dir = tmp_path / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    (signals_dir / "queue-1.json").write_text(json.dumps({"task": "Backlog task"}), encoding="utf-8")

    await _run_watcher_once(handler)

    assert orch.commands == [(CommandType.QUEUE, None, "Backlog task", TaskPriority.NORMAL)]
