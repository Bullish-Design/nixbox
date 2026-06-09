#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$TESTS_DIR")"
cd "$PLUGIN_DIR"

if [[ -n "${NVIM_CMD:-}" ]]; then
  if [[ "${LOCI_RELEASE_ALLOW_NON_NV:-0}" != "1" && "$(basename "$NVIM_CMD")" != "nv" ]]; then
    echo "ERROR: release validation must use nv. Set LOCI_RELEASE_ALLOW_NON_NV=1 only for emergency debugging." >&2
    echo "Current NVIM_CMD: $NVIM_CMD" >&2
    exit 2
  fi
else
  if ! command -v nv >/dev/null 2>&1; then
    echo "ERROR: nv wrapper not found. Release validation must run under the project wrapper." >&2
    exit 127
  fi
  export NVIM_CMD="nv"
fi

if ! command -v "$NVIM_CMD" >/dev/null 2>&1; then
  echo "ERROR: Neovim command not found: $NVIM_CMD" >&2
  echo "Release validation requires the project nv wrapper." >&2
  exit 127
fi

export LOCI_TEST_TIMEOUT_MS="${LOCI_TEST_TIMEOUT_MS:-30000}"
export LOCI_TEST_LOG_CASES="${LOCI_TEST_LOG_CASES:-0}"
export NVIM_LOG_FILE="${NVIM_LOG_FILE:-/tmp/loci-release-nvim.log}"

STATE_DIR="${LOCI_RELEASE_STATE_DIR:-$(mktemp -d -t loci-release-state.XXXXXX)}"
CACHE_DIR="${LOCI_RELEASE_CACHE_DIR:-$(mktemp -d -t loci-release-cache.XXXXXX)}"
export XDG_STATE_HOME="$STATE_DIR"
export XDG_CACHE_HOME="$CACHE_DIR"

cleanup() {
  if [[ -z "${LOCI_RELEASE_KEEP_STATE:-}" ]]; then
    rm -rf "$STATE_DIR" "$CACHE_DIR"
  else
    echo "Preserved release state: $STATE_DIR"
    echo "Preserved release cache: $CACHE_DIR"
  fi
}
trap cleanup EXIT

echo "LOCI release test run"
echo "Plugin root: $PLUGIN_DIR"
echo "Neovim command: $NVIM_CMD"
echo "Timeout: $LOCI_TEST_TIMEOUT_MS ms"
echo "State: $XDG_STATE_HOME"
echo "Cache: $XDG_CACHE_HOME"
echo ""

# Run selected files when supplied; otherwise run the complete runner.
"$TESTS_DIR/run_loci_tests.sh" "$@"
