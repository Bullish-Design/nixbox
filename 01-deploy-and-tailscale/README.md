# 01 — Deploy nixbox & connect over Tailscale (dogfooding walkthrough)

A step-by-step run to take nixbox from source to a **running container you log into
from a browser**, first on `localhost`, then **over Tailscale** from any device.

> **This is the first real end-to-end deployment.** The image has been built and
> its entrypoint verified, but nixbox has never actually been `docker run` and
> connected to, and **the Tailscale path is code-complete but never tested against
> a live tailnet**. Treat this as a shakedown — expect rough edges, and jot down
> anything that breaks (see *Report back* at the end) so we can fix the module.

Each step has a **✓ checkpoint** — don't move on until it passes.

---

## 0. Prerequisites

- `docker` and `devenv` on PATH (you have both).
- This repo, on `main` (`v0.5.0`+).
- A **Tailscale account** (for Part B) + the Tailscale app on a second device.
- **Patience on first run:** the container preseeds neovim on startup — it clones
  ~50 `vim.pack` plugins *and* builds `fff`'s Rust backend. Several minutes, and it
  **needs network**. The image is also large (~3 GB+: LSPs + the rust toolchain).

Run everything from the repo root unless noted.

---

## Part A — Local first (prove the image works before Tailscale)

Goal: container running, terminal reachable at `http://localhost:8920`, you land in
neovim. No Tailscale yet — isolate problems one layer at a time.

### A1. Build the image
```bash
devenv container build nixbox
```
✓ **Checkpoint:** it prints a `/nix/store/…-image-nixbox.json` path and exits 0.

### A2. Load it into Docker
```bash
devenv container copy nixbox -r docker-daemon:
docker images | grep nixbox
```
✓ **Checkpoint:** `docker images` shows `nixbox  latest`.

### A3. Start it (with persistence)
`compose.yaml` (repo root) mounts named volumes for `~/.local` + `~/.cache` and uses
`network_mode: host`, so the container's loopback bind is your host's loopback.
```bash
docker compose up        # add -d to detach; here we watch the logs
```
Watch the logs go through:
1. `nixbox: seeding neovim plugins (vim.pack)…` → a long download list (~50 plugins).
2. `nixbox: building native plugin binaries (fff)…` (cargo build).
3. `nixbox: no login token yet — creating one (shown once):` then
   `token_1: <uuid>` — **copy that token**.
4. `nixbox: starting zellij web on 127.0.0.1:8920`.

✓ **Checkpoint** (new terminal):
```bash
curl -sI http://127.0.0.1:8920/ | head -1     # -> HTTP/1.0 200 OK
```
> Lost the token? `docker compose logs nixbox | grep -i token`, or mint a new one:
> `docker compose exec nixbox nixbox-token` (if PATH isn't set in the exec shell,
> read it from the logs instead).

### A4. Connect in a browser
Open **http://localhost:8920**:
1. A **"Security Token Required"** modal → paste the token → Enter.
2. The **session manager** appears → type a session name (e.g. `work`) → **Enter**.
3. A **layout list** appears with `nvim` highlighted → **Enter** to create it.
4. **First run only:** a Zellij **release-notes** popup → press **Esc**. Then
   plugin permission prompts (`Allow? (y/n)` for autolock/attention) → press **y**
   (granted once, then cached on the volume).

✓ **Checkpoint:** you're in **neovim** (dashboard / statusline visible);
`:e README.md` then `<Enter>` shows a file with syntax highlighting.

### A5. Persistence check
```bash
docker compose restart
```
Reconnect at `localhost:8920` with the **same token**.
✓ **Checkpoint:** no re-preseed (plugins already on the volume), session/token persist.

### A6. Teardown (local)
```bash
docker compose down        # stop, keep volumes (plugins/token survive)
# docker compose down -v   # also wipe the volumes (forces a fresh preseed next time)
```

If Part A worked, the image itself is good. On to Tailscale.

---

## Part B — Tailscale ⚠️ (the never-tested path)

Goal: the container joins your tailnet and serves the terminal over Tailscale, so
you can reach it from any device — no host networking, no port-forwarding.

> This exercises `nixbox.tailscale.*` for the first time on a real tailnet. If
> something's off, it's most likely here — Part B has the most diagnosis steps.

### B1. Get a Tailscale auth key
Tailscale admin console → **Settings → Keys → Generate auth key**. Make it reusable
if you'll rebuild a lot; ephemeral if you want the node to vanish on stop. Copy the
`tskey-auth-…` value.

Also: **enable HTTPS certificates** for your tailnet (admin → DNS → enable MagicDNS
+ HTTPS Certificates). `tailscale serve` needs this to provision the cert.

