#!/usr/bin/env bash
# Re-vendor the neovim + zellij configs from ~/.dotfiles into modules/config,
# applying the same prune rules used for the initial import. Run this whenever
# your daily-driver dotfiles change so the nixbox image doesn't drift.
#
#   scripts/sync-config.sh [DOTFILES_DIR]   (default: ~/.dotfiles)
#
# It does NOT touch modules/config/zellij/plugins/ — those vendored .wasm files
# are nixbox's own (see scripts/fetch-zellij-plugins.sh to refresh them).
set -euo pipefail

DOTFILES="${1:-$HOME/.dotfiles}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DST="$REPO/modules/config"

[ -d "$DOTFILES/nvim" ] || { echo "error: $DOTFILES/nvim not found" >&2; exit 1; }
[ -d "$DOTFILES/zellij" ] || { echo "error: $DOTFILES/zellij not found" >&2; exit 1; }

echo "==> syncing neovim config"
rsync -a --delete \
  --exclude='.git' --exclude='nvim.log' --exclude='.luarc.json' \
  "$DOTFILES/nvim/" "$DST/nvim/"
# Drop the home-manager wrapper (re-homed in modules/devenv.nix) and the heavy
# upstream doc dumps (not referenced by the config; docs/loci IS kept).
rm -f  "$DST/nvim/default.nix"
rm -rf "$DST/nvim/docs/wayfinder" "$DST/nvim/docs/markdown-oxide"

echo "==> syncing zellij config (preserving vendored plugins/)"
cp -f "$DOTFILES/zellij/config.kdl"          "$DST/zellij/config.kdl"
cp -f "$DOTFILES/zellij/terminal-config.kdl" "$DST/zellij/terminal-config.kdl"
rsync -a --delete "$DOTFILES/zellij/layouts/" "$DST/zellij/layouts/"

echo "==> done. Review with: git -C \"$REPO\" status --short modules/config"
echo "    If config.kdl/layouts gained new plugin URLs, vendor them with"
echo "    scripts/fetch-zellij-plugins.sh and add the rewrite in modules/devenv.nix."
