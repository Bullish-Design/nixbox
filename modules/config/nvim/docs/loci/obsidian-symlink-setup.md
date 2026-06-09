# Obsidian symlink setup

LOCI exposes only `.loci/content/` to Obsidian.

It does **not** symlink graph files, indexes, integration data, or internal state.

## Configure the vault

In `.loci/loci.json` or `require("loci").setup()`:

```json
{
  "vault": {
    "path": "~/Documents/Notes",
    "project_path": "1_Projects/example-repo",
    "symlink_name": "loci"
  },
  "integrations": {
    "obsidian": true,
    "bases": true
  }
}
```

The resulting symlink is:

```text
~/Documents/Notes/1_Projects/example-repo/loci -> /path/to/repo/.loci/content
```

## Create or verify the symlink

Run:

```vim
:LociInit
:LociHealth
:LociDoctor
```

If the symlink path already exists and points elsewhere, LOCI reports a conflict and does not overwrite it.

## Bases

LOCI generates `.base` files under:

```text
.loci/content/bases/
```

Bases query Markdown frontmatter. They do not query LOCI graph JSON as the source of truth.
