# nixbox v0.4.0 — importable devenv module.
#
# Provides a personal terminal-only interface: the vendored Neovim config
# (config/nvim) running over a Zellij web server (config/zellij). Self-contained:
# it pins its own Neovim and Zellij via fetchTarball so it works in *any* devenv
# repo without that repo declaring extra inputs.
#
# Usage in a repo's devenv.yaml:
#
#   inputs:
#     nixbox:
#       url: path:../nixbox/modules   # or github:Bullish-Design/nixbox?dir=modules
#       flake: false
#   imports:
#     - nixbox
#
# then in devenv.nix:  nixbox.enable = true;
{ pkgs, lib, config, ... }:

let
  cfg = config.nixbox;
  system = pkgs.stdenv.hostPlatform.system;

  # --- Pinned package sets (match ~/.dotfiles) -----------------------------
  # Neovim 0.12.x for vim.pack support; revs/hashes lifted from the dotfiles
  # flake.lock so behaviour matches the user's daily driver exactly.
  neovimPkgs = import (builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/d233902339c02a9c334e7e593de68855ad26c4cb.tar.gz";
    sha256 = "sha256-30sZNZoA1cqF5JNO9fVX+wgiQYjB7HJqqJ4ztCDeBZE=";
  }) { inherit system; };

  zellijPkgs = import (builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/265473c9181f3b18295d634c844bdf7761a18594.tar.gz";
    sha256 = "sha256-UEkQrTl36JeCF1VJCyq0zCiSTwWDdiLYtUiCvRju7NA=";
  }) { inherit system; };

  neovim = neovimPkgs.neovim;
  zellij = zellijPkgs.zellij;

  # --- Vendored configs (in-store, path-independent) -----------------------
  nvimConfig = ./config/nvim;
  zellijConfig = ./config/zellij;
  zellijPlugins = ./config/zellij/plugins;

  # Patched zellij config dir: the vendored config + layouts with the four
  # plugin URLs rewritten to local `file:` paths (the vendored wasm). Zellij
  # then never fetches plugins at runtime, so it works offline and inside
  # fornix's default-deny sandbox. Used by both `znv` and the web config.
  zellijConfigPatched = pkgs.runCommand "nixbox-zellij-config" { } ''
    cp -r ${zellijConfig} "$out"
    chmod -R +w "$out"
    rm -rf "$out/plugins"
    f="file:${zellijPlugins}"
    find "$out" -name '*.kdl' -print0 | xargs -0 sed -i \
      -e "s|https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm|$f/autolock.wasm|g" \
      -e "s|https://github.com/KiryuuLight/zellij-attention/releases/latest/download/zellij-attention.wasm|$f/attention.wasm|g" \
      -e "s|https://github.com/yaroslavborbat/zellij-bookmarks/releases/latest/download/zellij-bookmarks.wasm|$f/bookmarks.wasm|g" \
      -e "s|https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm|$f/zjstatus.wasm|g"
  '';

  # Treesitter grammars provided from Nix. `withAllGrammars` is ~300 MB; by
  # default we bundle a curated common set (covers the config's ftplugin
  # languages + the usual suspects) and let any other language's grammar install
  # at runtime. Set `nixbox.allTreesitterGrammars = true` for the full set.
  treesitterGrammars =
    if cfg.allTreesitterGrammars then
      pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies
    else
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (g: with g; [
        bash c comment css diff dockerfile gitcommit git_rebase gitignore
        html javascript json json5 lua luadoc markdown markdown_inline nix
        python query regex rust toml tsx typescript vim vimdoc yaml
      ])).dependencies;
  grammarPath = pkgs.symlinkJoin {
    name = "nvim-treesitter-grammars";
    paths = treesitterGrammars;
  };

  # Neovim wrapper: same shape as the dotfiles' writeShellScriptBin "nvim".
  nvimWrapper = pkgs.writeShellScriptBin "nvim" ''
    export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # Clean-env fallback: the config configures obsidian.nvim with a vault at
    # ~/Documents/Notes and aborts init if it's missing. In a container/demo
    # that path doesn't exist, so point the config's own LOCI_OBSIDIAN_VAULT hook
    # at a writable dir. No-op on a real machine that has the vault (or sets the
    # var), so the user's config is respected. (Lives here, not in the vendored
    # config, so it survives `scripts/sync-config.sh`.)
    if [ -z "''${LOCI_OBSIDIAN_VAULT:-}" ] && [ ! -d "$HOME/Documents/Notes" ]; then
      export LOCI_OBSIDIAN_VAULT="''${XDG_DATA_HOME:-$HOME/.local/share}/nixbox/notes"
      mkdir -p "$LOCI_OBSIDIAN_VAULT"
    fi
    exec ${neovim}/bin/nvim -u "${nvimConfig}/init.lua" \
      --cmd "set rtp^=${nvimConfig}" \
      --cmd "set rtp+=${nvimConfig}/after" \
      --cmd "set rtp^=${grammarPath}" \
      "$@"
  '';

  # `nv` is an alias for nvim on the host; the zellij nvim layout execs `nv`
  # directly (not via a shell), so ship it as a real binary.
  nvAlias = pkgs.writeShellScriptBin "nv" ''
    exec ${nvimWrapper}/bin/nvim "$@"
  '';

  # `znv` = zellij with the nvim layout (mirrors the dotfiles wrapper).
  znv = pkgs.writeShellScriptBin "znv" ''
    exec ${zellij}/bin/zellij --config-dir "${zellijConfigPatched}" --layout nvim "$@"
  '';

  # Web-enabled zellij config *file*. Two things matter (learned from
  # zelligate's src/zelligate/zellij.py and direct testing):
  #   * the web server is enabled by config directives, not CLI flags; and
  #   * it must be passed via `--config <FILE>`, not `--config-dir <DIR>` —
  #     zellij writes state into a config-dir, which fails on a read-only store
  #     path and leaves the server printing "started" without ever binding.
  # `layout_dir` points back at the vendored layouts so `default_layout "nvim"`
  # still resolves.
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

  # Pre-granted zellij plugin permissions, keyed by the (stable) vendored plugin
  # store paths. Dropped into a demo's XDG_CACHE so the web session manager and
  # nvim layout load without "Allow? (y/n)" prompts — needed for deterministic
  # headless Playwright capture.
  zellijPermissions = pkgs.writeText "nixbox-zellij-permissions.kdl" (
    lib.concatMapStrings
      (w: ''
        "${zellijPlugins}/${w}" {
            ReadApplicationState
            ChangeApplicationState
            ReadCliPipes
            MessageAndLaunchOtherPlugins
        }
      '')
      [ "attention.wasm" "autolock.wasm" "zjstatus.wasm" "bookmarks.wasm" ]
  );

  # Optional zelligate manifest interop (same JSON shape as
  # zelligate/modules/devenv.nix) — only emitted when `name` is set.
  manifestJson = builtins.toJSON {
    enable = true;
    name = cfg.name;
    port = cfg.webPort;
  };
