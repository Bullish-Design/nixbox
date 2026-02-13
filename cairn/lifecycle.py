"""Single canonical lifecycle storage for agent metadata.

This module provides the unified storage layer for agent lifecycle metadata,
replacing the previous scattered approach across runtime memory, state files,
and bin DB metadata.

Design Principles:
- Single source of truth: bin.db KV namespace
- Linear and idempotent operations
- Clear recovery path from persistent state
"""

from __future__ import annotations

import time
from pathlib import Path
from typing import Any

from agentfs_sdk import AgentFS
from pydantic import BaseModel, field_validator, model_validator

from cairn.agent import AgentState


class LifecycleRecord(BaseModel):
    """Canonical lifecycle record for an agent."""

    agent_id: str
    task: str
    priority: int
    state: AgentState
    created_at: float
    state_changed_at: float
    db_path: str
    submission: dict[str, Any] | None = None
    error: str | None = None

    @field_validator("agent_id")
    @classmethod
    def validate_agent_id(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("agent_id must be non-empty")
        return value

    @field_validator("state", mode="before")
    @classmethod
    def validate_state(cls, value: AgentState | str) -> AgentState:
        return AgentState(value)

    @model_validator(mode="after")
    def validate_timestamps(self) -> LifecycleRecord:
        if self.state_changed_at < self.created_at:
            raise ValueError("state_changed_at must be greater than or equal to created_at")
        return self


class LifecycleStore:
    """Manages agent lifecycle metadata in AgentFS KV namespace.

    This is the single source of truth for agent state. All lifecycle
    transitions, completions, and cleanup operations go through this store.
    """

    def __init__(self, storage: AgentFS):
        self.storage = storage

    async def save(self, record: LifecycleRecord) -> None:
        """Save or update an agent lifecycle record.

        This is the canonical write operation for agent state.
        All state transitions must call this method.
        """
        key = f"agent:{record.agent_id}"
        await self.storage.kv.set(key, record.model_dump_json())

    async def load(self, agent_id: str) -> LifecycleRecord | None:
        """Load an agent lifecycle record by ID."""
        key = f"agent:{agent_id}"
        data = await self.storage.kv.get(key)
        if data is None:
            return None
        return LifecycleRecord.model_validate_json(data)

    async def delete(self, agent_id: str) -> None:
        """Delete an agent lifecycle record."""
        key = f"agent:{agent_id}"
        await self.storage.kv.delete(key)

    async def list_all(self) -> list[LifecycleRecord]:
        """List all agent lifecycle records."""
        keys = await self.storage.kv.list()
        records = []
        for key in keys:
            if not key.startswith("agent:"):
                continue
            data = await self.storage.kv.get(key)
            if data:
                records.append(LifecycleRecord.model_validate_json(data))
        return records

    async def list_active(self) -> list[LifecycleRecord]:
        """List only active (non-terminal) agent records."""
        all_records = await self.list_all()
        terminal_states = {
            AgentState.ACCEPTED,
            AgentState.REJECTED,
        }
        return [r for r in all_records if r.state not in terminal_states]

    async def cleanup_old(
        self,
        max_age_seconds: float = 86400 * 7,
        agentfs_dir: Path | None = None,
    ) -> int:
        """Remove lifecycle records and DBs for old completed agents.

        This is the single retention policy for the system.

        Args:
            max_age_seconds: Maximum age in seconds for completed agents
            agentfs_dir: Directory containing agent DB files

        Returns:
            Number of records cleaned up
        """
        cutoff = time.time() - max_age_seconds
        all_records = await self.list_all()
        cleaned = 0

        terminal_states = {
            AgentState.ACCEPTED,
            AgentState.REJECTED,
            AgentState.ERRORED,
        }

        for record in all_records:
            if record.state not in terminal_states:
                continue

            if record.state_changed_at >= cutoff:
                continue

            await self.delete(record.agent_id)
            cleaned += 1

            if agentfs_dir:
                db_path = Path(record.db_path)
                if db_path.exists():
                    db_path.unlink()

        return cleaned
