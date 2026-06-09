#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$(dirname "$TESTS_DIR")"
cd "$PLUGIN_DIR"

if [[ -n "${NVIM_CMD:-}" ]]; then
  if [[ "${LOCI_MANUAL_ALLOW_NON_NV:-0}" != "1" && "$(basename "$NVIM_CMD")" != "nv" ]]; then
    echo "ERROR: manual integration validation should use nv." >&2
    echo "Set LOCI_MANUAL_ALLOW_NON_NV=1 only for local debugging." >&2
    exit 2
  fi
else
  if ! command -v nv >/dev/null 2>&1; then
    echo "ERROR: nv wrapper not found." >&2
    exit 127
  fi
  export NVIM_CMD="nv"
fi

REPO_DIR="${LOCI_MANUAL_REPO:-$(mktemp -d -t loci-manual-repo.XXXXXX)}"
STATE_DIR="${LOCI_MANUAL_STATE:-$(mktemp -d -t loci-manual-state.XXXXXX)}"
CACHE_DIR="${LOCI_MANUAL_CACHE:-$(mktemp -d -t loci-manual-cache.XXXXXX)}"
LOG_FILE="${LOCI_MANUAL_LOG:-/tmp/loci-manual-validation.log}"

export LOCI_PROJECT_ROOT="$REPO_DIR"
export XDG_STATE_HOME="$STATE_DIR"
export XDG_CACHE_HOME="$CACHE_DIR"
export NVIM_LOG_FILE="$LOG_FILE"
export LOCI_MANUAL_REQUIRED="${LOCI_MANUAL_REQUIRED:-haunt,wayfinder,resession,tabby}"

cleanup() {
  if [[ -z "${LOCI_MANUAL_KEEP:-}" ]]; then
    rm -rf "$REPO_DIR" "$STATE_DIR" "$CACHE_DIR"
  else
    echo "Preserved manual repo: $REPO_DIR"
    echo "Preserved manual state: $STATE_DIR"
    echo "Preserved manual cache: $CACHE_DIR"
  fi
}
trap cleanup EXIT

echo "LOCI manual integration validation"
echo "Plugin root: $PLUGIN_DIR"
echo "Neovim command: $NVIM_CMD"
echo "Repository: $LOCI_PROJECT_ROOT"
echo "State: $XDG_STATE_HOME"
echo "Cache: $XDG_CACHE_HOME"
echo "Required integrations: $LOCI_MANUAL_REQUIRED"
echo "Log: $NVIM_LOG_FILE"
echo ""

"$NVIM_CMD" --headless \
  --cmd "set shadafile=NONE" \
  -c "lua require('tests.manual.loci_manual_validation').run()" \
  -c "qa" \
  2>&1 | tee "$LOG_FILE"
