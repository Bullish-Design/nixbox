# Wayfinder Trails

LOCI stores logical Wayfinder Trail bindings per Workspace.

Wayfinder owns actual Trail contents. LOCI owns the registry that says which logical Trail belongs to which Workspace.

Example logical Trails:

```text
main
repro
review
```

Generated Wayfinder Trail names look like:

```text
loci-<workspace_id>-<logical_name>
```

## Commands

```vim
:LociTrailList
:LociTrailCreate repro
:LociTrailSwitch repro
:LociTrailSave repro
:LociTrailLoad repro
:LociTrailRename repro reproduction
:LociTrailDelete reproduction
:LociTrailExport
```

Managed Loci Trails require Wayfinder's direct named Trail API. Loci does not
use interactive command fallback for managed Trail create/save/load/rename/delete
operations because those operations must keep graph state and Wayfinder state
aligned.

Display/export commands may use non-mutating Wayfinder integrations when
explicitly documented, but registry-mutating operations require the named API.

## Activation behavior

When a Workspace opens, LOCI attempts to resume or load its active logical Trail. Wayfinder failures are soft integration failures and should not block core Workspace activation.
