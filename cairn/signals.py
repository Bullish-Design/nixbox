"""Signal polling for orchestrator workflow events."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import TYPE_CHECKING, Any

from cairn.commands import CairnCommand, CommandType, parse_command_payload

if TYPE_CHECKING:
    from cairn.orchestrator import CairnOrchestrator


class SignalHandler:
    """Poll signal files and dispatch normalized orchestrator commands."""

    def __init__(self, cairn_home: Path, orchestrator: "CairnOrchestrator"):
        self.signals_dir = Path(cairn_home) / "signals"
        self.orchestrator = orchestrator

    async def watch(self) -> None:
        """Poll for signal files every 500ms."""
        self.signals_dir.mkdir(parents=True, exist_ok=True)

        while True:
            await asyncio.sleep(0.5)

            for signal_file in sorted(self.signals_dir.glob("accept-*")):
                payload = self._load_payload(signal_file)
                payload.setdefault("agent_id", signal_file.stem.replace("accept-", ""))
                command = parse_command_payload(CommandType.ACCEPT, payload)
                try:
                    await self._dispatch(command)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("reject-*")):
                payload = self._load_payload(signal_file)
                payload.setdefault("agent_id", signal_file.stem.replace("reject-", ""))
                command = parse_command_payload(CommandType.REJECT, payload)
                try:
                    await self._dispatch(command)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("spawn-*")):
                payload = self._load_payload(signal_file)
                command = parse_command_payload("spawn", payload)
                try:
                    await self._dispatch(command)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("queue-*")):
                payload = self._load_payload(signal_file)
                command = parse_command_payload(CommandType.QUEUE, payload)
                try:
                    await self._dispatch(command)
                finally:
                    signal_file.unlink(missing_ok=True)

    async def _dispatch(self, command: CairnCommand) -> None:
        await self.orchestrator.submit_command(command)

    def _load_payload(self, signal_file: Path) -> dict[str, Any]:
        try:
            loaded = json.loads(signal_file.read_text(encoding="utf-8"))
            return loaded if isinstance(loaded, dict) else {}
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
