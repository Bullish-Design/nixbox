# Running nixbox inside a fornix sandbox

[fornix](../../../devbox) gives disposable, isolated dev sandboxes
(btrfs-subvolume forks + srt/bubblewrap, default-deny network). This example
shows how to run the nixbox terminal inside one for agent-grade isolation.

The pieces compose because **both speak devenv**: fornix captures the devenv on
the host and runs commands in the sandbox, and nixbox is a devenv module.

## Setup

Use the files here (`devenv.yaml` + `devenv.nix`) as your fornix `repo-main`.
They import nixbox and — importantly — redirect `XDG_DATA_HOME`/`XDG_CACHE_HOME`
*into the workspace*:

```nix
env.XDG_DATA_HOME  = "${config.devenv.root}/.nixbox/data";
env.XDG_CACHE_HOME = "${config.devenv.root}/.nixbox/cache";
```

## The two network problems (and how this example solves them)

fornix runs sandboxes with `FORNIX_NETWORK=none` by default, so anything that
fetches at runtime breaks. nixbox would otherwise fetch in two places:

1. **Zellij plugins** — already solved: nixbox vendors the `.wasm` and rewrites
   the config to local `file:` paths. No network needed.
2. **Neovim `vim.pack` plugins** — clone from GitHub on first launch. Solve it
   by **preseeding on the host before forking**, into the in-workspace
   `XDG_DATA_HOME` above, so the btrfs fork carries the plugins:

   ```bash
   cd repo-main
   devenv shell -- nixbox-preseed     # populates ./.nixbox/data (needs network, once)
   ```

   (Alternatively run the first fork with `FORNIX_NETWORK=allowlist` and
   `FORNIX_ALLOWLIST=github.com,*.githubusercontent.com,objects.githubusercontent.com`.)

## Run

```bash
fornix doctor                          # host substrate must be provisioned
fornix fork demo                       # snapshot repo-main -> sandbox 'demo'
fornix run demo -- nixbox-web          # start the terminal inside the sandbox
```

or set `FORNIX_AGENT_COMMAND=nixbox-web` so `fornix run demo` launches it.

## Open integration point: reaching the web server

`nixbox-web` binds `127.0.0.1:<webPort>` *inside the sandbox*. Whether you can
reach it from the host depends on srt's network model:

- **Shared network namespace** → the bind is on the host's loopback; reach it at
  `127.0.0.1:<webPort>` (front with `tailscale serve`).
- **Isolated namespace** → use srt's SOCKS5 proxy, or run a forwarder, to bridge
  in. (srt is built for *egress* control of agents, not inbound serving, so this
  is the part that needs validation for interactive use.)

For interactive terminals reached over Tailscale, the Docker path
(`compose.yaml` + zelligate) is currently the smoother option; fornix shines for
**autonomous-agent** isolation where inbound reachability matters less.