### B2. Turn on Tailscale in the image and rebuild
Edit `devenv.nix` (repo root):
```nix
  nixbox.tailscale.enable = true;
  nixbox.tailscale.hostname = "nixbox";     # becomes nixbox.<tailnet>.ts.net
  # nixbox.tailscale.funnel = true;         # ONLY if you want it on the public internet
```
Rebuild and reload:
```bash
devenv container build nixbox
devenv container copy nixbox -r docker-daemon:
```
✓ **Checkpoint:** rebuild succeeds; the image now contains `tailscale`.

### B3. Run it with the auth key (bridge networking, not host)
Use the override in this directory (it switches off `network_mode: host` so the
container's *own* userspace Tailscale is the network path, and injects the key):
```bash
export TS_AUTHKEY=tskey-auth-xxxxxxitsasecret
docker compose -f compose.yaml -f 01-deploy-and-tailscale/compose.tailscale.yaml up
```
Watch for:
```
nixbox: starting tailscaled (userspace networking)
nixbox: tailscale up (hostname=nixbox)
nixbox: serve -> http://127.0.0.1:8920
nixbox: starting zellij web on 127.0.0.1:8920
```

### B4. Validate the Tailscale path (the crux)
1. **Device registered:** Tailscale admin console → the **`nixbox`** machine appears
   and is **online**.
2. **From inside the container:**
   ```bash
   sock=/env/.cache/../.local/share/nixbox/tailscale   # state dir on the volume
   docker compose exec nixbox sh -lc \
     'tailscale --socket="${XDG_RUNTIME_DIR:-/tmp}/nixbox-tailscaled.sock" status'
   docker compose exec nixbox sh -lc \
     'tailscale --socket="${XDG_RUNTIME_DIR:-/tmp}/nixbox-tailscaled.sock" serve status'
   ```
   ✓ status shows the node connected; `serve status` shows
   `https://nixbox.<tailnet>.ts.net` → `http://127.0.0.1:8920`.
3. **From a second device on your tailnet:** open
   **`https://nixbox.<your-tailnet>.ts.net`** → the same token modal → … → neovim.

✓ **Final checkpoint:** you're editing in neovim, in a browser, on a different
machine, over Tailscale.

### B5. Likely failure points (since untested) and how to read them
| Symptom | Where to look / fix |
|---|---|
| No `nixbox` node in admin console | `TS_AUTHKEY` not passed / expired. Check container logs and `…/tailscale/tailscaled.log` on the volume. |
| Node online but page won't load over `.ts.net` | `tailscale serve` failed — check `serve status`; confirm the web server is up (`curl` inside container to `127.0.0.1:8920`). |
| Cert error on `https://…ts.net` | HTTPS certificates not enabled for the tailnet (B1). |
| `serve` rejects the args | We call `tailscale serve --bg <port>`; if your `tailscale` version differs, the CLI may want `tailscale serve --bg http://127.0.0.1:8920`. Note the exact error to feed back. |
| Want it on the public internet | `nixbox.tailscale.funnel = true` (B2) + tailnet Funnel enabled in admin. |

### B6. Teardown
```bash
docker compose -f compose.yaml -f 01-deploy-and-tailscale/compose.tailscale.yaml down
# revert devenv.nix (nixbox.tailscale.enable = false) if you don't want it in the default image
```

---

## Verification checklist

- [ ] `devenv container build` + `copy` → `nixbox:latest` in Docker
- [ ] container starts; preseed completes; token printed in logs
- [ ] **A:** `localhost:8920` → token → session wizard → neovim (edits a file)
- [ ] **A:** restart → no re-preseed, token/session persist
- [ ] **B:** `nixbox` device online in the Tailscale admin console
- [ ] **B:** `tailscale serve status` shows `…ts.net → 127.0.0.1:8920`
- [ ] **B:** reachable from a second device → neovim over Tailscale

## Troubleshooting (general)

- **Preseed hangs / no plugins:** the container needs outbound network on first run
  (plugin clones + cargo). Behind a proxy/offline, it will stall — run it somewhere
  with network once; the volume then carries everything.
- **Port 8920 already in use (Part A, host mode):** something else holds it on the
  host (a stray `zellij web`?). `ss -ltnp | grep 8920`.
- **`fff` still errors:** confirm `nixbox.nvimBuildTools.enable` is on and the
  preseed's "building native plugin binaries (fff)" step ran (logs).
- **Can't `exec` commands (no PATH):** the entrypoint sets up the devenv env; a bare
  `docker exec` may not inherit it. Prefer reading logs, or
  `docker compose exec nixbox sh -lc '<cmd>'`.

## Report back

This is a discovery run. Note, per step: what worked, what broke, exact error text
(especially anything in Part B). That feedback is what turns the untested Tailscale
path into a verified one — and likely the next round of module fixes.
