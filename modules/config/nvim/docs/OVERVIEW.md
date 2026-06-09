# Neovim Configuration Overview

## Philosophy

This is a Neovim 0.12+ configuration built on three pillars:

1. **Hybrid plugin management.** `vim.pack` (Neovim's built-in plugin manager) manages all Lua plugins with explicit version pinning and a lockfile. Nix provides treesitter grammars (compiled C) and the Neovim binary itself.

2. **One owner per surface.** No two plugins compete to render or manage the same UI element. Every screen surface — cmdline, statusline, completions, file tree, etc. — has exactly one owner.

3. **Native where possible.** Neovim 0.12 built-in APIs own Tree-sitter highlighting, cmdline/message UI (UI2), LSP client configuration, diagnostics, and formatting.

---

## Plugin Management

### vim.pack (Lua plugins)

All Lua plugins are managed by `vim.pack` — Neovim 0.12's built-in plugin manager. Plugins are declared in `init.lua` via `vim.pack.add()` with explicit version pins (commit SHAs or tags):

```lua
vim.pack.add({
  { src = 'https://github.com/echasnovski/mini.nvim', version = 'v0.14.0' },
  { src = 'https://github.com/folke/snacks.nvim', version = 'abc1234' },
  -- ...
})
```

Reproducibility is maintained via:
- **Explicit `version` fields** pinning to tags or commit SHAs
- **Lockfile** (`nvim-pack-lock.json`) recording exact revisions, committed to the dotfiles repo
- Updates are deliberate: run `:packupdate`, review changes, confirm, commit lockfile

On a fresh machine, first launch installs all plugins at the lockfile's pinned revisions.

### Nix (treesitter grammars + binary)

Nix provides only what requires compilation or system-level integration:
- The Neovim 0.12+ binary (pinned via nixpkgs-neovim overlay)
- Treesitter grammars via `nvim-treesitter.withAllGrammars` (compiled C parsers)
- The `nv` wrapper script that sets `packpath` to include the Nix-provided grammar pack

```nix
# Nix only provides treesitter grammars as a packpath entry
treesitterPack = linkFarm "nvim-treesitter" [{
  name = "pack/nix/start/nvim-treesitter";
  path = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
}];
```

This separation means the Lua config is portable — it works on any machine with Neovim 0.12+ and internet access for the initial `vim.pack` install.

---

## Plugin Ecosystem

The config uses three primary ecosystems plus targeted standalone plugins:

| Ecosystem | Role | Owns |
|---|---|---|
| **Neovim native** | Foundation | Treesitter, LSP, diagnostics, formatting, UI2 messages/notifications |
| **mini.nvim** | Quiet primitives | Editing (surround, pairs, comment, text objects), statusline, git signs, icons |
| **which-key.nvim** | Keymap discovery | Leader/localleader key hint popup and keymap browsing |
| **snacks.nvim** | Interaction surfaces | Picker, explorer, terminal, dashboard, scratch, git browse, zoom |
| **blink.cmp** | Completion | Insert completion, cmdline completion, snippets, signature help |

Standalone plugins fill specific gaps: nvim-lspconfig (LSP server data: filetypes, root markers, default cmds), neogit (full git UI), edgy (sidebar layout), tabby (workspace tabs), yanky (yank history), grug-far (find/replace), persistence (sessions), precognition (motion hints), todo-comments (highlight tags).

---

## Architecture Layers

```
Neovim 0.12+ (native: treesitter, UI2, vim.lsp, vim.diagnostic)
  |
  ├── UI layer           colorscheme, UI2 messages, tiny-cmdline, statusline, tabline, which-key
  ├── Editing layer      pairs, surround, ai, comment, move, splitjoin, bracketed, yanky
  ├── Visual layer       indentscope, hipatterns, icons, todo-comments, scope, precognition
  ├── Intelligence layer treesitter, blink.cmp, LSP (config/enable/format)
  ├── Interaction layer  snacks (picker, explorer, terminal, dashboard, scratch, git)
  ├── Git layer          mini.diff (signs), mini.git (commands), neogit+diffview (full UI)
  └── Workspace layer    edgy (sidebars), persistence (sessions), workspace center
```

---

## File Structure

```
nvim/
├── default.nix              Nix module: builds 'nv' wrapper, provides treesitter via packpath
├── overlays.nix             Pins Neovim 0.12 binary from nixpkgs-neovim
├── init.lua                 Entry point: leader keys, vim.pack.add(), load order
├── nvim-pack-lock.json      vim.pack lockfile (committed, tracks exact plugin revisions)
├── docs/                    Plugin documentation and reference
└── lua/
    ├── core/                Foundation (no plugin deps): options, autocmds
    ├── keymaps/             Layered keybinding system: registry, global, navigation, lsp, plugin_entries
    ├── ui/                  UI layer: colorscheme, ui2, tiny_cmdline, statusline, tabline, which_key
    ├── editing/             Editing primitives: pairs, surround, ai, comment, move, splitjoin, yanky, etc.
    ├── intelligence/        LSP, treesitter, completion (blink.cmp)
    ├── interaction/         Snacks-powered surfaces: picker, explorer, terminal, dashboard, scratch
    ├── git/                 Git integration: signs, commands, neogit, browse
    ├── visual/              Visual enhancements: indentscope, hipatterns, icons, todo_comments, scope
    └── workspace/           Workspace management: edgy, persistence, center
```

---

## Design Decisions

### vim.pack for plugins, Nix for compiled artifacts
Lua plugins are managed by `vim.pack` with version-pinned lockfile for reproducibility. Nix handles only treesitter grammars (compiled C) and the Neovim binary. This gives correct plugin load ordering (via native `packpath`/`packadd`), portability across machines, and no custom rtp injection hacks.

### nvim-lspconfig as a data package
Neovim 0.12+ provides `vim.lsp.config()` and `vim.lsp.enable()` natively. nvim-lspconfig is still used — not as a framework, but as a data package. Its `lsp/` directory provides per-server defaults (filetypes, root_markers, cmd) that `vim.lsp.enable()` discovers automatically on the runtimepath. Our config only overrides where custom settings are needed (lua_ls workspace, rust-analyzer clippy). No `require('lspconfig')` calls exist.

### No conform.nvim / nvim-lint
Formatting uses `vim.lsp.buf.format()` (format-on-save via LspAttach). Linting comes from LSP servers that provide diagnostics natively (ruff, rust-analyzer, etc.).

### No noice.nvim
Native UI2 handles cmdline display, messages, notifications, and pager. tiny-cmdline repositions the cmdline to a floating popup.

### Workspace-per-tabpage
Tabpages represent named workspace layouts (code, tests, terminal), not individual files. Buffer navigation is via snacks.picker, not a bufferline.

---

## External Dependencies

All installed via Nix:

- **Search:** ripgrep, fd
- **LSP servers:** lua-language-server, nil (Nix), pyright, ruff, rust-analyzer, typescript-language-server, vscode-json-language-server, yaml-language-server
- **Formatters:** stylua, prettier, rustfmt (via LSP servers, not conform)
- **Git:** git, gh (GitHub CLI)
- **Treesitter:** All parsers via `nvim-treesitter.withAllGrammars` (Nix-provided, added to packpath)

---

## Plugin Update Workflow

1. Run `:packupdate` — downloads latest changes from sources
2. Review the confirmation buffer (shows changelogs per plugin)
3. Confirm (`:w`) or deny (`:q`)
4. Commit updated `nvim-pack-lock.json` to dotfiles repo

To pin a plugin to a specific version, set `version` in `vim.pack.add()` spec. To freeze a plugin from updates entirely, set `version` to its current commit SHA from the lockfile.
