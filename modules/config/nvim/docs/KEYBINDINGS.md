# Keybinding Architecture

## Layered System

Keymaps are organized into five layers, each with clear ownership rules:

```
Layer 1: Global grammar          keymaps/global.lua
  Always-available editor actions: save, quit, windows, buffers, tabs, scroll.

Layer 2: Plugin entry grammar    keymaps/plugin_entries.lua
  Global keys that OPEN plugin features: <leader>ff for picker, <leader>e for explorer.

Layer 3: Buffer-local grammar    keymaps/lsp.lua (via LspAttach autocmd)
  Keys that only exist in certain buffers: LSP mappings appear when a server attaches.

Layer 4: Plugin-internal grammar (defined in each plugin's config file)
  Keys inside plugin UIs: q to close workspace center, <CR> to select in picker.
  Owned by the plugin config, NOT the central keymaps.

Layer 5: Discovery grammar       ui/which_key.lua
  which-key displays all of the above. It does NOT create any mappings.
```

### Ownership rules

- `keymaps/*.lua` owns all global mappings and global plugin entrypoints
- Plugin config files (e.g., `git/neogit.lua`) own plugin-internal keymaps only
- `keymaps/lsp.lua` owns buffer-local LSP overlays
- `ui/which_key.lua` owns display groups/presets — never creates actual mappings
- All mappings use `desc = "..."` so which-key discovers them automatically

### Conflict detection

All keymaps flow through `keymaps/registry.lua`, which checks for existing mappings before setting new ones. Conflicts emit a warning rather than silently overwriting.

---

## Leader Groups

Leader is `<Space>`. Local leader is `,`.

| Prefix | Group | Purpose |
|---|---|---|
| `<leader>b` | Buffer | Buffer operations |
| `<leader>c` | Code | LSP actions (rename, action, format, diagnostics) |
| `<leader>f` | Find | Picker (files, grep, buffers, help, etc.) |
| `<leader>g` | Git | Neogit, diffview, blame, browse |
| `<leader>q` | Quit/Session | Quit all, session restore/stop |
| `<leader>s` | Search/Replace | Grug-far find and replace |
| `<leader>t` | Tab | Tabpage operations |
| `<leader>u` | UI toggle | Precognition, inlay hints |
| `<leader>w` | Window/Workspace | Splits, close, zoom, workspace center |
| `<leader>x` | Diagnostics | (Reserved) |

---

## Complete Keymap Reference

### Global Editor (keymaps/global.lua)

#### Save / Quit
| Key | Action |
|---|---|
| `<C-s>` | Save file |
| `<leader>qq` | Quit all |
| `<leader>?` | Show buffer-local keymaps |

#### Windows
| Key | Action |
|---|---|
| `<C-h/j/k/l>` | Focus window left/down/up/right |
| `<leader>wd` | Close window |
| `<leader>w-` | Split below |
| `<leader>w\|` | Split right |
| `<leader>ww` | Other window |
| `<leader>wz` | Zoom window (snacks.zoom) |

#### Buffers
| Key | Action |
|---|---|
| `<Tab>` | Next buffer |
| `<S-Tab>` | Previous buffer |
| `<leader>bd` | Delete buffer (mini.bufremove) |

#### Tabs (Workspace Tabpages)
| Key | Action |
|---|---|
| `<leader>tn` | New tab |
| `<leader>tc` | Close tab |
| `<leader>to` | Only this tab |
| `]t` | Next tab |
| `[t` | Previous tab |

#### Misc
| Key | Action |
|---|---|
| `<Esc>` | Clear search highlight |

---

### Navigation (keymaps/navigation.lua)

| Key | Action |
|---|---|
| `n` | Search next (centered) |
| `N` | Search prev (centered) |
| `<C-d>` | Half-page down (centered) |
| `<C-u>` | Half-page up (centered) |

---

### Picker / Find (keymaps/plugin_entries.lua)

