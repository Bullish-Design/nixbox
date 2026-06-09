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
{ pkgs, ... }:
{
  nixbox.enable = true;
  # nixbox.webPort = 8920;       # zellij web port (default)
  # nixbox.bind = "127.0.0.1";   # keep loopback; front it externally
  # nixbox.name = "my-repo";     # optional: expose a zelligate manifest

  # Image size levers (see "Image size" below):
  # nixbox.lspServers = with pkgs; [ ty ruff nil lua-language-server ];
  # nixbox.allTreesitterGrammars = false;   # default; true bundles all (~+240MB)

  # Join a tailnet and serve the web port directly (see "Tailscale" below):
  # nixbox.tailscale.enable = true;
  # nixbox.tailscale.hostname = "my-box";
}
```

Then:

```bash
devenv shell
nixbox-start       # preseed plugins (first run) + start the web server
```

`nixbox-start` is the entrypoint: it runs `nixbox-preseed` once (clones the
`vim.pack` plugins — needs network the first time) and bootstraps a web login
token, then starts the server. Open `http://127.0.0.1:8920` (or front it via
zelligate / `tailscale serve`).

## Build & run the container image

```bash
devenv container build nixbox      # produces a nix2container image (entrypoint: nixbox-start)
docker compose up                  # run it with persistent state (see compose.yaml)
```

