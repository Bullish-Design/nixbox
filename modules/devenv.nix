# nixbox v0.1.0 — importable devenv module.
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

  # Treesitter grammars provided from Nix (mirrors ~/.dotfiles/nvim/default.nix).
  treesitterGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
  grammarPath = pkgs.symlinkJoin {
    name = "nvim-treesitter-grammars";
    paths = treesitterGrammars;
  };

  # Neovim wrapper: same shape as the dotfiles' writeShellScriptBin "nvim".
  nvimWrapper = pkgs.writeShellScriptBin "nvim" ''
    export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
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
    exec ${zellij}/bin/zellij --config-dir "${zellijConfig}" --layout nvim "$@"
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
    cp ${zellijConfig}/config.kdl "$out"
    chmod +w "$out"
    cat >> "$out" <<KDL

// nixbox: web server (generated)
layout_dir "${zellijConfig}/layouts"
web_server true
web_server_ip "${cfg.bind}"
web_server_port ${toString cfg.webPort}
KDL
  '';

  # LSP servers from ~/.dotfiles/nvim/default.nix.
  lspServers = with pkgs; [
    basedpyright
    ty
    ruff
    vtsls
    vscode-langservers-extracted
    lua-language-server
    nil
    rust-analyzer
    yaml-language-server
    markdown-oxide
  ];

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
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
    packages = [
      nvimWrapper
      nvAlias
      znv
      zellij
      pkgs.git
    ] ++ lspServers;

    env.EDITOR = "nvim";

    # Launch the terminal interface: a zellij web server bound to `bind:webPort`,
    # using the vendored zellij config (default_layout "nvim" -> opens neovim).
    scripts.nixbox-web.exec = ''
      set -euo pipefail
      echo "nixbox: starting zellij web on ${cfg.bind}:${toString cfg.webPort}"
      echo "nixbox: create a login token with 'nixbox-token' if you have not yet"
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
      mkdir -p "$(dirname "$seeded")" && touch "$seeded"
      echo "nixbox: preseed complete"
    '';

    # Run the zellij web server as a managed process (used by `devenv up` and the
    # container image).
    processes.nixbox.exec = "nixbox-web";

    enterShell = ''
      echo "nixbox ready — 'nixbox-web' starts the terminal interface; 'nixbox-preseed' warms neovim plugins."
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
  ];
}
