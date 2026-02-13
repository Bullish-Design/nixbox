"""Command-line interface for the Cairn orchestrator service."""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path

from cairn.commands import (
    AcceptCommand,
    CairnCommand,
    CommandResult,
    ListAgentsCommand,
    QueueCommand,
    RejectCommand,
    StatusCommand,
    parse_command_payload,
)
from cairn.orchestrator import CairnOrchestrator
from cairn.queue import TaskPriority


async def _run_up(args: argparse.Namespace) -> int:
    orchestrator = CairnOrchestrator(project_root=args.project_root, cairn_home=args.cairn_home)
    await orchestrator.initialize()
    await orchestrator.run()
    return 0


class CairnCommandClient:
    """Submit CLI commands through orchestrator command handling."""

    def __init__(self, *, project_root: str | Path, cairn_home: str | Path | None) -> None:
        self.project_root = project_root
        self.cairn_home = cairn_home

    async def submit(self, command: CairnCommand) -> CommandResult:
        orchestrator = CairnOrchestrator(project_root=self.project_root, cairn_home=self.cairn_home)
        await orchestrator.initialize()
        return await orchestrator.submit_command(command)


async def _submit_command(args: argparse.Namespace, command: CairnCommand) -> CommandResult:
    client = CairnCommandClient(project_root=args.project_root, cairn_home=args.cairn_home)

    match command:
        case QueueCommand() | AcceptCommand() | RejectCommand() | StatusCommand() | ListAgentsCommand():
            return await client.submit(command)

    raise ValueError(f"unsupported command type: {command.type.value}")


async def _run_spawn(args: argparse.Namespace) -> int:
    command = parse_command_payload("spawn", {"task": args.task, "priority": int(TaskPriority.HIGH)})
    await _submit_command(args, command)
    print("queued spawn request")
    return 0


async def _run_queue(args: argparse.Namespace) -> int:
    command = parse_command_payload("queue", {"task": args.task, "priority": int(TaskPriority.NORMAL)})
    await _submit_command(args, command)
    print("queued task request")
    return 0


async def _run_list_agents(args: argparse.Namespace) -> int:
    command = parse_command_payload("list_agents", {})
    result = await _submit_command(args, command)
    agents = result.payload.get("agents", {})
    if not agents:
        print("No active agents")
        return 0

    for agent_id, agent in sorted(agents.items()):
        print(f"{agent_id}\t{agent.get('state')}\t{agent.get('task')}")
    return 0


async def _run_status(args: argparse.Namespace) -> int:
    command = parse_command_payload("status", {"agent_id": args.agent_id})
    try:
        result = await _submit_command(args, command)
    except ValueError:
        print(f"Unknown agent: {args.agent_id}")
        return 1

    print(json.dumps(result.payload, indent=2, sort_keys=True))
    return 0


async def _run_accept(args: argparse.Namespace) -> int:
    command = parse_command_payload("accept", {"agent_id": args.agent_id})
    await _submit_command(args, command)
    print(f"queued accept for {args.agent_id}")
    return 0


async def _run_reject(args: argparse.Namespace) -> int:
    command = parse_command_payload("reject", {"agent_id": args.agent_id})
    await _submit_command(args, command)
    print(f"queued reject for {args.agent_id}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="cairn")
    parser.add_argument("--project-root", default=".")
    parser.add_argument("--cairn-home", default=None)

    subparsers = parser.add_subparsers(dest="command", required=True)

    up_parser = subparsers.add_parser("up", help="Start orchestrator service")
    up_parser.set_defaults(handler=_run_up, is_async=True)

    spawn_parser = subparsers.add_parser("spawn", help="Spawn an agent")
    spawn_parser.add_argument("task")
    spawn_parser.set_defaults(handler=_run_spawn, is_async=True)

    queue_parser = subparsers.add_parser("queue", help="Queue an agent task")
    queue_parser.add_argument("task")
    queue_parser.set_defaults(handler=_run_queue, is_async=True)

    list_parser = subparsers.add_parser("list-agents", help="List active agents")
    list_parser.set_defaults(handler=_run_list_agents, is_async=True)

    status_parser = subparsers.add_parser("status", help="Show agent status")
    status_parser.add_argument("agent_id")
    status_parser.set_defaults(handler=_run_status, is_async=True)

    accept_parser = subparsers.add_parser("accept", help="Accept agent changes")
    accept_parser.add_argument("agent_id")
    accept_parser.set_defaults(handler=_run_accept, is_async=True)

    reject_parser = subparsers.add_parser("reject", help="Reject agent changes")
    reject_parser.add_argument("agent_id")
    reject_parser.set_defaults(handler=_run_reject, is_async=True)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.is_async:
        return asyncio.run(args.handler(args))
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
