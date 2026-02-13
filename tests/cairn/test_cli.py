"""Tests for Cairn CLI command surface and signal/state integration."""

from __future__ import annotations

import json
from pathlib import Path

from cairn.cli import main


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_spawn_command_writes_signal(tmp_path: Path) -> None:
    cairn_home = tmp_path / ".cairn"

    exit_code = main(["--cairn-home", str(cairn_home), "spawn", "Add docs"])

    assert exit_code == 0
    files = list((cairn_home / "signals").glob("spawn-*.json"))
    assert len(files) == 1
    payload = _read_json(files[0])
    assert payload["task"] == "Add docs"


def test_accept_command_writes_signal(tmp_path: Path) -> None:
    cairn_home = tmp_path / ".cairn"

    exit_code = main(["--cairn-home", str(cairn_home), "accept", "agent-123"])

    assert exit_code == 0
    files = list((cairn_home / "signals").glob("accept-*.json"))
    assert len(files) == 1
    payload = _read_json(files[0])
    assert payload["agent_id"] == "agent-123"


def test_status_command_reads_state(tmp_path: Path, capsys) -> None:
    cairn_home = tmp_path / ".cairn"
    state_dir = cairn_home / "state"
    state_dir.mkdir(parents=True)
    (state_dir / "orchestrator.json").write_text(
        json.dumps(
            {
                "agents": {
                    "agent-abc": {
                        "agent_id": "agent-abc",
                        "task": "Do thing",
                        "state": "reviewing",
                    }
                }
            }
        ),
        encoding="utf-8",
    )

    exit_code = main(["--cairn-home", str(cairn_home), "status", "agent-abc"])

    assert exit_code == 0
    out = capsys.readouterr().out
    assert '"agent_id": "agent-abc"' in out
    assert '"state": "reviewing"' in out
