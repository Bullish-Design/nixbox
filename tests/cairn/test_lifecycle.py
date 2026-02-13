"""Tests for lifecycle models and storage serialization."""

from __future__ import annotations

from pathlib import Path

import pytest
from agentfs_pydantic import AgentFSOptions
from agentfs_sdk import AgentFS
from pydantic import ValidationError

from cairn.agent import AgentState
from cairn.lifecycle import LifecycleRecord, LifecycleStore


@pytest.mark.asyncio
async def test_lifecycle_store_serialization_round_trip(tmp_path: Path) -> None:
    storage = await AgentFS.open(AgentFSOptions(path=str(tmp_path / "lifecycle.db")).model_dump())
    store = LifecycleStore(storage)

    record = LifecycleRecord(
        agent_id="agent-1",
        task="Ship feature",
        priority=1,
        state=AgentState.QUEUED,
        created_at=100.0,
        state_changed_at=100.0,
        db_path=str(tmp_path / "agent-1.db"),
        submission={"summary": "ok"},
    )

    await store.save(record)
    loaded = await store.load("agent-1")

    assert loaded is not None
    assert loaded == record
    assert loaded.model_dump_json() == record.model_dump_json()

    listed = await store.list_all()
    assert listed == [record]

    await storage.close()


def test_lifecycle_record_validation_errors() -> None:
    with pytest.raises(ValidationError):
        LifecycleRecord(
            agent_id="",
            task="Task",
            priority=1,
            state=AgentState.QUEUED,
            created_at=1.0,
            state_changed_at=1.0,
            db_path="/tmp/a.db",
        )

    with pytest.raises(ValidationError):
        LifecycleRecord(
            agent_id="agent-2",
            task="Task",
            priority=1,
            state="bad-state",
            created_at=1.0,
            state_changed_at=1.0,
            db_path="/tmp/a.db",
        )

    with pytest.raises(ValidationError):
        LifecycleRecord(
            agent_id="agent-3",
            task="Task",
            priority=1,
            state=AgentState.QUEUED,
            created_at=2.0,
            state_changed_at=1.0,
            db_path="/tmp/a.db",
        )
