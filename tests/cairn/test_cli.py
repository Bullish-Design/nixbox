"""Tests for Cairn CLI command surface and command dispatch integration."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from cairn.cli import main
from cairn.commands import CommandType, parse_command_payload
from cairn.queue import TaskPriority


def test_spawn_command_dispatches_and_prints(tmp_path: Path, capsys) -> None:
    exit_code = main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "spawn", "Add docs"])

    assert exit_code == 0
    out = capsys.readouterr().out
    assert "queued spawn request" in out


def test_accept_command_dispatches_and_prints(tmp_path: Path, capsys) -> None:
    main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "spawn", "Do thing"])
    capsys.readouterr()

    exit_code = main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "list-agents"])

    assert exit_code == 0
    list_out = capsys.readouterr().out
    agent_id = list_out.splitlines()[0].split("\t")[0]

    accept_exit = main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "accept", agent_id])
    assert accept_exit == 0
    out = capsys.readouterr().out
    assert f"queued accept for {agent_id}" in out


def test_status_command_returns_command_payload(tmp_path: Path, capsys) -> None:
    main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "spawn", "Do thing"])
    capsys.readouterr()

    main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "list-agents"])
    list_output = capsys.readouterr().out
    agent_id = list_output.splitlines()[0].split("\t")[0]

    exit_code = main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "status", agent_id])

    assert exit_code == 0
    out = capsys.readouterr().out
    payload = json.loads(out)
    assert payload["state"]
    assert payload["task"] == "Do thing"


def test_status_command_unknown_agent(tmp_path: Path, capsys) -> None:
    exit_code = main(["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), "status", "agent-missing"])

    assert exit_code == 1
    out = capsys.readouterr().out
    assert "Unknown agent: agent-missing" in out


@pytest.mark.parametrize(
    ("argv", "expected"),
    [
        (
            ["spawn", "Fast track task"],
            parse_command_payload("spawn", {"task": "Fast track task", "priority": int(TaskPriority.HIGH)}),
        ),
        (
            ["queue", "Backlog task"],
            parse_command_payload("queue", {"task": "Backlog task", "priority": int(TaskPriority.NORMAL)}),
        ),
        (
            ["accept", "agent-1"],
            parse_command_payload(CommandType.ACCEPT, {"agent_id": "agent-1"}),
        ),
        (
            ["reject", "agent-2"],
            parse_command_payload(CommandType.REJECT, {"agent_id": "agent-2"}),
        ),
        (
            ["status", "agent-3"],
            parse_command_payload(CommandType.STATUS, {"agent_id": "agent-3"}),
        ),
        (
            ["list-agents"],
            parse_command_payload(CommandType.LIST_AGENTS, {}),
        ),
    ],
)
def test_cli_adapter_emits_normalized_cairn_command(
    tmp_path: Path,
    argv: list[str],
    expected,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    emitted = []

    async def _submit(self, command):  # noqa: ANN001
        emitted.append(command)

        class _Result:
            payload: dict[str, object] = {}

        return _Result()

    monkeypatch.setattr("cairn.cli.CairnCommandClient.submit", _submit)

    full_argv = ["--project-root", str(tmp_path), "--cairn-home", str(tmp_path / ".cairn"), *argv]
    exit_code = main(full_argv)

    assert exit_code == 0
    assert emitted == [expected]


def test_cli_flags_override_env_settings(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("CAIRN_ORCHESTRATOR_MAX_CONCURRENT_AGENTS", "2")
    monkeypatch.setenv("CAIRN_EXECUTOR_MAX_EXECUTION_TIME", "11")

    captured = {}

    async def _initialize(self):  # noqa: ANN001
        captured["config"] = self.config
        captured["executor"] = self.executor

    async def _submit_command(self, command):  # noqa: ANN001
        class _Result:
            payload: dict[str, object] = {}

        return _Result()

    monkeypatch.setattr("cairn.orchestrator.CairnOrchestrator.initialize", _initialize)
    monkeypatch.setattr("cairn.orchestrator.CairnOrchestrator.submit_command", _submit_command)

    exit_code = main([
        "--project-root",
        str(tmp_path),
        "--max-concurrent-agents",
        "5",
        "--max-execution-time",
        "3",
        "list-agents",
    ])

    assert exit_code == 0
    assert captured["config"].max_concurrent_agents == 5
    assert captured["executor"].max_execution_time == 3

