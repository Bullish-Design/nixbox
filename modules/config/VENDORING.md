# Vendored configs

`nvim/` and `zellij/` are copied from `~/.dotfiles` (re-sync with
`scripts/sync-config.sh`). Notes on what is adjusted vs. the source:

## nvim/
- **Excluded:** `.git`, `nvim.log`, `.luarc.json`, and the home-manager wrapper
  `default.nix` (re-homed as a devenv module in `../devenv.nix`).
- **Pruned from `docs/`:** `docs/wayfinder` and `docs/markdown-oxide`
  (~7.5 MB of screenshots / an Obsidian vault). Verified nothing in `init.lua`,
  `lua/`, or `after/` references them.
- **Kept:** `docs/loci/` — referenced at runtime by
  `lua/loci/health/doctor.lua`. The remaining per-plugin `docs/` are upstream
  reference material kept as-is.
- Plugins are managed by `vim.pack` (runtime GitHub clones); see the preseed
  handling in `../devenv.nix`.

## zellij/
- `config.kdl`, `terminal-config.kdl`, `layouts/` copied verbatim.
- **`plugins/`** is nixbox-owned (NOT from dotfiles): the vendored `.wasm`
  plugin binaries (`scripts/fetch-zellij-plugins.sh`). `../devenv.nix` rewrites
  the config's plugin URLs to local `file:` paths pointing at these, so zellij
  never fetches plugins at runtime (works offline / under fornix).
