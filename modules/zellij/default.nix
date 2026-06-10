# Zellij packaging for nixbox — the offline web terminal layer.
#
# Owns everything Zellij: the pinned package, the vendored config patched for offline
# use (plugin URLs rewritten to local file: paths), the web-server config file, and the
# pre-granted plugin permissions. The plugin set is defined once in ./plugins.nix and
# every artifact below is derived from it.
#
# Imported by ../devenv.nix via `imports = [ ./zellij ]` (relative path, so it resolves
# under both the `path:` and `github:...?dir=modules` consumption forms). Computed
# derivations are handed to the parent through internal read-only options
# (config.nixbox.zellij._*); the shared nixbox.bind / nixbox.webPort options are declared
# in the parent and merged in here.
{ pkgs, lib, config, ... }:
let
  cfg = config.nixbox;
  system = pkgs.stdenv.hostPlatform.system;

  # Zellij pinned to match ~/.dotfiles (rev/hash from its flake.lock) so behaviour
  # matches the user's daily driver. Self-contained: an importing repo needn't declare it.
  zellijPkgs = import (builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/265473c9181f3b18295d634c844bdf7761a18594.tar.gz";
    sha256 = "sha256-UEkQrTl36JeCF1VJCyq0zCiSTwWDdiLYtUiCvRju7NA=";
  }) { inherit system; };
  zellij = zellijPkgs.zellij;

  # Vendored configs (in-store, path-independent). NOTE the `../` — this file lives one
  # directory deeper than the old in-line implementation in ../devenv.nix.
  zellijConfig = ../config/zellij;
  zellijPlugins = ../config/zellij/plugins;

  plugins = import ./plugins.nix;
  pluginNames = lib.attrNames plugins;

  # zellij web refuses to bind a non-loopback address without --cert/--key, so an
  # off-loopback `bind` silently yields a server that never comes up. Warn at eval
  # time rather than letting it fail live. (A hard assertion would block the legit
  # cert/key path, and devenv doesn't reliably evaluate the NixOS `assertions` option.)
  isLoopback = b: b == "127.0.0.1" || b == "localhost" || b == "::1";

  # URL -> local file: rewrite, derived from plugins.nix. The attr name is the vendored
  # basename, so each plugin's upstream URL maps to `$f/<name>.wasm`.
  rewriteArgs = lib.concatMapStringsSep " \\\n      "
    (n: ''-e "s|${plugins.${n}}|$f/${n}.wasm|g"'')
    pluginNames;

  # Patched zellij config dir: the vendored config with every plugin URL rewritten to the
  # vendored wasm. Zellij then never fetches plugins at runtime, so it works offline and
  # inside fornix's default-deny sandbox. Used by both `znv` and the web config.
  zellijConfigPatched = pkgs.runCommand "nixbox-zellij-config" { } ''
    cp -r ${zellijConfig} "$out"
    chmod -R +w "$out"
    rm -rf "$out/plugins"
    f="file:${zellijPlugins}"
    find "$out" -name '*.kdl' -print0 | xargs -0 sed -i \
      ${rewriteArgs}
  '';

  # Web-enabled zellij config *file*. Two things matter (learned from zelligate's
  # src/zelligate/zellij.py and direct testing):
  #   * the web server is enabled by config directives, not CLI flags; and
  #   * it must be passed via `--config <FILE>`, not `--config-dir <DIR>` — zellij writes
  #     state into a config-dir, which fails on a read-only store path and leaves the
  #     server printing "started" without ever binding.
  # `layout_dir` points back at the vendored layouts so `default_layout "nvim"` resolves.
  zellijWebConfig = lib.warnIf (!isLoopback cfg.bind)
    "nixbox: bind='${cfg.bind}' is non-loopback; zellij web requires --cert/--key off loopback and will not bind otherwise. Keep bind on loopback and front it with `tailscale serve` / a reverse proxy."
    (pkgs.runCommand "nixbox-zellij-web.kdl" { } ''
      cp ${zellijConfigPatched}/config.kdl "$out"
      chmod +w "$out"
      cat >> "$out" <<KDL

// nixbox: web server (generated)
layout_dir "${zellijConfigPatched}/layouts"
web_server true
web_server_ip "${cfg.bind}"
web_server_port ${toString cfg.webPort}
KDL
    '');

  # Pre-granted zellij plugin permissions, keyed by the (stable) vendored plugin store
  # paths. Dropped into a demo's XDG_CACHE so the web session manager and nvim layout load
  # without "Allow? (y/n)" prompts — needed for deterministic headless Playwright capture.
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
  # Computed outputs consumed by ../devenv.nix. internal+readOnly so they aren't
  # user-settable and don't surface as configuration options.
  options.nixbox.zellij = {
    package = lib.mkOption {
      type = lib.types.package; internal = true; readOnly = true;
      description = "The pinned zellij package.";
    };
    patchedConfig = lib.mkOption {
      type = lib.types.package; internal = true; readOnly = true;
      description = "Vendored zellij config dir with plugin URLs rewritten to file: paths.";
    };
    webConfig = lib.mkOption {
      type = lib.types.package; internal = true; readOnly = true;
      description = "Web-server-enabled zellij config file (pass via --config FILE).";
    };
    permissions = lib.mkOption {
      type = lib.types.package; internal = true; readOnly = true;
      description = "Pre-granted plugin permissions KDL for headless/demo capture.";
    };
    pluginDir = lib.mkOption {
      type = lib.types.path; internal = true; readOnly = true;
      description = "Directory of vendored plugin .wasm files.";
    };
    pluginCount = lib.mkOption {
      type = lib.types.int; internal = true; readOnly = true;
      description = "Number of vendored plugins (for selfcheck assertions).";
    };
  };

  config = lib.mkIf cfg.enable {
    nixbox.zellij = {
      package = zellij;
      patchedConfig = zellijConfigPatched;
      webConfig = zellijWebConfig;
      permissions = zellijPermissions;
      pluginDir = zellijPlugins;
      pluginCount = lib.length pluginNames;
    };
  };
}
