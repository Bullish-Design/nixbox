# Troubleshooting LOCI

Use:

```vim
:LociHealth
:LociDoctor
```

`LociHealth` shows health facts through Neovim's health provider. `LociDoctor` opens a Markdown buffer with remediation hints.

## Common issues

### Repository is not initialized

Run:

```vim
:LociInit
```

### Current Workspace pointer is invalid

Run:

```vim
:LociRepositoryOpen
:LociWorkspaceSwitch
```

Then refresh:

```vim
:LociRefresh
```

### Missing Markdown association

A Workspace can point at a Markdown `loci_id` whose file was moved or deleted.

If the file was moved and kept the same `loci_id`, run:

```vim
:LociRefresh
```

If the file was deleted intentionally, remove the association:

```vim
:LociKnowledgeRemove <workspace_id> <loci_id>
```

### Optional plugin unavailable

If an optional plugin is not installed, either install it or disable the integration in config:

```json
{
  "integrations": {
    "wayfinder": false
  }
}
```

Optional integration warnings should not block core repository initialization or Workspace activation.

### Obsidian symlink conflict

If the configured vault path already contains a file, directory, or symlink at the target location, LOCI reports a conflict and refuses to overwrite it.

Inspect the target manually, move it aside if appropriate, then run:

```vim
:LociHealth
:LociDoctor
```
