# nixbox

A personal **terminal-only interface** packaged as an importable
[devenv.sh](https://devenv.sh) module: a vendored Neovim config running over a
**Zellij web server**, reachable from a browser. Importable into any devenv repo,
and buildable into a Docker image so each environment can run isolated and be
reached over Tailscale.

## Ecosystem

nixbox is the *environment* in a small stack of independent projects:

| Project | Role |
|---|---|
| **nixbox** (this repo) | The environment: Neovim + Zellij + tooling. Substrate-agnostic. |
| **zelligate** | Access layer: Docker-first orchestrator serving per-repo Zellij web terminals over Tailscale. |
| **fornix / devbox** | Isolation engine for autonomous agents (btrfs + srt sandboxes). Composes later; both speak devenv. |
| **tyo3** | An example repo / interface-style reference. |

## What's inside

- **Neovim** pinned to 0.12.x (for `vim.pack`), wrapped with the vendored config
  in [`modules/config/nvim`](modules/config/nvim) and the LSP servers it expects.
- **Zellij** pinned to match, with the vendored config in
  [`modules/config/zellij`](modules/config/zellij) — `default_layout "nvim"`, so a
  new web session opens straight into Neovim.
- A `zellij web` server as the entrypoint (`nixbox-web`).

The module is **self-contained**: it pins its own Neovim and Zellij via
`fetchTarball`, so an importing repo doesn't need to declare those inputs.

## Use it in another repo

`devenv.yaml`:

```yaml
inputs:
  nixbox:
    url: path:../nixbox/modules   # or github:Bullish-Design/nixbox?dir=modules
    flake: false
imports:
  - nixbox
```

`devenv.nix`:

```nix
{
  nixbox.enable = true;
  # nixbox.webPort = 8920;       # zellij web port (default)
  # nixbox.bind = "127.0.0.1";   # keep loopback; front it externally
  # nixbox.name = "my-repo";     # optional: expose a zelligate manifest
}
```

Then:

```bash
devenv shell
nixbox-preseed     # one-off: clone neovim plugins (needs network)
nixbox-token       # one-off: create a web login token
nixbox-web         # start the zellij web server
```

Open `http://127.0.0.1:8920` (or front it via zelligate/Tailscale).

## Build the container image

```bash
devenv container build nixbox      # produces a Docker image
# run it; entrypoint is `nixbox-web` (processes.nixbox)
```

`bind` stays on loopback by default; public exposure / TLS is handled by an
external forwarder (zelligate's socat, or Tailscale), matching zelligate's
networking model. Binding `zellij web` to a non-loopback address directly
requires `--cert`/`--key`.

## Commands

| Command | What it does |
|---|---|
| `nixbox-web` | Start the zellij web server (`bind:webPort`). |
| `nixbox-token` | Create a zellij web login token. |
| `nixbox-preseed` | Clone `vim.pack` plugins + treesitter (one-off, needs network). |
| `nvim` / `nv` | Neovim with the vendored config. |
| `znv` | Zellij with the `nvim` layout. |

## Notes & deferred work

- **Plugin fetch:** the Neovim config uses `vim.pack`, which clones ~55 plugins at
  runtime. `nixbox-preseed` warms them; without it, the first Neovim launch fetches
  them (needs network + a writable data dir).
- **Deferred:** multi-spawn / one-container-per-env orchestration, fornix-based
  isolation, and baking Tailscale into the image — all out of scope for now.
