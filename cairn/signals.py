"""Signal polling for orchestrator workflow events."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import TYPE_CHECKING

from cairn.queue import TaskPriority

if TYPE_CHECKING:
    from cairn.orchestrator import CairnOrchestrator


class SignalHandler:
    """Poll signal files and dispatch orchestrator lifecycle actions."""

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
                agent_id = payload.get("agent_id") or signal_file.stem.replace("accept-", "")
                try:
                    await self.orchestrator.accept_agent(agent_id)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("reject-*")):
                payload = self._load_payload(signal_file)
                agent_id = payload.get("agent_id") or signal_file.stem.replace("reject-", "")
                try:
                    await self.orchestrator.reject_agent(agent_id)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("spawn-*")):
                payload = self._load_payload(signal_file)
                task = payload.get("task")
                priority = TaskPriority(payload.get("priority", int(TaskPriority.HIGH)))
                try:
                    if task:
                        await self.orchestrator.spawn_agent(task=task, priority=priority)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in sorted(self.signals_dir.glob("queue-*")):
                payload = self._load_payload(signal_file)
                task = payload.get("task")
                priority = TaskPriority(payload.get("priority", int(TaskPriority.NORMAL)))
                try:
                    if task:
                        await self.orchestrator.spawn_agent(task=task, priority=priority)
                finally:
                    signal_file.unlink(missing_ok=True)

    def _load_payload(self, signal_file: Path) -> dict[str, str | int]:
        try:
            return json.loads(signal_file.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
