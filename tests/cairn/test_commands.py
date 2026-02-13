"""Tests for normalized Cairn command parsing and validation."""

from __future__ import annotations

import pytest

from cairn.commands import CommandType, parse_command_payload
from cairn.queue import TaskPriority


def test_parse_queue_defaults_to_normal_priority() -> None:
    command = parse_command_payload(CommandType.QUEUE, {"task": "Backlog task"})

    assert command.type is CommandType.QUEUE
    assert command.task == "Backlog task"
    assert command.priority is TaskPriority.NORMAL


def test_parse_spawn_alias_defaults_to_high_priority() -> None:
    command = parse_command_payload("spawn", {"task": "Urgent task"})

    assert command.type is CommandType.QUEUE
    assert command.task == "Urgent task"
    assert command.priority is TaskPriority.HIGH


def test_parse_accept_requires_agent_id() -> None:
    with pytest.raises(ValueError, match="require agent_id"):
        parse_command_payload(CommandType.ACCEPT, {})
