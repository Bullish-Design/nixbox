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
import os
import uuid
from pathlib import Path
from typing import Any

import httpx
import pydantic_monty
from agentfs_sdk import AgentFS, AgentFSOptions
from watchfiles import awatch


class ChimeraOrchestrator:
    """Main orchestrator for managing agentlets and stable layer."""

    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root).resolve()
        self.agentfs_dir = self.project_root / ".agentfs"
        self.chimera_dir = Path.home() / ".chimera"
        self.previews_dir = self.chimera_dir / "previews"
        self.signals_dir = self.chimera_dir / "signals"

        self.stable: AgentFS | None = None
        self.bin: AgentFS | None = None
        self.active_agents: dict[str, AgentFS] = {}

    async def initialize(self) -> None:
        """Initialize the orchestrator and stable layer."""
        # Ensure directories exist
        self.agentfs_dir.mkdir(parents=True, exist_ok=True)
        self.previews_dir.mkdir(parents=True, exist_ok=True)
        self.signals_dir.mkdir(parents=True, exist_ok=True)

        # Open stable layer
        self.stable = await AgentFS.open(AgentFSOptions(id="stable"))

        # Open bin (garbage collection tracker)
        self.bin = await AgentFS.open(AgentFSOptions(id="bin"))

        print(f"✅ Chimera initialized at {self.project_root}")
        print(f"   Stable layer: {self.agentfs_dir / 'stable.db'}")

    async def spawn_agentlet(self, task: str) -> str:
        """Spawn a new agentlet with the given task."""
        agent_id = f"agent-{uuid.uuid4().hex[:8]}"

        # Create new AgentFS for this agent
        agent_fs = await AgentFS.open(AgentFSOptions(id=agent_id))
        self.active_agents[agent_id] = agent_fs

        # Store task in agent's KV
        await agent_fs.kv.set("task", task)

        print(f"🤖 Spawned agentlet: {agent_id}")
        print(f"   Task: {task}")

        # Run the agentlet
        asyncio.create_task(self.run_agentlet(agent_id, agent_fs, task))

        return agent_id

    async def run_agentlet(self, agent_id: str, agent_fs: AgentFS, task: str) -> None:
        """Run an agentlet's code in Monty sandbox."""
        try:
            # Generate agent code via Ollama
            agent_code = await self.generate_agent_code(task)

            # Store generated code for debugging
            await agent_fs.kv.set("generated_code", agent_code)

            # Create external functions for Monty
            external_funcs = self.create_external_functions(agent_id, agent_fs)

            # Run in Monty sandbox
            m = pydantic_monty.Monty(
                agent_code,
                inputs=[],
                external_functions=list(external_funcs.keys()),
                script_name=f"{agent_id}.py",
            )

            result = await pydantic_monty.run_monty_async(m, inputs={}, external_functions=external_funcs)

            print(f"✅ Agentlet {agent_id} completed")
            print(f"   Result: {result}")

        except Exception as e:
            print(f"❌ Agentlet {agent_id} failed: {e}")
            await self.trash_agentlet(agent_id)

    def create_external_functions(self, agent_id: str, agent_fs: AgentFS) -> dict[str, Any]:
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
            await agent_fs.kv.set(
                "submission",
                json.dumps({"summary": summary, "changed_files": changed_files}),
            )
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
                await self.trash_agentlet(agent_id)
                signal_file.unlink()

    async def accept_agentlet(self, agent_id: str) -> None:
        """Accept an agentlet's changes and merge to stable."""
        agent_fs = self.active_agents.get(agent_id)
        if not agent_fs or not self.stable:
            return

        # Get submission
        submission_str = await agent_fs.kv.get("submission")
        if not submission_str:
            print(f"⚠️  No submission found for {agent_id}")
            return

        submission = json.loads(submission_str)

        # Copy changed files to stable
        for path in submission.get("changed_files", []):
            content = await agent_fs.fs.read_file(path)
            await self.stable.fs.write_file(path, content)
            print(f"✅ Merged to stable: {path}")

        # Clean up
        await self.trash_agentlet(agent_id)

    async def trash_agentlet(self, agent_id: str) -> None:
        """Mark an agentlet for garbage collection."""
        if agent_id in self.active_agents:
            await self.active_agents[agent_id].close()
            del self.active_agents[agent_id]

        if self.bin:
            await self.bin.kv.set(f"trash:{agent_id}", json.dumps({"timestamp": asyncio.get_event_loop().time()}))

        print(f"🗑️  Trashed agentlet: {agent_id}")

    async def gc_loop(self) -> None:
        """Garbage collect dead agentlets."""
        while True:
            await asyncio.sleep(30)

            if not self.bin:
                continue

            trash_items = await self.bin.kv.list("trash:")
            for item_data in trash_items:
                agent_id = item_data["key"].replace("trash:", "")
                db_path = self.agentfs_dir / f"{agent_id}.db"

                if db_path.exists():
                    db_path.unlink()
                    print(f"🧹 Deleted: {db_path}")

                await self.bin.kv.delete(item_data["key"])

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
