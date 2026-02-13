"""Signal polling for accept/reject workflow events."""

from __future__ import annotations

import asyncio
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from cairn.orchestrator import CairnOrchestrator


class SignalHandler:
    """Poll signal files and dispatch orchestrator lifecycle actions."""

    def __init__(self, cairn_home: Path, orchestrator: "CairnOrchestrator"):
        self.signals_dir = Path(cairn_home) / "signals"
        self.orchestrator = orchestrator

    async def watch(self) -> None:
        """Poll for accept/reject signal files every 500ms."""
        self.signals_dir.mkdir(parents=True, exist_ok=True)

        while True:
            await asyncio.sleep(0.5)

            for signal_file in self.signals_dir.glob("accept-*"):
                agent_id = signal_file.stem.replace("accept-", "")
                try:
                    await self.orchestrator.accept_agent(agent_id)
                finally:
                    signal_file.unlink(missing_ok=True)

            for signal_file in self.signals_dir.glob("reject-*"):
                agent_id = signal_file.stem.replace("reject-", "")
                try:
                    await self.orchestrator.reject_agent(agent_id)
                finally:
                    signal_file.unlink(missing_ok=True)
