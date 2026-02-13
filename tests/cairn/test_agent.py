"""Stage 3 unit tests for agent lifecycle state transitions."""

from __future__ import annotations

import time
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from cairn.agent import AgentContext, AgentState
from cairn.queue import TaskPriority


def test_agent_transition_updates_state_and_timestamp() -> None:
    """State transitions should update both state and state_changed_at."""
    ctx = AgentContext(
        agent_id="agent-1",
        task="Add docs",
        priority=TaskPriority.NORMAL,
        state=AgentState.QUEUED,
        agent_fs=SimpleNamespace(),
    )

    before = ctx.state_changed_at
    time.sleep(0.01)

    ctx.transition(AgentState.SPAWNING)

    assert ctx.state == AgentState.SPAWNING
    assert ctx.state_changed_at > before


def test_agent_multiple_transitions_monotonic_timestamps() -> None:
    """Repeated transitions should keep increasing the transition timestamp."""
    ctx = AgentContext(
        agent_id="agent-2",
        task="Refactor queue",
        priority=TaskPriority.HIGH,
        state=AgentState.QUEUED,
        agent_fs=SimpleNamespace(),
    )

    stamps = []
    for state in (AgentState.GENERATING, AgentState.EXECUTING, AgentState.REVIEWING):
        time.sleep(0.01)
        ctx.transition(state)
        stamps.append(ctx.state_changed_at)

    assert ctx.state == AgentState.REVIEWING
    assert stamps == sorted(stamps)


def test_agent_context_validation_errors() -> None:
    """AgentContext should enforce required invariants."""
    with pytest.raises(ValidationError):
        AgentContext(
            agent_id="",
            task="Task",
            priority=TaskPriority.NORMAL,
            state=AgentState.QUEUED,
            agent_fs=SimpleNamespace(),
        )

    with pytest.raises(ValidationError):
        AgentContext(
            agent_id="agent-3",
            task="Task",
            priority=TaskPriority.NORMAL,
            state="not-a-state",
            agent_fs=SimpleNamespace(),
        )

    with pytest.raises(ValidationError):
        AgentContext(
            agent_id="agent-4",
            task="Task",
            priority=TaskPriority.NORMAL,
            state=AgentState.QUEUED,
            agent_fs=SimpleNamespace(),
            created_at=20.0,
            state_changed_at=10.0,
        )
