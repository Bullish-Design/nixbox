"""Shared command models and parsing for CLI and signal handling."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Mapping

from cairn.queue import TaskPriority


class CommandType(str, Enum):
    """Supported high-level Cairn command operations."""

    QUEUE = "queue"
    ACCEPT = "accept"
    REJECT = "reject"
    STATUS = "status"
    LIST_AGENTS = "list_agents"


@dataclass(slots=True)
class CairnCommand:
    """Normalized command object used across CLI and signal processing."""

    type: CommandType
    agent_id: str | None = None
    task: str | None = None
    priority: TaskPriority | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.type is CommandType.QUEUE and not self.task:
            raise ValueError("queue commands require task")

        if self.type in {CommandType.ACCEPT, CommandType.REJECT, CommandType.STATUS} and not self.agent_id:
            raise ValueError(f"{self.type.value} commands require agent_id")

    def to_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"type": self.type.value}

        if self.agent_id is not None:
            payload["agent_id"] = self.agent_id
        if self.task is not None:
            payload["task"] = self.task
        if self.priority is not None:
            payload["priority"] = int(self.priority)
        if self.metadata:
            payload["metadata"] = self.metadata

        return payload


@dataclass(slots=True)
class CommandResult:
    """Normalized result returned after orchestrator command dispatch."""

    command_type: CommandType
    ok: bool = True
    agent_id: str | None = None
    payload: dict[str, Any] = field(default_factory=dict)


def _parse_command_type(command_type: CommandType | str) -> tuple[CommandType, bool]:
    if isinstance(command_type, CommandType):
        return command_type, False

    normalized = command_type.strip().lower().replace("-", "_")
    if normalized == "spawn":
        return CommandType.QUEUE, True

    try:
        return CommandType(normalized), False
    except ValueError as exc:
        raise ValueError(f"unsupported command type: {command_type}") from exc


def parse_command_payload(
    command_type: CommandType | str,
    payload: Mapping[str, Any] | None = None,
) -> CairnCommand:
    """Parse/validate incoming command data and normalize command defaults."""

    data = dict(payload or {})
    command, is_spawn_alias = _parse_command_type(command_type)

    agent_id = data.get("agent_id")
    task = data.get("task")

    metadata_raw = data.get("metadata")
    metadata = dict(metadata_raw) if isinstance(metadata_raw, Mapping) else {}

    if command is CommandType.QUEUE:
        default_priority = TaskPriority.HIGH if is_spawn_alias else TaskPriority.NORMAL
        raw_priority = data.get("priority", int(default_priority))
        priority = TaskPriority(int(raw_priority))
    else:
        priority = None

    return CairnCommand(
        type=command,
        agent_id=agent_id,
        task=task,
        priority=priority,
        metadata=metadata,
    )
