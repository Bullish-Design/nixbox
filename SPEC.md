# Cairn Technical Specification

Version: 1.1
Status: Active
Updated: 2026-02-13

## Canonical scope of this document

`SPEC.md` is the single source of truth for:
- current runtime architecture,
- filesystem/runtime contracts,
- orchestrator state and CLI behavior.

For philosophy and constraints, see [CONCEPT.md](CONCEPT.md). For install/quickstart, see [README.md](README.md).

## Runtime architecture

Cairn has three layers:

1. **Storage**: AgentFS overlays backed by SQLite (`stable.db`, `agent-*.db`, `bin.db`).
2. **Execution**: Monty sandbox that runs generated agent code with explicit external functions.
3. **Orchestration**: Python process that manages queueing, execution, review state, and accept/reject.

## Data layout contract

```text
$PROJECT_ROOT/.agentfs/
├── stable.db
├── agent-{id}.db
└── bin.db

$CAIRN_HOME/ (default ~/.cairn)
├── workspaces/
├── previews/
├── signals/
└── state/
```

## Storage contracts (AgentFS)

### Overlay semantics

- Reads in an agent overlay must fall through to stable when a path is absent in the overlay.
- Writes in an agent overlay must only update that overlay.
- Accept copies selected overlay changes into stable.
- Reject discards overlay changes.

### Required operations

- `read_file(path) -> bytes`
- `write_file(path, content) -> None`
- `readdir(path) -> list[DirEntry]`
- `stat(path) -> FileStat`
- `remove(path) -> None`
- `mkdir(path) -> None`
- KV store: `get/set/delete/list`

## Execution contracts (Monty)

### Sandbox policy

Allowed:
- procedural Python constructs,
- async functions,
- calls to declared external functions.

Disallowed:
- imports,
- host filesystem/network access except through external functions,
- subprocess execution,
- implicit environment access.

### Required external functions exposed to agents

- `read_file(path)`
- `write_file(path, content)`
- `list_dir(path)`
- `file_exists(path)`
- `search_files(pattern)`
- `search_content(pattern, path='.')`
- `ask_llm(prompt, context='')`
- `submit_result(summary, changed_files)`
- `log(message)`

## Orchestrator contracts

### Agent lifecycle

`QUEUED -> RUNNING -> REVIEWING -> (ACCEPTED | REJECTED | FAILED)`

### Responsibilities

- monitor signals (`spawn/queue/accept/reject`),
- create per-agent overlays,
- generate/execute agent code,
- materialize preview workspace,
- persist state snapshot under `$CAIRN_HOME/state/`.

### CLI contract (current)

- `cairn up`
- `cairn spawn <task>`
- `cairn queue <task>`
- `cairn list-agents`
- `cairn status <agent-id>`
- `cairn accept <agent-id>`
- `cairn reject <agent-id>`

## Documentation boundaries

To avoid drift:
- `README.md`: setup + first commands only.
- `CONCEPT.md`: conceptual model and invariants only.
- `SPEC.md`: runtime details and contracts only.
- `.agent/skills/*`: implementation workflows that link back to these canonical docs.
