#!/usr/bin/env bash
# Capture all nixbox demo GIFs. Run from inside the demos devenv:
#   cd demos && devenv shell -- ./run.sh
# Output: demos/output/*.gif
set -euo pipefail
cd "$(dirname "$0")"
export DEMO_OUTDIR="$PWD/output"
mkdir -p "$DEMO_OUTDIR"
FIX="$(cd ../tests/fixtures/hello && pwd)"

echo "== demo 1/2: edit — neovim editing a Python file (syntax, statusline) =="
DEMO_STEPS='[
  {"type":":e hello.py","wait":700},
  {"press":"Enter","wait":3000},
  {"shot":"edit-open","wait":900},
  {"type":"G","wait":1100},
  {"type":"gg","wait":1100},
  {"type":"jjjj","wait":1400},
  {"press":"Escape","wait":1500}
]' nixbox-demo edit "$FIX"

echo "== demo 2/2: readme — open and scroll a markdown file =="
DEMO_STEPS='[
  {"type":":e README.md","wait":700},
  {"press":"Enter","wait":2800},
  {"shot":"readme-open","wait":900},
  {"type":"jjjjjj","wait":1600},
  {"press":"Escape","wait":1500}
]' nixbox-demo readme "$FIX"

echo
echo "GIFs written to $DEMO_OUTDIR:"
ls -la "$DEMO_OUTDIR"/*.gif
