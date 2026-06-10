#!/usr/bin/env bash
# (Re)vendor the zellij plugin .wasm files referenced by the zellij config into
# modules/config/zellij/plugins/. Vendoring them lets the image run offline and
# inside fornix's default-deny sandbox (modules/zellij/default.nix rewrites the
# config's plugin URLs to local file: paths pointing at these files).
#
# The plugin set is the single source of truth in modules/zellij/plugins.nix — this
# script derives its download list from there (via `nix eval`), so it can't drift from
# the rewrite/permissions. Add/remove a plugin THERE, then re-run this.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DST="$REPO/modules/config/zellij/plugins"
mkdir -p "$DST"

fetch() {
  local out="$1" url="$2"
  echo "==> $out"
  curl -fsSL --retry 3 -o "$DST/$out" "$url"
}

# Emit "name<TAB>url" lines from plugins.nix (attr name = vendored basename).
mapfile -t plugins < <(
  nix eval --raw --impure --expr "
    let p = import $REPO/modules/zellij/plugins.nix; in
    builtins.concatStringsSep \"\n\"
      (builtins.map (n: n + \"\t\" + p.\${n}) (builtins.attrNames p))
  "
)

for line in "${plugins[@]}"; do
  name="${line%%$'\t'*}"
  url="${line#*$'\t'}"
  fetch "$name.wasm" "$url"
done

echo "==> done:"
du -h "$DST"/*.wasm
