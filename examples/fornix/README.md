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

## Reaching the web server: the hard limit (resolved)

**You cannot reach `nixbox-web` from the host when it runs inside a fornix
sandbox.** This is by design, not a gap to patch:

- srt enforces default-deny networking with **`--unshare-net` + a private
  loopback bridge** (fornix's `BACKEND_DECISION.md`). The sandbox gets its *own*
  network namespace, so `nixbox-web` on `127.0.0.1:<webPort>` binds the
  *sandbox's* loopback — invisible to the host's `127.0.0.1`.
- srt's only network egress hatch is a **SOCKS5 proxy for outbound** traffic and
  a per-domain allowlist. There is **no inbound port-publish** and no exposed
  handle to the sandbox netns, so a host-side forwarder has nothing to attach to.
- `network.allowLocalBinding` only governs whether the sandboxed process may bind
  *within its own* namespace — it does not bridge to the host.

So srt is the right tool for **isolating an autonomous agent's execution**
(filesystem + egress), and the wrong tool for **serving an interactive web
terminal you browse to**. Reaching in would require an upstream srt feature
(inbound publish, or a documented netns handle) that doesn't exist today.

### What to do instead

- **Interactive terminal over Tailscale** → use the Docker path
  (`compose.yaml`, optionally `nixbox.tailscale.enable`, or zelligate). That's
  what nixbox is built for.
- **Agent isolation** → keep using fornix, but run the *agent command* in the
  sandbox (`fornix run <id> -- <agent>`), not a web server. The agent can launch
  `nvim`/`znv` for its own use; it just isn't reachable from outside.
