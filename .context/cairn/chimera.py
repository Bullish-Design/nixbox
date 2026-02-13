#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "agentfs-sdk>=0.6.0",
#   "pydantic-monty>=0.1.0",
#   "httpx>=0.27.0",
#   "watchfiles>=0.21.0",
#   "pydantic>=2.0.0",
# ]
# ///
# chimera.py

"""Chimera orchestrator - manages agentlets and their sandboxes."""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any

import httpx
import pydantic_monty
from agentfs_sdk import AgentFS, AgentFSOptions
from watchfiles import awatch


class AgentState(str, Enum):
    """Agent lifecycle states."""
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    REJECTED = "rejected"
    ACCEPTED = "accepted"


@dataclass
class AgentLifecycle:
    """Unified agent lifecycle metadata."""
    agent_id: str
    state: AgentState
    task: str
    created_at: float
    updated_at: float
    generated_code: str | None = None
    submission_summary: str | None = None
    changed_files: list[str] | None = None
    error: str | None = None

    def to_json(self) -> str:
        """Serialize to JSON."""
        return json.dumps({
            "agent_id": self.agent_id,
            "state": self.state.value,
            "task": self.task,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "generated_code": self.generated_code,
            "submission_summary": self.submission_summary,
            "changed_files": self.changed_files,
            "error": self.error,
        })

    @staticmethod
    def from_json(data: str) -> AgentLifecycle:
        """Deserialize from JSON."""
        obj = json.loads(data)
        return AgentLifecycle(
            agent_id=obj["agent_id"],
            state=AgentState(obj["state"]),
            task=obj["task"],
            created_at=obj["created_at"],
            updated_at=obj["updated_at"],
            generated_code=obj.get("generated_code"),
            submission_summary=obj.get("submission_summary"),
            changed_files=obj.get("changed_files"),
            error=obj.get("error"),
        )


