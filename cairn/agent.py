"""Agent lifecycle state and context models."""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum

from agentfs_sdk import AgentFS

from cairn.executor import ExecutionResult
from cairn.queue import TaskPriority


class AgentState(str, Enum):
    """Agent lifecycle states from queueing through completion."""

    QUEUED = "queued"
    SPAWNING = "spawning"
    GENERATING = "generating"
    EXECUTING = "executing"
    SUBMITTING = "submitting"
    REVIEWING = "reviewing"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    ERRORED = "errored"


@dataclass
class AgentContext:
    """Runtime metadata for an agent task lifecycle."""

    agent_id: str
    task: str
    priority: TaskPriority
    state: AgentState
    agent_fs: AgentFS
    generated_code: str | None = None
    execution_result: ExecutionResult | None = None
    submission: dict | None = None
    error: str | None = None
    created_at: float = field(default_factory=time.time)
    state_changed_at: float = field(default_factory=time.time)

    def transition(self, new_state: AgentState) -> None:
        """Transition state and update the lifecycle timestamp."""
        self.state = new_state
        self.state_changed_at = time.time()