| Key | Action |
|---|---|
| `<leader>ff` / `<leader><space>` | Find files |
| `<leader>fg` / `<leader>/` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |
| `<leader>fk` | Keymaps |
| `<leader>fd` | Diagnostics |
| `<leader>fc` | Commands |
| `<leader>fs` | LSP symbols |
| `<leader>fG` | Git status |

---

### Explorer / Terminal / Scratch

| Key | Action |
|---|---|
| `<leader>e` | File explorer (snacks.explorer) |
| `<A-i>` | Toggle terminal (normal + terminal mode) |
| `<Esc><Esc>` | Exit terminal mode to normal |
| `<leader>.` | Scratch buffer |

---

### Git (keymaps/plugin_entries.lua)

| Key | Action |
|---|---|
| `<leader>gg` | Open Neogit |
| `<leader>gD` | Open Diffview |
| `<leader>gq` | Close Diffview |
| `<leader>gb` | Git blame/show at cursor (mini.git) |

---

### Search / Replace

| Key | Action |
|---|---|
| `<leader>sr` | Open grug-far (project-wide find/replace) |

---

### Sessions (keymaps/plugin_entries.lua)

| Key | Action |
|---|---|
| `<leader>qs` | Restore session (current dir) |
| `<leader>ql` | Restore last session |
| `<leader>qd` | Stop session auto-save |

---

### UI Toggles

| Key | Action |
|---|---|
| `<leader>up` | Toggle precognition (motion hints) |
| `<leader>uh` | Toggle inlay hints |

---

### Workspace Center (plugin-internal, workspace/center/init.lua)

These keys are buffer-local inside the workspace center sidebar:

| Key | Action |
|---|---|
| `f` | Find files |
| `g` | Live grep |
| `b` | Buffers |
| `t` | Terminal |
| `G` | Git status |
| `q` | Close |

---

### LSP (keymaps/lsp.lua — buffer-local via LspAttach)

#### Navigation
| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gr` | References |
| `gI` | Implementation |
| `gy` | Type definition |
| `gD` | Declaration |

#### Info
| Key | Action |
|---|---|
| `K` | Hover documentation |
| `<C-k>` (insert) | Signature help |

#### Actions
| Key | Action |
|---|---|
| `<leader>cr` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>cf` | Format buffer |
| `<leader>cd` | Line diagnostics (float) |

---

### Editing Primitives (plugin-internal, set by each plugin)

#### mini.surround
| Key | Action |
|---|---|
| `sa` | Add surrounding |
| `sd` | Delete surrounding |
| `sr` | Replace surrounding |

#### mini.comment
| Key | Action |
|---|---|
| `gcc` | Toggle comment (line) |
| `gc` | Toggle comment (visual/motion) |

#### mini.move
| Key | Action |
|---|---|
| `<A-h/j/k/l>` | Move line/selection left/down/up/right |

#### mini.splitjoin
| Key | Action |
|---|---|
| `gS` | Toggle single/multi-line |

#### mini.ai (text objects)
| Key | Action |
|---|---|
| `af/if` | Around/inside function |
| `ac/ic` | Around/inside class |
| `aa/ia` | Around/inside argument |

#### yanky.nvim
| Key | Action |
|---|---|
| `p` / `P` | Put after/before (with yank ring) |
| `<C-p>` | Cycle to previous yank entry |
| `<C-n>` | Cycle to next yank entry |

---

### Bracket Navigation (mini.bracketed)

| Key | Action |
|---|---|
| `[b` / `]b` | Previous/next buffer |
| `[d` / `]d` | Previous/next diagnostic |
| `[q` / `]q` | Previous/next quickfix |
| `[t` / `]t` | Previous/next tab (overridden by global.lua) |

---

### Treesitter Movement (treesitter-textobjects)

| Key | Action |
|---|---|
| `]m` | Next function start |
| `[m` | Previous function start |
| `]]` | Next class start |
| `[[` | Previous class start |
