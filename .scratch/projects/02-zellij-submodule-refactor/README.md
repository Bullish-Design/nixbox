# 02 — Zellij submodule extraction + review-driven refactor

Runbook for acting on the code-review findings. The headline change (M1) extracts
the Zellij layer into an **in-repo submodule** with a single source of truth for the
plugin set; the rest are smaller correctness/robustness fixes. Each phase is
independently shippable — land them as separate commits in order.

## Decision record

- **M1 structure:** in-repo submodule (`modules/zellij/default.nix`), imported by
  `modules/devenv.nix` via a **relative path**. Chosen over a separate repo because:
  - Relative-path imports survive *both* consumption forms (`path:../nixbox/modules`
    and `github:Bullish-Design/nixbox?dir=modules`) — flake:false inputs are copied
    into the store with their directory structure intact, so `imports = [ ./zellij ]`
    resolves downstream with **zero new pinned inputs**. Self-containment is preserved.
  - A separate repo would have to be pulled in *from inside* `modules/devenv.nix` via
    `fetchTarball(rev+sha)` (NOT via `devenv.yaml` — downstream consumers don't
    evaluate nixbox's `devenv.yaml`, only `modules/devenv.nix`), adding a second repo
    to version-bump on every zellij change. Defer that until a second consumer
    (zelligate) concretely wants to share the module.
- **Extraction ≠ dedup.** Moving the code does not dedupe it. The single-attrset
  refactor (M1 core) happens *inside* the new submodule and is the actual fix for the
  duplicated plugin list. The submodule boundary is a bonus, not the fix.

## Findings → phases

| Phase | Finding | Severity | One-line |
|---|---|---|---|
| 1 | M1 | med | Zellij submodule + single plugin attrset (4 lists → 1) |
| 2 | M2 | med | Enforce/warn on non-loopback `bind`; selfcheck honors `cfg.bind` |
| 3 | M3 | med | Stop leaking the web token into container logs |
| 4 | L1 | low | Document/harden the `vim.pack` sync-clone assumption in preseed |
| 4 | L2 | low | Note `nixbox-tailscale` single-daemon assumption; optional pidfile guard |
| 4 | L3 | low | Flag demo-driver timing brittleness (doc-only) |
| 4 | nits | — | sentinel semantics, token regex coupling, version single-source |

---

## Phase 0 — baseline

Get a green tree before touching anything, so every later step has a known-good
comparison point.

```bash
devenv shell -- nixbox-selfcheck       # must end "ALL PASS"
git switch -c refactor/zellij-submodule
```

Keep `nixbox-selfcheck` as the regression oracle throughout — it already does the
live bind/serve check, which is exactly what could break during the extraction.

---

## Phase 1 — M1: Zellij submodule + single source of truth

### Goal

```
modules/
  devenv.nix              # neovim wrapper + composition + entrypoints; imports = [ ./zellij ]
  zellij/
    default.nix           # ALL zellij packaging: plugin attrset, patch, web config, permissions
    plugins.nix           # the single source of truth: name -> upstream URL
  config/zellij/...        # unchanged (vendored-from-dotfiles configs + plugins/*.wasm)
```

Downstream `imports: [nixbox]` is unaffected — they still import `modules/devenv.nix`,
which now pulls the submodule transitively via the relative path.

### Step 1.1 — the single source of truth

Create `modules/zellij/plugins.nix`. **Attr names must equal the vendored wasm
basenames** (`<name>.wasm`) — that invariant is what lets the rewrite/permissions/fetch
all derive from this one file.

```nix
# modules/zellij/plugins.nix
# Single source of truth for the vendored Zellij plugins. Consumed by:
#   - modules/zellij/default.nix  (URL->file: rewrite + pre-granted permissions)
#   - scripts/fetch-zellij-plugins.sh  (download, via `nix eval`)
# The attr NAME is the vendored basename: <name> -> config/zellij/plugins/<name>.wasm
# To add/remove a plugin, edit ONLY this file (then re-run fetch-zellij-plugins.sh).
{
  autolock  = "https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm";
  attention = "https://github.com/KiryuuLight/zellij-attention/releases/latest/download/zellij-attention.wasm";
  bookmarks = "https://github.com/yaroslavborbat/zellij-bookmarks/releases/latest/download/zellij-bookmarks.wasm";
  zjstatus  = "https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm";
}
```

### Step 1.2 — the submodule

Create `modules/zellij/default.nix`. It owns everything zellij and exposes the
computed derivations to the parent through **internal read-only options**
(`config.nixbox.zellij._*`) — the clean module-system way to hand computed values
between merged modules. It reads the shared `nixbox.bind` / `nixbox.webPort` options
(declared in the parent; option declarations merge, so they're visible here).

```nix
# modules/zellij/default.nix — Zellij packaging for nixbox (offline web terminal).
{ pkgs, lib, config, ... }:
let
  cfg = config.nixbox;
  system = pkgs.stdenv.hostPlatform.system;

  zellijPkgs = import (builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/265473c9181f3b18295d634c844bdf7761a18594.tar.gz";
    sha256 = "sha256-UEkQrTl36JeCF1VJCyq0zCiSTwWDdiLYtUiCvRju7NA=";
  }) { inherit system; };
  zellij = zellijPkgs.zellij;

  zellijConfig  = ../config/zellij;          # NOTE: ../ now that we're one dir deeper
  zellijPlugins = ../config/zellij/plugins;

  plugins = import ./plugins.nix;
  pluginNames = lib.attrNames plugins;

  # URL -> local file: rewrite, derived from plugins.nix (was a hand-kept 4-line sed).
  rewriteArgs = lib.concatMapStringsSep " \\\n      "
    (n: ''-e "s|${plugins.${n}}|$f/${n}.wasm|g"'') pluginNames;

  zellijConfigPatched = pkgs.runCommand "nixbox-zellij-config" { } ''
    cp -r ${zellijConfig} "$out"
    chmod -R +w "$out"
    rm -rf "$out/plugins"
    f="file:${zellijPlugins}"
    find "$out" -name '*.kdl' -print0 | xargs -0 sed -i \
      ${rewriteArgs}
  '';

  zellijWebConfig = pkgs.runCommand "nixbox-zellij-web.kdl" { } ''
    cp ${zellijConfigPatched}/config.kdl "$out"
    chmod +w "$out"
    cat >> "$out" <<KDL

// nixbox: web server (generated)
layout_dir "${zellijConfigPatched}/layouts"
web_server true
web_server_ip "${cfg.bind}"
web_server_port ${toString cfg.webPort}
KDL
  '';

  zellijPermissions = pkgs.writeText "nixbox-zellij-permissions.kdl" (
    lib.concatMapStrings (n: ''
      "${zellijPlugins}/${n}.wasm" {
          ReadApplicationState
          ChangeApplicationState
          ReadCliPipes
          MessageAndLaunchOtherPlugins
      }
    '') pluginNames
  );
in
{
  options.nixbox.zellij = {
    # The four computed outputs the parent module consumes. internal+readOnly so
    # they don't show up as user-settable options.
    package      = lib.mkOption { type = lib.types.package; internal = true; readOnly = true; };
    patchedConfig = lib.mkOption { type = lib.types.package; internal = true; readOnly = true; };
    webConfig    = lib.mkOption { type = lib.types.package; internal = true; readOnly = true; };
    permissions  = lib.mkOption { type = lib.types.package; internal = true; readOnly = true; };
    pluginCount  = lib.mkOption { type = lib.types.int;     internal = true; readOnly = true; };
  };

  config = lib.mkIf cfg.enable {
    nixbox.zellij = {
      package       = zellij;
      patchedConfig = zellijConfigPatched;
      webConfig     = zellijWebConfig;
      permissions   = zellijPermissions;
      pluginCount   = lib.length pluginNames;
    };
  };
}
```

> Alternative considered: a plain function (`import ./zellij { inherit pkgs lib; cfg = config.nixbox; }`
> returning `{ package; webConfig; … }`) is less ceremony than internal options. Either
> works; the module form was chosen to match `imports = [ ./zellij ]`. If you find the
> readonly-option boilerplate noisy, the function form is a fine substitution — it
> changes only *how the parent reaches the values*, not the dedup.

### Step 1.3 — slim down `modules/devenv.nix`

In `modules/devenv.nix`:

1. Add the import at the top of the returned attrset:
   ```nix
   {
     imports = [ ./zellij ];
     options.nixbox = { ... };   # unchanged
     ...
   }
   ```
   (devenv/NixOS modules allow `imports`, `options`, and `config` as siblings.)

2. **Delete** these `let` bindings (now in the submodule): `zellijPkgs`, `zellij`,
   `zellijConfig`, `zellijPlugins`, `zellijConfigPatched`, `zellijWebConfig`,
   `zellijPermissions`. Keep everything neovim/treesitter.

3. Repoint references to the submodule outputs:
   | was | now |
   |---|---|
   | `zellij` | `config.nixbox.zellij.package` |
   | `zellijConfigPatched` | `config.nixbox.zellij.patchedConfig` |
   | `zellijWebConfig` | `config.nixbox.zellij.webConfig` |
   | `zellijPermissions` | `config.nixbox.zellij.permissions` |
   | `zellijPlugins` | `config.nixbox.zellij.patchedConfig` is wasm-free; for the selfcheck's wasm-count use a new `config.nixbox.zellij.pluginCount` (see below) |

   These appear in: `znv`, `packages = [ … zellij … ]`, `nixbox-web`, `nixbox-token`,
   the `processes`/selfcheck cleanup, and the playwright block (`zellijPermissions`,
   `zellijWebConfig`). Grep to be exhaustive:
   ```bash
   grep -n 'zellij\(Config\|Web\|Permissions\|Plugins\)\|\bzellij\b' modules/devenv.nix
   ```
   Because `znv` etc. are built in `let` but only *used* in `config`, referencing
   `config.nixbox.zellij.*` from those `let` bindings is fine (lazy eval).

4. **Selfcheck step [3]** — replace the magic `-ge 4` with the real count, and drop the
   now-removed `zellijPlugins` path. Either glob the patched store path's sibling
   `plugins/` (gone after patch) — simpler: assert against `pluginCount`:
   ```sh
   want=${toString config.nixbox.zellij.pluginCount}
   n=$(grep -oE 'file:[^ ]*\.wasm' "${config.nixbox.zellij.webConfig}" | sort -u | wc -l)
   # (webConfig is config.kdl only; for a wasm-on-disk count, keep a vendored-dir check)
   ```
   Simplest robust form: keep counting vendored wasm on disk but compare to `pluginCount`:
   ```sh
   n=$(ls ${zellijPlugins}/*.wasm 2>/dev/null | wc -l)   # zellijPlugins -> ../config/zellij/plugins
   if [ "${"$"}{n:-0}" -eq "$want" ]; then pass "$n/$want vendored wasm present"; else fail "$n/$want wasm"; fi
   ```
   (Expose the vendored dir too, e.g. `config.nixbox.zellij.pluginDir`, if you want to
   avoid hardcoding the path in the parent.)

### Step 1.4 — make `fetch-zellij-plugins.sh` derive from the source

Replace the hardcoded `fetch …` block (`scripts/fetch-zellij-plugins.sh:22-25`) with a
loop driven by `plugins.nix`, so the fetch list can never drift from the rewrite list:

```bash
# read name->url from the single source of truth
eval "$(nix eval --raw --impure --expr '
  let p = import '"$REPO"'/modules/zellij/plugins.nix;
  in builtins.concatStringsSep "\n"
       (builtins.map (n: "fetch " + n + ".wasm " + p.${n}) (builtins.attrNames p))
')"
```

(or `nix eval --json` + `jq -r 'to_entries[] | "\(.key).wasm \(.value)"'` and loop with
`read`). Either way the script becomes a *consumer* of `plugins.nix`, not a second copy.

### Step 1.5 — docs

- `modules/config/VENDORING.md`: note that the plugin set is now defined in
  `modules/zellij/plugins.nix`, and `default.nix` derives the rewrite + permissions.
- README "Offline / vendored plugins": one-line pointer to `modules/zellij/plugins.nix`
  as the place to add/remove a plugin.

### Verify Phase 1

```bash
devenv shell -- nixbox-selfcheck     # ALL PASS, incl. live bind + correct wasm count
devenv container build nixbox        # exercises the runCommand derivations
( cd demos && devenv shell -- ./run.sh )   # permissions still pre-granted (no y/n prompt)
git -C . grep -n 'zellij' modules/devenv.nix   # should only show submodule-output refs
```

Acceptance: adding a hypothetical 5th plugin requires editing **only**
`modules/zellij/plugins.nix` + dropping its `.wasm`; rewrite, permissions, fetch, and
the selfcheck count all follow automatically.

---

## Phase 2 — M2: `bind` correctness is enforced, not just documented

Today a non-loopback `bind` (e.g. `0.0.0.0`) silently produces a server that can't bind
(zellij web needs `--cert`/`--key` off-loopback), discoverable only at runtime; and
`nixbox-selfcheck` hardcodes `127.0.0.1` so it never exercises a custom bind.

1. **Build-time warning** (in `modules/zellij/default.nix`, wrap `webConfig`):
   ```nix
   isLoopback = b: b == "127.0.0.1" || b == "localhost" || b == "::1";
   zellijWebConfig = lib.warnIf (!isLoopback cfg.bind)
     "nixbox: bind='${cfg.bind}' is non-loopback; zellij web requires --cert/--key off loopback. Front it with tailscale serve / a reverse proxy and keep bind on loopback."
     (pkgs.runCommand "nixbox-zellij-web.kdl" { } ''…'');
   ```
   (Prefer `lib.warnIf` over `assertions` — devenv doesn't reliably evaluate the NixOS
   `assertions` option, and a hard failure would block the legit `--cert`/`--key` path.)

2. **Selfcheck honors `cfg.bind`** (`modules/devenv.nix`, step [4]). Connect to a host
   derived from the bind instead of a literal:
   ```sh
   checkhost=${if (cfg.bind == "0.0.0.0" || cfg.bind == "::") then "127.0.0.1" else cfg.bind}
   ```
   then replace the two `/dev/tcp/127.0.0.1/$port` uses with `/dev/tcp/$checkhost/$port`.

Verify: `nixbox.bind = "0.0.0.0"` build prints the warning; selfcheck on default bind
still passes.

---

## Phase 3 — M3: stop leaking the web token into logs

The token is the only auth on the web terminal, and under `processes.nixbox` /
the container entrypoint `--create-token`'s stdout lands in the process/container log
in plaintext (and persists there). `tailscale.funnel = true` makes that terminal
public — so this matters.

Change the bootstrap to write the token to a mode-600 file on the data volume and print
only its **location**, with an explicit opt-in to echo it:

- `nixbox-web` (`modules/devenv.nix`): replace the inline `--create-token` with a call to
  `nixbox-token --bootstrap` (below), and on success print
  `"nixbox: web token written to $tokfile (chmod 600); reveal with 'nixbox-token --show'"`.
- `nixbox-token`: support
  - default / `--bootstrap`: create token, write to
    `"${"$"}{XDG_DATA_HOME:-$HOME/.local/share}/nixbox/web-token"` with `umask 077`, don't echo.
  - `--show`: `cat` the saved token (the one explicit reveal path).
  Keep the existing sentinel logic but key it off the token file's existence so the two
  can't desync (see nit below).

Verify: first `nixbox-web` run prints a path, not the token; `nixbox-token --show` prints
it; `grep` of the process log finds no token; selfcheck's "login token bootstrapped"
check still passes (point it at the new file).

> Document the residual: even file-based, anyone with read access to the data volume can
> read the token — that's inherent to a bearer-token model. Note it in the README
> security framing alongside the `funnel` warning.

---

## Phase 4 — low-severity hardening + nits

Smaller, mostly doc/comment changes; batch into one commit.

### L1 — `vim.pack` sync-clone assumption (`nixbox-preseed`)

`nvim --headless +qa!` assumes `vim.pack.add` clones complete before quit. Add a comment
making the assumption explicit (the `--config` insight got this treatment; this didn't),
and optionally guard the quit until packs settle:
```sh
# Assumes vim.pack.add clones synchronously during startup; the follow-up
# vim.pack.update reconciles if a clone lands late. If vim.pack ever clones async,
# replace +qa! with a wait on vim.pack readiness before quitting.
```

### L2 — `nixbox-tailscale` single-daemon assumption

`tailscaled` is backgrounded and never reaped — correct for the container entrypoint,
racy under repeated host `devenv up`. Add a comment, and optionally a pidfile guard:
```sh
# Intended for the container entrypoint (one tailscaled for the box's lifetime), not
# repeated host invocation. The socket `status` probe is the only dedup; add a pidfile
# guard here if you start running this on a long-lived dev host.
```

### L3 — demo driver brittleness (`modules/playwright/demo.cjs`)

Fixed `sleep()`s + blind Enter/Escape to walk the session wizard will break on any
zellij UI-flow change and flake under CI load. It's an artifact generator, not the
verification layer (that's `nixbox-selfcheck`). Action is **doc-only**: a header comment
stating it's intentionally timing-based and not a test, so nobody mistakes a flaky GIF
job for a real regression. Only invest in selector-based waits if the GIF job starts
failing regularly.

### Nits

- **Sentinel semantics** (`nixbox-web`): the `web-token-created` sentinel tracks "we ran
  the command," not "a token exists." After Phase 3, key it off the token *file*
  existing so the two can't desync.
- **Token regex coupling** (`nixbox-demo`): `grep -oE '[0-9a-f]{8}-…'` couples the demo
  to zellij's token format. After Phase 3, have it read the token file via
  `nixbox-token --show` instead of scraping stdout.
- **Version single-source**: `VERSION`, the `modules/devenv.nix` header comment, and the
  git tag are hand-kept. Make the header reference `VERSION` by convention (or drop the
  version from the comment) so there's one place to bump.

---

## Suggested commit sequence

1. `refactor(zellij): extract submodule + single plugin source of truth` (Phase 1)
2. `feat(bind): warn on non-loopback bind; selfcheck honors cfg.bind` (Phase 2)
3. `security(token): write web token to a 0600 file instead of logs` (Phase 3)
4. `docs+hardening: preseed/tailscale/demo notes; sentinel + version nits` (Phase 4)

Run `devenv shell -- nixbox-selfcheck` after each; run `./scripts/ci.sh` (selfcheck +
container build) before the PR, and `./scripts/ci.sh --demos` once to confirm GIF capture
still works after the Phase 1 permissions/path moves.

## Risk notes

- **Highest-risk step is 1.3** (repointing references). The relative-path change
  (`./config/zellij` → `../config/zellij`) inside the submodule is easy to miss — it's
  the single most likely break. The container build + live selfcheck catch it.
- The internal-option indirection is lazy; if you hit an infinite-recursion eval error,
  it's almost always an option *declared* in the submodule but *read* during the
  parent's option-declaration phase — keep all `config.nixbox.zellij.*` reads inside
  `config`/`let`-used-by-config, never inside `options`.
