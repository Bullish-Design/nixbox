# Repository initialization

A LOCI repository is a code repository with a `.loci/` directory.

Initialize LOCI from the repository root:

```vim
:LociInit
```

LOCI creates:

```text
.loci/
  loci.json
  repository.json
  content/
  graph/
  integrations/
  indexes/
```

Important files:

| File | Purpose |
|---|---|
| `.loci/loci.json` | sentinel and repository-local config |
| `.loci/repository.json` | repository identity and fallback Workspace pointer |
| `.loci/graph/current.json` | active Workspace pointer |
| `.loci/graph/workspaces/*.json` | Workspace orchestration state |
| `.loci/graph/projects/*.json` | Project orchestration/cache state |
| `.loci/content/` | Obsidian-visible Markdown knowledge |
| `.loci/indexes/*.json` | rebuildable picker/cache indexes |

## Repository-local config

You may store LOCI config in `.loci/loci.json`:

```json
{
  "schema_version": 1,
  "kind": "loci",
  "vault": {
    "path": "~/Documents/Notes",
    "project_path": "1_Projects/example-repo",
    "symlink_name": "loci"
  },
  "integrations": {
    "haunt": true,
    "wayfinder": true,
    "resession": true,
    "tabby": true,
    "tasknotes": true,
    "obsidian": true,
    "bases": true
  },
  "refresh": {
    "on_setup": false,
    "before_picker": true,
    "after_markdown_save": false
  }
}
```

Neovim setup overrides repository-local config:

```lua
require("loci").setup({
  refresh = { before_picker = true },
})
```

## Validate the repository

```vim
:LociHealth
:LociDoctor
```

`LociHealth` reports facts. `LociDoctor` shows remediation hints and useful commands.