class ChimeraOrchestrator:
    """Main orchestrator for managing agentlets and stable layer."""

    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root).resolve()
        self.agentfs_dir = self.project_root / ".agentfs"
        self.chimera_dir = Path.home() / ".chimera"
        self.previews_dir = self.chimera_dir / "previews"
        self.signals_dir = self.chimera_dir / "signals"

        self.stable: AgentFS | None = None
        self.lifecycle_store: AgentFS | None = None  # Unified lifecycle storage
        self.active_agents: dict[str, AgentFS] = {}  # Runtime cache only

    async def initialize(self) -> None:
        """Initialize the orchestrator and stable layer."""
        # Ensure directories exist
        self.agentfs_dir.mkdir(parents=True, exist_ok=True)
        self.previews_dir.mkdir(parents=True, exist_ok=True)
        self.signals_dir.mkdir(parents=True, exist_ok=True)

        # Open stable layer
        self.stable = await AgentFS.open(AgentFSOptions(id="stable"))

        # Open lifecycle store (single source of truth for agent lifecycle)
        self.lifecycle_store = await AgentFS.open(AgentFSOptions(id="lifecycle"))

        # Recover from restart
        await self.recover_agents()

        print(f"✅ Chimera initialized at {self.project_root}")
        print(f"   Stable layer: {self.agentfs_dir / 'stable.db'}")
        print(f"   Lifecycle store: {self.agentfs_dir / 'lifecycle.db'}")

    async def recover_agents(self) -> None:
        """Recover agent state after restart."""
        if not self.lifecycle_store:
            return

        # List all lifecycle records
        lifecycle_keys = await self.lifecycle_store.kv.list("agent:")

        for item in lifecycle_keys:
            data = item.get("value")
            if not data:
                continue

            lifecycle = AgentLifecycle.from_json(data)

            # Only recover running agents
            if lifecycle.state == AgentState.RUNNING:
                agent_db = self.agentfs_dir / f"{lifecycle.agent_id}.db"

                if agent_db.exists():
                    # Re-open the agent's DB
                    agent_fs = await AgentFS.open(AgentFSOptions(id=lifecycle.agent_id))
                    self.active_agents[lifecycle.agent_id] = agent_fs
                    print(f"♻️  Recovered running agent: {lifecycle.agent_id}")
                else:
                    # DB file missing, mark as failed
                    lifecycle.state = AgentState.REJECTED
                    lifecycle.error = "Database file not found after restart"
                    lifecycle.updated_at = time.time()
                    await self.update_lifecycle(lifecycle)
                    print(f"⚠️  Agent {lifecycle.agent_id} DB missing, marked rejected")

    async def create_lifecycle(self, agent_id: str, task: str) -> AgentLifecycle:
        """Create a new lifecycle record."""
        lifecycle = AgentLifecycle(
            agent_id=agent_id,
            state=AgentState.QUEUED,
            task=task,
            created_at=time.time(),
            updated_at=time.time(),
        )
        await self.update_lifecycle(lifecycle)
        return lifecycle

    async def update_lifecycle(self, lifecycle: AgentLifecycle) -> None:
        """Update lifecycle record (single source of truth)."""
        if not self.lifecycle_store:
            return

        lifecycle.updated_at = time.time()
        await self.lifecycle_store.kv.set(f"agent:{lifecycle.agent_id}", lifecycle.to_json())

    async def get_lifecycle(self, agent_id: str) -> AgentLifecycle | None:
        """Get lifecycle record."""
        if not self.lifecycle_store:
            return None

        data = await self.lifecycle_store.kv.get(f"agent:{agent_id}")
        if not data:
            return None

        return AgentLifecycle.from_json(data)

    async def delete_lifecycle(self, agent_id: str) -> None:
        """Delete lifecycle record."""
        if not self.lifecycle_store:
            return

        await self.lifecycle_store.kv.delete(f"agent:{agent_id}")

    async def spawn_agentlet(self, task: str) -> str:
        """Spawn a new agentlet with the given task."""
        agent_id = f"agent-{uuid.uuid4().hex[:8]}"

        # Create lifecycle record FIRST
        lifecycle = await self.create_lifecycle(agent_id, task)

        # Create new AgentFS for this agent
        agent_fs = await AgentFS.open(AgentFSOptions(id=agent_id))
        self.active_agents[agent_id] = agent_fs

        print(f"🤖 Spawned agentlet: {agent_id}")
        print(f"   Task: {task}")

        # Run the agentlet
        asyncio.create_task(self.run_agentlet(agent_id, task))

        return agent_id

    async def run_agentlet(self, agent_id: str, task: str) -> None:
        """Run an agentlet's code in Monty sandbox."""
        lifecycle = await self.get_lifecycle(agent_id)
        if not lifecycle:
            print(f"❌ No lifecycle found for {agent_id}")
            return

        agent_fs = self.active_agents.get(agent_id)
        if not agent_fs:
            print(f"❌ No AgentFS found for {agent_id}")
            return

        try:
            # Update state to RUNNING
            lifecycle.state = AgentState.RUNNING
            await self.update_lifecycle(lifecycle)

            # Generate agent code via Ollama
            agent_code = await self.generate_agent_code(task)

            # Store generated code in lifecycle
            lifecycle.generated_code = agent_code
            await self.update_lifecycle(lifecycle)

            # Create external functions for Monty
            external_funcs = self.create_external_functions(agent_id, agent_fs, lifecycle)

            # Run in Monty sandbox
            m = pydantic_monty.Monty(
                agent_code,
                inputs=[],
                external_functions=list(external_funcs.keys()),
                script_name=f"{agent_id}.py",
            )

            result = await pydantic_monty.run_monty_async(m, inputs={}, external_functions=external_funcs)

            # Update state to COMPLETED
            lifecycle.state = AgentState.COMPLETED
            await self.update_lifecycle(lifecycle)

            print(f"✅ Agentlet {agent_id} completed")
            print(f"   Result: {result}")

        except Exception as e:
            print(f"❌ Agentlet {agent_id} failed: {e}")

            # Update lifecycle with error
            lifecycle.state = AgentState.REJECTED
            lifecycle.error = str(e)
            await self.update_lifecycle(lifecycle)

            # Clean up
            await self.cleanup_agent(agent_id)

    def create_external_functions(self, agent_id: str, agent_fs: AgentFS, lifecycle: AgentLifecycle) -> dict[str, Any]:
        """Create external functions that Monty can call."""

        async def read_file(path: str) -> str:
            """Read a file from the agent's overlay."""
            try:
                # Try agent's overlay first
                content = await agent_fs.fs.read_file(path)
                return content
            except Exception:
                # Fall through to stable layer
                if self.stable:
                    return await self.stable.fs.read_file(path)
                raise

        async def write_file(path: str, content: str) -> bool:
            """Write a file to the agent's overlay."""
            await agent_fs.fs.write_file(path, content.encode("utf-8"))
            return True

        async def list_dir(path: str) -> list[str]:
            """List directory contents."""
            entries = await agent_fs.fs.readdir(path)
            return [e.name for e in entries]

        async def search_files(pattern: str) -> list[str]:
            """Search for files matching a pattern (simplified)."""
            # In real implementation, use ripgrep subprocess
            # For MVP, just return placeholder
            return []

        async def ask_llm(prompt: str, context: str = "") -> str:
            """Call Ollama for LLM assistance."""
            return await self.call_ollama(prompt, context)

        async def submit_result(summary: str, changed_files: list[str]) -> bool:
            """Submit agentlet results."""
            # Update lifecycle record with submission
            lifecycle.submission_summary = summary
            lifecycle.changed_files = changed_files
            await self.update_lifecycle(lifecycle)

            print(f"📝 {agent_id} submitted: {summary}")
            print(f"   Changed files: {changed_files}")
            return True

        async def log(message: str) -> bool:
            """Log a debug message."""
            print(f"🔍 {agent_id}: {message}")
            return True

        return {
            "read_file": read_file,
            "write_file": write_file,
            "list_dir": list_dir,
            "search_files": search_files,
            "ask_llm": ask_llm,
            "submit_result": submit_result,
            "log": log,
        }

    async def generate_agent_code(self, task: str) -> str:
        """Generate Python code for an agent via Ollama."""
        prompt = f"""Write a short Python script to accomplish this task:
{task}

Available functions (the ONLY things you can call):
- read_file(path) -> str
- write_file(path, content) -> bool
- list_dir(path) -> list of strings
- search_files(pattern) -> list of matching paths
- ask_llm(prompt, context) -> str
- submit_result(summary, changed_files_list) -> bool
- log(message) -> bool

You CANNOT: import anything, define classes, use open(), use print().
Write simple procedural Python. Variables, functions, loops, conditionals only.

Respond with ONLY the Python code. No markdown, no explanation."""

        response = await self.call_ollama(prompt, "")
        return self.extract_code(response)

    def extract_code(self, response: str) -> str:
        """Extract code from LLM response."""
        # Remove markdown fences if present
        lines = response.strip().split("\n")
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines[-1].startswith("```"):
            lines = lines[:-1]
        return "\n".join(lines)

    async def call_ollama(self, prompt: str, context: str) -> str:
        """Call Ollama API."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "qwen2.5-coder:7b",
                    "prompt": f"{context}\n\n{prompt}" if context else prompt,
                    "stream": False,
                },
                timeout=30.0,
            )
            return response.json().get("response", "")

    async def watch_file_changes(self) -> None:
        """Watch project files and sync to stable layer."""
        async for changes in awatch(self.project_root):
            for change_type, path_str in changes:
                path = Path(path_str)

                # Skip .agentfs and .git directories
                if ".agentfs" in path.parts or ".git" in path.parts:
                    continue

                # Sync to stable layer
                rel_path = str(path.relative_to(self.project_root))
                if path.is_file() and self.stable:
                    content = path.read_bytes()
                    await self.stable.fs.write_file(rel_path, content)
                    print(f"📝 Synced to stable: {rel_path}")

    async def watch_signals(self) -> None:
        """Watch for accept/reject signals from Neovim."""
        while True:
            await asyncio.sleep(0.5)

            # Check for accept signals
            for signal_file in self.signals_dir.glob("accept-*"):
                agent_id = signal_file.stem.replace("accept-", "")
                await self.accept_agentlet(agent_id)
                signal_file.unlink()

            # Check for reject signals
            for signal_file in self.signals_dir.glob("reject-*"):
                agent_id = signal_file.stem.replace("reject-", "")
                await self.reject_agentlet(agent_id)
                signal_file.unlink()

    async def accept_agentlet(self, agent_id: str) -> None:
        """Accept an agentlet's changes and merge to stable."""
        lifecycle = await self.get_lifecycle(agent_id)
        if not lifecycle:
            print(f"⚠️  No lifecycle found for {agent_id}")
            return

        agent_fs = self.active_agents.get(agent_id)
        if not agent_fs or not self.stable:
            print(f"⚠️  Agent {agent_id} not active or stable layer missing")
            return

        # Check if agent has completed
        if lifecycle.state != AgentState.COMPLETED:
            print(f"⚠️  Agent {agent_id} not in COMPLETED state")
            return

        # Copy changed files to stable
        if lifecycle.changed_files:
            for path in lifecycle.changed_files:
                try:
                    content = await agent_fs.fs.read_file(path)
                    await self.stable.fs.write_file(path, content)
                    print(f"✅ Merged to stable: {path}")
                except Exception as e:
                    print(f"⚠️  Failed to merge {path}: {e}")

        # Update lifecycle state to ACCEPTED
        lifecycle.state = AgentState.ACCEPTED
        await self.update_lifecycle(lifecycle)

        # Clean up
        await self.cleanup_agent(agent_id)

        print(f"✅ Accepted agentlet: {agent_id}")

    async def reject_agentlet(self, agent_id: str) -> None:
        """Reject an agentlet's changes."""
        lifecycle = await self.get_lifecycle(agent_id)
        if not lifecycle:
            print(f"⚠️  No lifecycle found for {agent_id}")
            return

        # Update lifecycle state to REJECTED
        lifecycle.state = AgentState.REJECTED
        await self.update_lifecycle(lifecycle)

        # Clean up
        await self.cleanup_agent(agent_id)

        print(f"🗑️  Rejected agentlet: {agent_id}")

    async def cleanup_agent(self, agent_id: str) -> None:
        """Clean up agent resources (idempotent)."""
        # Close and remove from runtime cache
        if agent_id in self.active_agents:
            try:
                await self.active_agents[agent_id].close()
            except Exception as e:
                print(f"⚠️  Error closing {agent_id}: {e}")
            del self.active_agents[agent_id]

        # Delete agent DB file
        db_path = self.agentfs_dir / f"{agent_id}.db"
        if db_path.exists():
            try:
                db_path.unlink()
                print(f"🧹 Deleted: {db_path}")
            except Exception as e:
                print(f"⚠️  Failed to delete {db_path}: {e}")

        # Note: We keep the lifecycle record for history/debugging
        # It can be purged by a separate retention policy

    async def gc_loop(self) -> None:
        """Garbage collect old lifecycle records based on retention policy."""
        while True:
            await asyncio.sleep(300)  # Run every 5 minutes

            if not self.lifecycle_store:
                continue

            current_time = time.time()
            retention_seconds = 86400  # 24 hours

            # List all lifecycle records
            lifecycle_keys = await self.lifecycle_store.kv.list("agent:")

            for item in lifecycle_keys:
                data = item.get("value")
                if not data:
                    continue

                lifecycle = AgentLifecycle.from_json(data)

                # Delete old accepted/rejected records
                if lifecycle.state in (AgentState.ACCEPTED, AgentState.REJECTED):
                    age = current_time - lifecycle.updated_at
                    if age > retention_seconds:
                        await self.delete_lifecycle(lifecycle.agent_id)
                        print(f"🧹 Purged old lifecycle: {lifecycle.agent_id}")

    async def run(self) -> None:
        """Main orchestrator loop."""
        await self.initialize()

        # Start background tasks
        tasks = [
            asyncio.create_task(self.watch_file_changes()),
            asyncio.create_task(self.watch_signals()),
            asyncio.create_task(self.gc_loop()),
        ]

        # Spawn a test agentlet
        await self.spawn_agentlet("Add a docstring to any function that doesn't have one")

        # Keep running
        await asyncio.gather(*tasks)


async def main() -> None:
    """Entry point."""
    orchestrator = ChimeraOrchestrator()
    await orchestrator.run()


if __name__ == "__main__":
    asyncio.run(main())
