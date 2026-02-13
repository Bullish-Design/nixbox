"""Stage 3 unit tests for file watcher sync behavior."""

from __future__ import annotations

from pathlib import Path

import pytest
from watchfiles import Change

from cairn.watcher import FileWatcher


class FakeStableFS:
    def __init__(self) -> None:
        self.files: dict[str, bytes] = {}
        self.deleted: list[str] = []

    async def write_file(self, path: str, content: bytes) -> None:
        self.files[path] = content

    async def delete_file(self, path: str) -> None:
        self.deleted.append(path)
        self.files.pop(path, None)


class FakeStable:
    def __init__(self) -> None:
        self.fs = FakeStableFS()


@pytest.mark.asyncio
async def test_watcher_syncs_file_changes(tmp_path: Path) -> None:
    stable = FakeStable()
    watcher = FileWatcher(tmp_path, stable)

    file_path = tmp_path / "notes.txt"
    file_path.write_text("hello", encoding="utf-8")

    await watcher.handle_change(Change.modified, file_path)

    assert stable.fs.files["notes.txt"] == b"hello"


@pytest.mark.asyncio
async def test_watcher_ignores_internal_paths(tmp_path: Path) -> None:
    stable = FakeStable()
    watcher = FileWatcher(tmp_path, stable)

    ignored = tmp_path / ".git" / "config"
    ignored.parent.mkdir(parents=True)
    ignored.write_text("[core]", encoding="utf-8")

    await watcher.handle_change(Change.modified, ignored)

    assert stable.fs.files == {}


@pytest.mark.asyncio
async def test_watcher_deletes_removed_files(tmp_path: Path) -> None:
    stable = FakeStable()
    watcher = FileWatcher(tmp_path, stable)

    deleted_path = tmp_path / "old.txt"

    await watcher.handle_change(Change.deleted, deleted_path)

    assert stable.fs.deleted == ["old.txt"]
