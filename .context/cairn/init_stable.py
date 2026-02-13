#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "agentfs-sdk>=0.6.0",
# ]
# ///
# init_stable.py

"""Initialize stable layer from existing project files."""

from __future__ import annotations

import asyncio
from pathlib import Path

from agentfs_sdk import AgentFS, AgentFSOptions


async def init_stable(project_root: str = ".") -> None:
    """Initialize stable.db from current project directory."""
    project_path = Path(project_root).resolve()
    agentfs_dir = project_path / ".agentfs"

    agentfs_dir.mkdir(parents=True, exist_ok=True)

    print(f"🔧 Initializing stable layer at {project_path}")

    # Open stable layer
    stable = await AgentFS.open(AgentFSOptions(id="stable"))

    # Walk project directory and sync all files
    files_synced = 0
    bytes_synced = 0

    for file_path in project_path.rglob("*"):
        # Skip special directories
        if any(part.startswith(".") for part in file_path.parts):
            continue

        # Skip non-files
        if not file_path.is_file():
            continue

        # Get relative path
        rel_path = str(file_path.relative_to(project_path))

        # Read file content
        try:
            content = file_path.read_bytes()
        except Exception as e:
            print(f"⚠️  Skipping {rel_path}: {e}")
            continue

        # Write to stable layer
        try:
            await stable.fs.write_file(rel_path, content)
            files_synced += 1
            bytes_synced += len(content)
            print(f"✅ Synced: {rel_path} ({len(content)} bytes)")
        except Exception as e:
            print(f"❌ Failed to sync {rel_path}: {e}")

    await stable.close()

    print("")
    print(f"✨ Initialization complete!")
    print(f"   Files synced: {files_synced}")
    print(f"   Bytes synced: {bytes_synced:,}")
    print(f"   Database: {agentfs_dir / 'stable.db'}")


if __name__ == "__main__":
    asyncio.run(init_stable())
