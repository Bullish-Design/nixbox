# AGENT guidance

This repository is a devenv.sh plugin template, not a Python library.

## Mission

Provide a modular, declarative `devenv.sh` setup that runs an AgentFS database
process for sandboxed filesystem workflows.

## Editing rules

1. Prefer built-in devenv constructs (`env`, `packages`, `processes`, `scripts`, `imports`).
2. Keep runtime behavior parameterized via environment variables.
3. Avoid embedding host-specific absolute paths.
4. Keep `devenv.nix` ready for extraction into importable modules.
5. Ensure README and devenv config stay aligned whenever variables/commands change.

## Process contract

`processes.agentfs.exec` should remain the single source of truth for launching the
AgentFS runtime.