in
{
  options.nixbox = {
    enable = lib.mkEnableOption "the nixbox terminal interface (neovim over a zellij web server)";

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 8920;
      description = "Port the zellij web server listens on.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the zellij web server binds to. Non-loopback binds require SSL
        (`--cert`/`--key`); keep this on loopback and let an external forwarder
        (e.g. zelligate's socat / Tailscale) handle public exposure.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Optional zelligate repo name. When set, a zelligate-manifest script is exposed for auto-discovery.";
    };

    lspServers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        basedpyright ty ruff vtsls vscode-langservers-extracted
        lua-language-server nil rust-analyzer yaml-language-server markdown-oxide
      ];
      defaultText = lib.literalExpression "the full set from ~/.dotfiles/nvim/default.nix";
      description = ''
        LSP servers bundled in the environment. These dominate image size — the
        node-based ones especially (basedpyright ~880MB, vtsls ~450MB,
        vscode-langservers-extracted ~310MB, yaml-language-server ~260MB). Trim
        this list (or set it to `[]`) for a much smaller image; e.g. keep just
        `[ pkgs.ty pkgs.ruff pkgs.nil pkgs.lua-language-server ]`.
      '';
    };

    allTreesitterGrammars = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bundle ALL treesitter grammars (~300MB) instead of the curated common
        set. With the curated set, grammars for other languages install at
        runtime (needs network once, like vim.pack plugins).
      '';
    };

    nvimBuildTools.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Provide a reproducible build toolchain (rust + a C compiler + make +
        pkg-config) so neovim plugins with native components can compile their
        binaries during `nixbox-preseed` (e.g. fff's Rust backend). Without this
        the env silently relies on a host-leaked toolchain that is absent in the
        container, so those plugins error at startup. Disabling it shrinks the
        image (~the rust toolchain) but breaks plugins that need to self-build.
      '';
    };

    tailscale = {
      enable = lib.mkEnableOption "joining a tailnet and serving the web port over Tailscale (userspace networking)";

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "nixbox";
        description = "Tailscale device hostname for this container.";
      };

      funnel = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use `tailscale funnel` (public internet) instead of `tailscale serve` (tailnet-only).";
      };

      extraUpArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = lib.literalExpression ''[ "--ssh" "--accept-routes" ]'';
        description = "Extra arguments passed to `tailscale up`.";
      };
    };

    playwright.enable = lib.mkEnableOption ''
      the Playwright demo/CI addon: headless-browser capture of the web terminal
      into GIFs (`nixbox-demo`). Pulls in nodejs + playwright + chromium + ffmpeg
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
    packages = [
      nvimWrapper
      nvAlias
      znv
      zellij
      pkgs.git
    ] ++ cfg.lspServers
    # Reproducible toolchain for plugins that build native binaries on first run
    # (declared explicitly so it exists in the container, not just via host PATH).
    ++ lib.optionals cfg.nvimBuildTools.enable [
      pkgs.rustc
      pkgs.cargo
      pkgs.gcc
      pkgs.gnumake
      pkgs.pkg-config
    ];

    env.EDITOR = "nvim";

    # Launch the terminal interface: a zellij web server bound to `bind:webPort`,
    # using the patched zellij config (default_layout "nvim" -> opens neovim).
    # Bootstraps a web login token on first run (sentinel on the data dir, so a
    # persisted volume gets exactly one token), then starts the server.
    scripts.nixbox-web.exec = ''
      set -uo pipefail
      tokmark="''${XDG_DATA_HOME:-$HOME/.local/share}/nixbox/web-token-created"
      if [ ! -f "$tokmark" ]; then
        echo "nixbox: no login token yet — creating one (shown once):"
        if ${zellij}/bin/zellij --config "${zellijWebConfig}" web --create-token; then
          mkdir -p "$(dirname "$tokmark")" && touch "$tokmark"
        else
          echo "nixbox: token creation failed; create one later with 'nixbox-token'"
        fi
      fi
      echo "nixbox: starting zellij web on ${cfg.bind}:${toString cfg.webPort}"
      exec ${zellij}/bin/zellij --config "${zellijWebConfig}" web
    '';

    # Create a web login token (zellij requires one to attach over the web).
    scripts.nixbox-token.exec = ''
      exec ${zellij}/bin/zellij --config "${zellijWebConfig}" web --create-token "$@"
    '';

    # Pre-seed vim.pack plugins + treesitter so the first interactive launch is
    # instant. Runtime fetch needs network; run this once (also wired into the
    # container build). Guarded by a sentinel so it is cheap to re-run.
    scripts.nixbox-preseed.exec = ''
      set -euo pipefail
      seeded="''${XDG_DATA_HOME:-$HOME/.local/share}/nixbox-preseeded"
      if [ -f "$seeded" ]; then
        echo "nixbox: plugins already seeded ($seeded)"; exit 0
      fi
      echo "nixbox: seeding neovim plugins (vim.pack) — needs network, one-off..."
      # init.lua calls vim.pack.add at startup, which clones missing plugins;
      # a headless launch triggers that, then update pins them to locked versions.
      ${nvimWrapper}/bin/nvim --headless "+qa!" || true
      ${nvimWrapper}/bin/nvim --headless "+lua pcall(vim.pack.update)" "+qa!" || true
      ${lib.optionalString cfg.nvimBuildTools.enable ''
      # Build native plugin binaries that don't ship/download a prebuilt (fff's
      # Rust backend). Needs the toolchain (nvimBuildTools); best-effort.
      echo "nixbox: building native plugin binaries (fff)…"
      ${nvimWrapper}/bin/nvim --headless \
        "+lua pcall(function() require('fff.download').download_or_build_binary() end)" \
        "+qa!" || true
      ''}
      mkdir -p "$(dirname "$seeded")" && touch "$seeded"
      echo "nixbox: preseed complete"
    '';

    # Container/process entrypoint: warm plugins once (best-effort — needs
    # network the first time; harmless if already seeded or offline), then start
    # the web server. With the data dir on a persisted volume the seed/token
    # work happens exactly once across container restarts.
    scripts.nixbox-start.exec = ''
      set -uo pipefail
      nixbox-preseed || echo "nixbox: preseed skipped (continuing — run 'nixbox-preseed' with network to warm plugins)"
      ${lib.optionalString cfg.tailscale.enable ''
      nixbox-tailscale || echo "nixbox: tailscale bring-up failed (continuing — web still on localhost)"
      ''}
      exec nixbox-web
    '';

    # Run the full entrypoint as a managed process (used by `devenv up` and the
    # container image). Omitted under `devenv test` so it doesn't race the
    # self-contained web server that nixbox-selfcheck starts.
    processes = lib.optionalAttrs (!config.devenv.isTesting) {
      nixbox.exec = "nixbox-start";
    };

    # Self-contained verification used by CI (`devenv shell nixbox-selfcheck`) and
    # by `devenv test` (via enterTest). Static invariants + a LIVE check that the
    # zellij web server actually binds and speaks HTTP — the regression that the
    # "started but never bound" bug would have slipped past. No network needed:
    # plugins are vendored as file: paths and nvim is only version-checked here.
    scripts.nixbox-selfcheck.exec = ''
      set -uo pipefail
      fails=0
      pass(){ echo "  PASS $*"; }
      fail(){ echo "  FAIL $*"; fails=$((fails + 1)); }
      port=${toString cfg.webPort}

      echo "== nixbox selfcheck =="
      echo "[1] commands resolve"
      for c in nvim nv znv zellij nixbox-web nixbox-token nixbox-preseed nixbox-start; do
        command -v "$c" >/dev/null 2>&1 && pass "$c" || fail "$c missing"
      done

      echo "[2] neovim >= 0.12 (vim.pack)"
      v=$(${nvimWrapper}/bin/nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
      if [ "$(printf '0.12\n%s\n' "$v" | sort -V | head -1)" = "0.12" ]; then pass "nvim $v"; else fail "nvim $v < 0.12"; fi

      echo "[3] zellij web config is offline (file: plugins, no https)"
      if grep -q 'file:' "${zellijWebConfig}" && ! grep -q 'https://' "${zellijWebConfig}"; then
        pass "plugin URLs rewritten to file:"
      else
        fail "plugin URLs not rewritten"
      fi
      n=$(ls "${zellijPlugins}"/*.wasm 2>/dev/null | wc -l)
      if [ "''${n:-0}" -ge 4 ]; then pass "$n vendored wasm present"; else fail "only ''${n:-0} wasm vendored"; fi

      echo "[4] live: zellij web binds and serves on :$port"
      home=$(mktemp -d)
      export HOME="$home" XDG_DATA_HOME="$home/data" XDG_CACHE_HOME="$home/cache"
      mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
      # setsid -> own process group, so cleanup can reap the whole tree (the
      # nixbox-web wrapper exec's zellij as a child, so killing $! alone orphans
      # the server).
      setsid nixbox-web >"$home/web.log" 2>&1 &
      wpid=$!
      cleanup_web() {
        ${zellij}/bin/zellij --config "${zellijWebConfig}" web --stop >/dev/null 2>&1 || true
        kill -TERM -"$wpid" 2>/dev/null || kill "$wpid" 2>/dev/null || true
        wait "$wpid" 2>/dev/null || true
      }
      trap cleanup_web EXIT
      bound=""
      for _ in $(seq 1 30); do
        if (exec 3<>/dev/tcp/127.0.0.1/$port) 2>/dev/null; then bound=1; break; fi
        sleep 1
      done
      if [ -n "$bound" ]; then
        pass "port $port bound (server is listening)"
        resp=$( { exec 3<>/dev/tcp/127.0.0.1/$port; printf 'GET / HTTP/1.0\r\nHost: localhost\r\n\r\n' >&3; head -1 <&3; exec 3>&- 3<&-; } 2>/dev/null || true)
        case "$resp" in
          HTTP/*\ [23]*) pass "web responds: $(echo "$resp" | tr -d '\r')" ;;
          *) fail "unexpected web response: '$(echo "$resp" | tr -d '\r')'" ;;
        esac
        if [ -f "$XDG_DATA_HOME/nixbox/web-token-created" ]; then pass "login token bootstrapped"; else fail "no token sentinel"; fi
      else
        fail "web server never bound on :$port"; tail -5 "$home/web.log" 2>/dev/null || true
      fi
      cleanup_web; trap - EXIT

      echo
      if [ "$fails" -eq 0 ]; then echo "nixbox selfcheck: ALL PASS"; else echo "nixbox selfcheck: $fails FAILURE(S)"; exit 1; fi
    '';

    enterShell = ''
      echo "nixbox ready — 'nixbox-start' (preseed + web) is the entrypoint; 'nixbox-web' / 'nixbox-preseed' / 'nixbox-token' available individually."
    '';
    })

    # Optional zelligate auto-discovery manifest (only when a name is set).
    (lib.mkIf (cfg.enable && cfg.name != "") {
      scripts.zelligate-manifest.exec = ''
        cat <<'JSON'
${manifestJson}
JSON
      '';
    })

    # Optional Tailscale: join the tailnet and serve the web port directly, so
    # the container is reachable over Tailscale without host networking or a
    # separate forwarder. Uses userspace networking (no /dev/net/tun needed).
    # Auth via the TS_AUTHKEY env var; state persists under XDG_DATA.
    (lib.mkIf (cfg.enable && cfg.tailscale.enable) {
      packages = [ pkgs.tailscale ];

      scripts.nixbox-tailscale.exec = ''
        set -uo pipefail
        ts=${pkgs.tailscale}/bin/tailscale
        tsd=${pkgs.tailscale}/bin/tailscaled
        sock="''${XDG_RUNTIME_DIR:-/tmp}/nixbox-tailscaled.sock"
        statedir="''${XDG_DATA_HOME:-$HOME/.local/share}/nixbox/tailscale"
        mkdir -p "$statedir"

        if ! "$ts" --socket="$sock" status >/dev/null 2>&1; then
          echo "nixbox: starting tailscaled (userspace networking)"
          "$tsd" --tun=userspace-networking --socket="$sock" \
            --statedir="$statedir" >"$statedir/tailscaled.log" 2>&1 &
          for i in $(seq 1 30); do
            "$ts" --socket="$sock" status >/dev/null 2>&1 && break
            # 'status' exits non-zero when logged out but daemon is up; treat
            # "NeedsLogin" as ready.
            "$ts" --socket="$sock" status 2>&1 | grep -q "Logged out\|NeedsLogin\|Stopped" && break
            sleep 0.5
          done
        fi

        echo "nixbox: tailscale up (hostname=${cfg.tailscale.hostname})"
        "$ts" --socket="$sock" up \
          --hostname="${cfg.tailscale.hostname}" \
          ''${TS_AUTHKEY:+--authkey="$TS_AUTHKEY"} \
          ${lib.escapeShellArgs cfg.tailscale.extraUpArgs}

        echo "nixbox: ${if cfg.tailscale.funnel then "funnel" else "serve"} -> http://127.0.0.1:${toString cfg.webPort}"
        "$ts" --socket="$sock" ${if cfg.tailscale.funnel then "funnel" else "serve"} --bg ${toString cfg.webPort}
      '';
    })

    # Optional Playwright addon: capture the live web terminal into GIFs.
    # `nixbox-demo <name> [fixtureDir]` boots the web server (plugin permissions
    # pre-granted), drives a headless chromium through the session wizard into
    # nvim, records video, and renders a GIF. DEMO_STEPS (JSON) customises the
    # in-nvim scenario; see modules/playwright/demo.cjs.
    (lib.mkIf (cfg.enable && cfg.playwright.enable) {
      packages = [ pkgs.nodejs pkgs.playwright-test pkgs.ffmpeg ];

      # Playwright env (only present when the addon is enabled), in the devenv
      # `env` block for discoverability — same idiom as the browsee project. The
      # nix-provided browsers are used as-is; host-requirement validation is
      # skipped because the browsers are already the patched Nix builds.
      env = {
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };

      scripts.nixbox-demo.exec = ''
        set -uo pipefail
        # NODE_PATH lets the vendored CommonJS driver `require('@playwright/test')`
        # from the Nix package (scoped to this script so the dev shell's node
        # resolution is untouched).
        export NODE_PATH="${pkgs.playwright-test}/lib/node_modules"
        node=${pkgs.nodejs}/bin/node
        ffmpeg=${pkgs.ffmpeg}/bin/ffmpeg
        port=${toString cfg.webPort}

        name="''${1:-demo}"
        fixture="''${2:-$PWD}"
        outdir="''${DEMO_OUTDIR:-''${DEVENV_ROOT:-$PWD}/demos}"
        state="''${DEMO_STATE:-''${DEVENV_ROOT:-$PWD}/.nixbox/demo-home}"
        mkdir -p "$outdir" "$state/data" "$state/cache/zellij"

        export HOME="$state" XDG_DATA_HOME="$state/data" XDG_CACHE_HOME="$state/cache"
        # Pre-grant plugin permissions so the headless session loads prompt-free.
        cp -f "${zellijPermissions}" "$XDG_CACHE_HOME/zellij/permissions.kdl"

        echo "nixbox-demo: warming neovim plugins (first run only)…"
        nixbox-preseed || echo "nixbox-demo: preseed failed — nvim may show the install screen"

        tok=$(nixbox-token 2>&1 | grep -oE '[0-9a-f]{8}-[0-9a-f-]+' | head -1)
        [ -n "$tok" ] || { echo "nixbox-demo: could not create a web token"; exit 1; }

        work=$(mktemp -d)
        setsid bash -c "cd \"$fixture\" && exec nixbox-web" >"$work/web.log" 2>&1 &
        webpid=$!
        cleanup(){
          ${zellij}/bin/zellij --config "${zellijWebConfig}" web --stop >/dev/null 2>&1 || true
          kill -TERM -"$webpid" 2>/dev/null || kill "$webpid" 2>/dev/null || true
        }
        trap cleanup EXIT
        for _ in $(seq 1 30); do (exec 3<>/dev/tcp/127.0.0.1/$port) 2>/dev/null && break; sleep 1; done

        echo "nixbox-demo: capturing '$name' (fixture: $fixture)…"
        NIXBOX_TOKEN="$tok" NIXBOX_WEB_PORT="$port" DEMO_OUT="$work" DEMO_SESSION="$name" \
          "$node" "${./playwright/demo.cjs}" || { echo "nixbox-demo: capture failed"; tail -5 "$work/web.log"; exit 1; }

        webm=$(ls "$work"/*.webm 2>/dev/null | head -1)
        [ -n "$webm" ] || { echo "nixbox-demo: no video recorded"; exit 1; }
        "$ffmpeg" -y -i "$webm" -vf "fps=12,scale=820:-1:flags=lanczos,palettegen=stats_mode=diff" "$work/pal.png" >/dev/null 2>&1
        "$ffmpeg" -y -i "$webm" -i "$work/pal.png" -lavfi "fps=12,scale=820:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer" "$outdir/$name.gif" >/dev/null 2>&1
        echo "nixbox-demo: wrote $outdir/$name.gif ($(du -h "$outdir/$name.gif" 2>/dev/null | cut -f1))"
      '';
    })
  ];
}
