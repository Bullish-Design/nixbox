# nixbox

`nixbox` is now a **devenv.sh modular plugin template** for running a local
[AgentFS](https://docs.turso.tech/agentfs/introduction) database process inside sandboxed development
filesystems.

## What this plugin provides

- A configurable `agentfs` process under `processes.agentfs`.
- Built-in environment variables for all runtime knobs.
- The upstream `agentfs` CLI available directly in the dev shell.
- Helper scripts to inspect or connect to the local AgentFS instance.
- A layout that can be copied into any devenv project and split into modules.

## Configuration model

All configuration is done through standard devenv functionality (`env`, `packages`, `processes`, `scripts`):

| Variable | Default | Purpose |
| --- | --- | --- |
| `AGENTFS_ENABLED` | `1` | Toggle process startup (`1` = enabled, `0` = disabled). |
| `AGENTFS_HOST` | `127.0.0.1` | Bind host for the AgentFS process. |
| `AGENTFS_PORT` | `8081` | Bind port for the AgentFS process. |
| `AGENTFS_DATA_DIR` | `.devenv/state/agentfs` | Persistent local data directory. |
| `AGENTFS_DB_NAME` | `sandbox` | Logical database name used for local sandboxing. |
| `AGENTFS_LOG_LEVEL` | `info` | Log level forwarded to the runtime command. |
| `AGENTFS_EXTRA_ARGS` | *(empty)* | Escape hatch for additional runtime flags. |

## Quick start

1. Enter the shell:

   ```bash
   devenv shell
   ```

2. Start background processes:

   ```bash
   devenv up
   ```

3. Inspect effective runtime settings:

   ```bash
   devenv run agentfs-info
   ```

## Module usage pattern

You can factor this repo into reusable modules by moving the AgentFS block into
something like `modules/agentfs.nix` and importing it from your own `devenv.nix`:

```nix
{
  imports = [ ./modules/agentfs.nix ];
}
```

## Notes

- `devenv.nix` pins the upstream AgentFS flake (`github:tursodatabase/agentfs`) and exposes its default package in `packages`, so the `agentfs` binary is always available in-shell.
- This template expects a Turso CLI that supports AgentFS subcommands.
- If your CLI version differs, adjust `processes.agentfs.exec` and keep all options in
  `env` variables so downstream projects remain declarative.
