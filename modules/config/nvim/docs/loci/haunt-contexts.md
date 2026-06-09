# Haunt contexts

LOCI binds Haunt data directories to Workspaces.

Each Workspace has one active Haunt context and may have multiple named contexts:

```text
main
implementation
debugging
review
```

LOCI owns the registry of context names. Haunt owns the annotation data.

## Commands

```vim
:LociHauntList
:LociHauntNew implementation
:LociHauntSwitch implementation
:LociHauntRename implementation debugging
:LociHauntDelete debugging
```

## Storage

Context directories are stored under:

```text
.loci/integrations/haunt/workspaces/<workspace_id>/<context_name>
```

The stored path in the Workspace graph is repository-relative and begins with `.loci/`.

## Deletion safety

LOCI refuses to delete non-empty Haunt context directories without explicit confirmation. This protects annotation data.

Deleting the active context requires switching to another context in the same operation.

## Missing Haunt

If Haunt is not installed, LOCI keeps the Workspace graph valid and reports an integration warning. Workspace graph operations should not corrupt state merely because Haunt is unavailable.