`compose.yaml` mounts named volumes for `~/.local` and `~/.cache` so the plugin
preseed and web token happen only once and survive restarts, and uses
`network_mode: host` so the loopback bind is reachable (front it with
`tailscale serve` / a reverse proxy). `bind` stays on loopback by default;
non-loopback binds need `--cert`/`--key`, so public exposure / TLS is handled by
an external forwarder (zelligate's socat, or Tailscale), matching zelligate.

## Tailscale

Instead of host networking, the container can join your tailnet and serve the
web port directly (userspace networking — no `/dev/net/tun`, no privileged
container):

```nix
nixbox.tailscale.enable = true;
nixbox.tailscale.hostname = "my-box";
# nixbox.tailscale.funnel = true;            # expose to the public internet
# nixbox.tailscale.extraUpArgs = [ "--ssh" ];
```

Pass an auth key at run time (`TS_AUTHKEY`), e.g. in `compose.yaml`:

```yaml
services:
  nixbox:
    environment:
      - TS_AUTHKEY=tskey-auth-...      # or use an env_file / secret
```

`nixbox-start` then runs `tailscaled --tun=userspace-networking`, `tailscale up`,
and `tailscale serve --bg <webPort>` — so the terminal is reachable at
`https://<hostname>.<tailnet>.ts.net` with no host-network or forwarder. State
persists on the data volume, so re-auth isn't needed on restart.

## Image size

The default image is large because the bundled LSP servers (especially the
node-based ones) dominate. Measured sizes of the nix2container image:

| Config | Size |
|---|---|
| original (`withAllGrammars` + all LSPs) | ~2.95 GB |
| **default** (curated grammars + all LSPs) | ~2.71 GB |
| lean (curated grammars + `[ ty ruff nil lua-language-server rust-analyzer markdown-oxide ]`) | **~1.62 GB** |

Two levers:

- **`nixbox.lspServers`** — the biggest one. The node-based servers are heavy
  (basedpyright ~880 MB, vtsls ~450 MB, vscode-langservers-extracted ~310 MB,
  yaml-language-server ~260 MB). Trim the list to what you use; e.g.
  `nixbox.lspServers = with pkgs; [ ty ruff nil lua-language-server ];`.
- **`nixbox.allTreesitterGrammars`** — `false` (default) bundles a curated common
  set (~60 MB vs ~300 MB); other languages' grammars install at runtime. Set
  `true` to bundle everything.

## Offline / vendored plugins

The image runs without network at startup once warmed:

- **Zellij plugins** (`autolock`, `attention`, `bookmarks`, `zjstatus`) are
  vendored as `.wasm` under `modules/config/zellij/plugins/`; the module rewrites
  the config's plugin URLs to local `file:` paths. Refresh with
  `scripts/fetch-zellij-plugins.sh`.
- **Neovim `vim.pack` plugins** are fetched once by `nixbox-preseed` and persisted
  to the data volume.

This is what makes nixbox usable inside fornix's default-deny sandbox — see
[`examples/fornix`](examples/fornix).

## Keeping configs in sync with ~/.dotfiles

The vendored configs are a snapshot. Re-sync after changing your dotfiles:

```bash
scripts/sync-config.sh            # re-vendor nvim/ + zellij/ (preserves plugins/)
```

## Commands

| Command | What it does |
|---|---|
| `nixbox-start` | Entrypoint: preseed (once) + token bootstrap + (optional tailscale) + web server. |
| `nixbox-web` | Start the zellij web server (`bind:webPort`); bootstraps a token. |
| `nixbox-token` | Create a zellij web login token. |
| `nixbox-preseed` | Clone `vim.pack` plugins + treesitter (one-off, needs network). |
| `nixbox-tailscale` | (when `tailscale.enable`) bring up tailscaled + `tailscale serve`. |
| `nixbox-selfcheck` | Verify the setup: static invariants + a live "web server binds & serves HTTP" check. |
| `nvim` / `nv` | Neovim with the vendored config. |
| `znv` | Zellij with the `nvim` layout. |

## Demos (Playwright addon)

An opt-in dev addon (`nixbox.playwright.enable`) drives the *live* web terminal
in a headless browser and records GIFs — end-to-end proof the whole stack works
in a real browser (token auth → zellij web session → neovim editing a file):

```bash
cd demos
devenv shell -- ./run.sh        # writes demos/output/*.gif
```

It pre-grants the zellij plugin permissions, warms neovim's plugins, then drives
chromium through the session wizard into the `nvim` layout and captures the
result (`modules/playwright/demo.cjs`; customise scenarios with `DEMO_STEPS`).
The addon is kept in a **separate `demos/` environment** so the lean runtime /
container never pulls in node + chromium. CI runs it and uploads the GIFs as
artifacts. See [`demos/`](demos) and the fixtures in
[`tests/fixtures`](tests/fixtures).

## Testing / CI

`nixbox-selfcheck` is a self-contained verification you can run anywhere
(`devenv shell -- nixbox-selfcheck`) or via `devenv test` (wired through
`enterTest`). It checks:

1. all commands resolve (`nvim`, `znv`, `nixbox-web`, …);
2. Neovim is ≥ 0.12 (vim.pack-capable);
3. the zellij web config is offline — plugin URLs rewritten to `file:`, vendored
   `.wasm` present;
4. **live** — it actually starts the zellij web server, confirms the port binds
   and returns HTTP, and that a login token is bootstrapped, then cleans up.

Step 4 is the important one: the "web server printed *started* but never bound"
bug is only catchable by really connecting to it. It needs no network (plugins
are vendored) and leaves no stray server. The GitHub Actions workflow
(`.github/workflows/ci.yml`) runs the self-check and a `devenv container build`
on every push.

## Scope: the isolation model

nixbox is the *environment*; isolation and multi-environment spawning are owned by
the surrounding tools, split along two axes — **who runs the code** and **how hard
the boundary needs to be**:

| Need | Owner | Status |
|---|---|---|
| Many **interactive** terminals over Tailscale, *soft* isolation (your own cooperating repos) | **zelligate** (1 container, per-repo process/port/XDG isolation) | available |
| Parallel **autonomous-agent** sandboxes — disposable, hard filesystem + egress isolation | **fornix** (btrfs fork + srt `--unshare-net`) | integrated — see [`examples/fornix`](examples/fornix) |
| Many **interactive** terminals, each with a **hard kernel/container boundary** | a Docker one-container-per-env spawner | **intentionally out of scope** |

**The one-container-per-interactive-env spawner is a deliberate non-goal.** It is
only needed to run *untrusted or mutually-distrusting* code in different
browse-to terminals. For the actual use case — your own projects — zelligate's
soft isolation is sufficient, and for autonomous agents fornix already provides a
hard boundary. fornix cannot serve this case itself: srt's `--unshare-net` private
network namespace makes an in-sandbox web server unreachable from the host (full
analysis in [`examples/fornix`](examples/fornix)). Revisit only if a "hard
boundary between interactive envs" requirement appears.

Image size and Tailscale are addressed above. The `github:…?dir=modules` import
form is verified end-to-end (a bare repo importing nixbox gets a working
`nvim`/`nixbox-web`, vendored wasm included).
