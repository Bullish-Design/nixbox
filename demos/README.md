# nixbox demos (Playwright addon)

Generates animated GIFs of the live nixbox web terminal by driving it in a
headless browser — proof that the whole stack works, end to end, in a real
browser: token auth → zellij web session → neovim.

This environment is **separate from the repo root on purpose**: it enables the
heavy, opt-in `nixbox.playwright.enable` addon (node + chromium + ffmpeg), which
the lean runtime / container image must not pull in.

## Run

```bash
cd demos
devenv shell -- ./run.sh        # writes demos/output/*.gif
```

First run is slow: it builds the Playwright closure and warms neovim's vim.pack
plugins (cached afterwards under `demos/.nixbox/`).

## How it works

`nixbox-demo <name> [fixtureDir]` (from the addon):

1. pre-grants the zellij plugin permissions (so the headless session loads
   prompt-free), warms neovim plugins, and starts the zellij web server in the
   fixture directory;
2. drives headless chromium through token auth and the session wizard into the
   `nvim` layout (`modules/playwright/demo.cjs`);
3. records video and renders it to `output/<name>.gif` with ffmpeg.

Customise the in-nvim scenario with `DEMO_STEPS` (a JSON array of
`{type|press|shot, value, wait}` steps) — see `run.sh` and the driver.

## Fixtures

Small repos under [`../tests/fixtures`](../tests/fixtures) that the demo opens,
so the GIFs show the terminal editing a real project.
