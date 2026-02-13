"""Tests for Cairn CLI command surface and command dispatch integration."""

from __future__ import annotations

import json
from pathlib import Path

from cairn.cli import main


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
