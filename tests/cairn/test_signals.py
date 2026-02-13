"""Stage 3 integration tests for signal processing semantics."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import pytest

from cairn.commands import CairnCommand, CommandType, parse_command_payload
from cairn.queue import TaskPriority
from cairn.signals import SignalHandler


class StubOrchestrator:
    def __init__(self) -> None:
        self.commands: list[CairnCommand] = []

    async def submit_command(self, command: CairnCommand) -> object:
        self.commands.append(command)
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

    assert orch.commands == [parse_command_payload("spawn", {"task": "Add docs", "priority": int(TaskPriority.HIGH)})]
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
        parse_command_payload(CommandType.ACCEPT, {"agent_id": "agent-a"}),
        parse_command_payload(CommandType.REJECT, {"agent_id": "agent-b"}),
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

    assert orch.commands == [parse_command_payload("queue", {"task": "Backlog task"})]


@pytest.mark.asyncio
async def test_signal_file_with_type_payload_dispatches_independent_of_filename(tmp_path: Path) -> None:
    orch = StubOrchestrator()
    handler = SignalHandler(tmp_path, orch)
    signals_dir = tmp_path / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    (signals_dir / "custom-command.json").write_text(
        json.dumps({"type": "queue", "task": "Typed queue"}),
        encoding="utf-8",
    )

    await handler.process_signals_once()

    assert orch.commands == [parse_command_payload("queue", {"task": "Typed queue"})]
    assert not (signals_dir / "custom-command.json").exists()


@pytest.mark.asyncio
async def test_cli_and_signal_adapters_emit_equivalent_cairn_command(tmp_path: Path) -> None:
    signals_dir = tmp_path / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    signal_file = signals_dir / "spawn-equivalent.json"
    signal_file.write_text(json.dumps({"task": "equivalent task"}), encoding="utf-8")

    handler = SignalHandler(tmp_path, StubOrchestrator())
    signal_command = handler._parse_signal_file(signal_file)

    assert signal_command == parse_command_payload("spawn", {"task": "equivalent task", "priority": int(TaskPriority.HIGH)})


@pytest.mark.asyncio
async def test_polling_can_be_disabled_without_changing_command_semantics(tmp_path: Path) -> None:
    orch = StubOrchestrator()
    handler = SignalHandler(tmp_path, orch, enable_polling=False)
    signals_dir = tmp_path / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    signal_file = signals_dir / "spawn-compat.json"
    signal_file.write_text(json.dumps({"task": "manual process"}), encoding="utf-8")

    parsed_before_watch = handler._parse_signal_file(signal_file)

    await handler.watch()
    assert orch.commands == []
    assert signal_file.exists()

    await handler.process_signals_once()

    assert parsed_before_watch == parse_command_payload("spawn", {"task": "manual process", "priority": int(TaskPriority.HIGH)})
    assert orch.commands == [parsed_before_watch]
    assert not signal_file.exists()
