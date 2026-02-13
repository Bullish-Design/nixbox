"""Command-line interface for the Cairn orchestrator service."""

from __future__ import annotations

import argparse
import asyncio
import json
import uuid
from pathlib import Path
from typing import Any

from cairn.commands import CairnCommand, parse_command_payload
from cairn.orchestrator import CairnOrchestrator
from cairn.queue import TaskPriority


async def _run_up(args: argparse.Namespace) -> int:
    orchestrator = CairnOrchestrator(project_root=args.project_root, cairn_home=args.cairn_home)
    await orchestrator.initialize()
    await orchestrator.run()
    return 0


def _write_signal(cairn_home: str | Path | None, kind: str, command: CairnCommand) -> Path:
    home = Path(cairn_home or Path.home() / ".cairn").expanduser()
    signals_dir = home / "signals"
    signals_dir.mkdir(parents=True, exist_ok=True)
    signal_path = signals_dir / f"{kind}-{uuid.uuid4().hex}.json"
    signal_path.write_text(json.dumps(command.to_payload()), encoding="utf-8")
    return signal_path


def _read_state(cairn_home: str | Path | None) -> dict[str, Any]:
    home = Path(cairn_home or Path.home() / ".cairn").expanduser()
    state_file = home / "state" / "orchestrator.json"
    if not state_file.exists():
        return {"agents": {}, "queue": {"pending": 0, "running": 0}}
    return json.loads(state_file.read_text(encoding="utf-8"))


def _run_spawn(args: argparse.Namespace) -> int:
    command = parse_command_payload("spawn", {"task": args.task, "priority": int(TaskPriority.HIGH)})
    _write_signal(
        cairn_home=args.cairn_home,
        kind="spawn",
        command=command,
    )
    print("queued spawn request")
    return 0


def _run_queue(args: argparse.Namespace) -> int:
    command = parse_command_payload("queue", {"task": args.task, "priority": int(TaskPriority.NORMAL)})
    _write_signal(
        cairn_home=args.cairn_home,
        kind="queue",
        command=command,
    )
    print("queued task request")
    return 0


def _run_list_agents(args: argparse.Namespace) -> int:
    state = _read_state(args.cairn_home)
    agents = state.get("agents", {})
    if not agents:
        print("No active agents")
        return 0

    for agent_id, agent in sorted(agents.items()):
        print(f"{agent_id}\t{agent.get('state')}\t{agent.get('task')}")
    return 0


def _run_status(args: argparse.Namespace) -> int:
    state = _read_state(args.cairn_home)
    agent = state.get("agents", {}).get(args.agent_id)
    if agent is None:
        print(f"Unknown agent: {args.agent_id}")
        return 1

    print(json.dumps(agent, indent=2, sort_keys=True))
    return 0


def _run_accept(args: argparse.Namespace) -> int:
    command = parse_command_payload("accept", {"agent_id": args.agent_id})
    _write_signal(cairn_home=args.cairn_home, kind="accept", command=command)
    print(f"queued accept for {args.agent_id}")
    return 0


def _run_reject(args: argparse.Namespace) -> int:
    command = parse_command_payload("reject", {"agent_id": args.agent_id})
    _write_signal(cairn_home=args.cairn_home, kind="reject", command=command)
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
    spawn_parser.set_defaults(handler=_run_spawn, is_async=False)

    queue_parser = subparsers.add_parser("queue", help="Queue an agent task")
    queue_parser.add_argument("task")
    queue_parser.set_defaults(handler=_run_queue, is_async=False)

    list_parser = subparsers.add_parser("list-agents", help="List active agents")
    list_parser.set_defaults(handler=_run_list_agents, is_async=False)

    status_parser = subparsers.add_parser("status", help="Show agent status")
    status_parser.add_argument("agent_id")
    status_parser.set_defaults(handler=_run_status, is_async=False)

    accept_parser = subparsers.add_parser("accept", help="Accept agent changes")
    accept_parser.add_argument("agent_id")
    accept_parser.set_defaults(handler=_run_accept, is_async=False)

    reject_parser = subparsers.add_parser("reject", help="Reject agent changes")
    reject_parser.add_argument("agent_id")
    reject_parser.set_defaults(handler=_run_reject, is_async=False)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.is_async:
        return asyncio.run(args.handler(args))
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
