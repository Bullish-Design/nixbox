"""Stage 3 integration tests for workspace materialization and cleanup."""

from __future__ import annotations

from pathlib import Path

import pytest
from agentfs_pydantic import AgentFSOptions
from agentfs_sdk import AgentFS

from cairn.workspace import WorkspaceMaterializer


@pytest.mark.asyncio
async def test_workspace_materialize_copies_stable_and_overlay_files(tmp_path: Path) -> None:
    stable = await AgentFS.open(AgentFSOptions(path=str(tmp_path / "stable.db")).model_dump())
    overlay = await AgentFS.open(AgentFSOptions(path=str(tmp_path / "overlay.db")).model_dump())

    await stable.fs.write_file("base.txt", b"stable")
    await overlay.fs.write_file("overlay.txt", b"agent")
    await overlay.fs.write_file("base.txt", b"override")

    materializer = WorkspaceMaterializer(tmp_path / ".cairn", stable_fs=stable)
    workspace_path = await materializer.materialize("agent-1", overlay)

    assert workspace_path == tmp_path / ".cairn" / "workspaces" / "agent-1"
    assert (workspace_path / "overlay.txt").read_text(encoding="utf-8") == "agent"
    assert (workspace_path / "base.txt").read_text(encoding="utf-8") == "override"

    await overlay.close()
    await stable.close()


@pytest.mark.asyncio
async def test_workspace_cleanup_removes_materialized_directory(tmp_path: Path) -> None:
    overlay = await AgentFS.open(AgentFSOptions(path=str(tmp_path / "overlay.db")).model_dump())
    materializer = WorkspaceMaterializer(tmp_path / ".cairn")

    workspace_path = await materializer.materialize("agent-2", overlay)
    assert workspace_path.exists()

    await materializer.cleanup("agent-2")

    assert not workspace_path.exists()
    await overlay.close()
