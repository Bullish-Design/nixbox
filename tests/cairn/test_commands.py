"""Tests for normalized Cairn command parsing and validation."""

from __future__ import annotations

import pytest

from cairn.commands import (
    AcceptCommand,
    CommandType,
    ListAgentsCommand,
    QueueCommand,
    RejectCommand,
    StatusCommand,
    parse_command_payload,
)
from cairn.queue import TaskPriority


def test_parse_queue_defaults_to_normal_priority() -> None:
    command = parse_command_payload(CommandType.QUEUE, {"task": "Backlog task"})

    assert isinstance(command, QueueCommand)
    assert command.type is CommandType.QUEUE
    assert command.task == "Backlog task"
    assert command.priority is TaskPriority.NORMAL


def test_parse_spawn_alias_defaults_to_high_priority() -> None:
    command = parse_command_payload("spawn", {"task": "Urgent task"})

    assert isinstance(command, QueueCommand)
    assert command.type is CommandType.QUEUE
    assert command.task == "Urgent task"
    assert command.priority is TaskPriority.HIGH


def test_parse_spawn_alias_respects_explicit_priority() -> None:
    command = parse_command_payload("spawn", {"task": "Urgent task", "priority": int(TaskPriority.LOW)})

    assert isinstance(command, QueueCommand)
    assert command.priority is TaskPriority.LOW


@pytest.mark.parametrize(
    ("command_type", "payload"),
    [
        (CommandType.ACCEPT, {}),
        (CommandType.REJECT, {}),
        (CommandType.STATUS, {}),
        (CommandType.QUEUE, {}),
        (CommandType.QUEUE, {"task": ""}),
    ],
)
def test_parse_invalid_or_partial_payloads_raise_value_error(
    command_type: CommandType | str,
    payload: dict[str, object],
) -> None:
    with pytest.raises(ValueError):
        parse_command_payload(command_type, payload)


def test_parse_command_union_model_types() -> None:
    assert isinstance(parse_command_payload("accept", {"agent_id": "agent-a"}), AcceptCommand)
    assert isinstance(parse_command_payload("reject", {"agent_id": "agent-b"}), RejectCommand)
    assert isinstance(parse_command_payload("status", {"agent_id": "agent-c"}), StatusCommand)
    assert isinstance(parse_command_payload("list_agents", {}), ListAgentsCommand)
