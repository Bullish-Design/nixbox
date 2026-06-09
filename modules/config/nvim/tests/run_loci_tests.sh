#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${NVIM_CMD:-}" ]]; then
  if command -v nv >/dev/null 2>&1; then
    NVIM_CMD="nv"
  elif command -v nvim >/dev/null 2>&1; then
    NVIM_CMD="nvim"
  else
    echo "ERROR: neither nv nor nvim found. Set NVIM_CMD=/path/to/nvim." >&2
    exit 127
  fi
fi

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$TESTS_DIR")"
export NVIM_LOG_FILE="${NVIM_LOG_FILE:-/tmp/loci-nvim.log}"
export LOCI_TEST_LOG_CASES="${LOCI_TEST_LOG_CASES:-0}"
export LOCI_TEST_RUN_INDIVIDUAL="${LOCI_TEST_RUN_INDIVIDUAL:-0}"

cd "$PLUGIN_DIR"

echo "Running loci test suite..."
echo "Plugin root: $PLUGIN_DIR"
echo "Neovim command: $NVIM_CMD"
echo "Case logging: $LOCI_TEST_LOG_CASES"
echo "Per-file rerun after full suite: $LOCI_TEST_RUN_INDIVIDUAL"
echo ""

run_nvim() {
  "$NVIM_CMD" --headless -u tests/minimal_init.lua \
    --cmd "set shadafile=NONE" \
    "$@"
}

run_one_file() {
  local test_file="$1"
  echo ""
  echo "-- $test_file --"
  run_nvim \
    -c "lua require('tests.init_tests').run_file('$test_file')" \
    -c "qa" \
    2>&1
}

if [[ "$#" -gt 0 ]]; then
  echo "== Selected files =="
  for test_file in "$@"; do
    if [[ ! -f "$test_file" ]]; then
      echo "ERROR: test file not found: $test_file" >&2
      exit 2
    fi
    run_one_file "$test_file"
  done
else
  echo "== Full suite =="
  run_nvim \
    -c "lua require('tests.init_tests').run_all()" \
    -c "qa" \
    2>&1

  if [[ "$LOCI_TEST_RUN_INDIVIDUAL" == "1" ]]; then
    echo ""
    echo "== Individual files =="
    while IFS= read -r test_file; do
      run_one_file "$test_file"
    done < <(find tests -type f -name 'test_*.lua' | sort)
  fi
fi

echo ""
echo "Done."
