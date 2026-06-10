#!/usr/bin/env bash
# Run the full CI suite locally — the same stages as .github/workflows/ci.yml,
# but devenv-native against your warm Nix cache (no Docker, no act).
#
#   ./scripts/ci.sh            # selfcheck + container build
#   ./scripts/ci.sh --demos    # + capture demo GIFs (heavy: chromium + nvim warm-up)
#   ./scripts/ci.sh --quick    # selfcheck only (fast inner loop)
#
# Each stage is a plain top-level `devenv` invocation (not nested inside a shell),
# so it's robust and mirrors exactly what CI runs.
set -euo pipefail
cd "$(dirname "$0")/.."

demos=0 quick=0
for a in "$@"; do
  case "$a" in
    --demos | --all) demos=1 ;;
    --quick) quick=1 ;;
    -h | --help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $a (try --quick | --demos)" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1;34m━━ %s ━━\033[0m\n' "$*"; }

step "selfcheck — static invariants + live web server binds/serves"
devenv shell -- nixbox-selfcheck

if [ "$quick" = 1 ]; then
  printf '\n\033[1;32m✓ quick CI passed (selfcheck only)\033[0m\n'
  exit 0
fi

step "container — devenv container build nixbox"
devenv container build nixbox

if [ "$demos" = 1 ]; then
  step "demos — capture GIFs (cd demos && ./run.sh)"
  ( cd demos && devenv shell -- ./run.sh )
fi

printf '\n\033[1;32m✓ local CI passed\033[0m\n'
