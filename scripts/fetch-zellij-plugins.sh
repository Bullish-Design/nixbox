#!/usr/bin/env bash
# (Re)vendor the zellij plugin .wasm files referenced by the zellij config into
# modules/config/zellij/plugins/. Vendoring them lets the image run offline and
# inside fornix's default-deny sandbox (modules/devenv.nix rewrites the config's
# plugin URLs to local file: paths pointing at these files).
#
# If you change which plugins the zellij config uses, update this list AND the
# URL-rewrite block in modules/devenv.nix (zellijConfigPatched).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DST="$REPO/modules/config/zellij/plugins"
mkdir -p "$DST"

# name<TAB>url  (latest release assets)
fetch() {
  local out="$1" url="$2"
  echo "==> $out"
  curl -fsSL --retry 3 -o "$DST/$out" "$url"
}

fetch autolock.wasm  https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm
fetch attention.wasm https://github.com/KiryuuLight/zellij-attention/releases/latest/download/zellij-attention.wasm
fetch bookmarks.wasm https://github.com/yaroslavborbat/zellij-bookmarks/releases/latest/download/zellij-bookmarks.wasm
fetch zjstatus.wasm  https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm

echo "==> done:"
du -h "$DST"/*.wasm
