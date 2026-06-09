# TaskNotes delegation boundary

LOCI does not own task lifecycle state.

Task lifecycle belongs to TaskNotes and Markdown frontmatter:

- status,
- priority,
- due dates,
- scheduled dates,
- timers,
- completion,
- recurrence,
- task views.

LOCI delegates to TaskNotes commands:

```vim
:LociTaskBrowse
:LociTaskNew
:LociTaskEdit
:LociTaskRescan
:LociTaskView
```

LOCI intentionally does not provide commands such as:

```text
:LociTaskComplete
:LociTaskArchive
:LociTaskSetStatus
:LociTaskSetPriority
```

## Workspace association is not task ownership

A Workspace may associate with a task Markdown file so it can restore the right working context. That association does not make LOCI the owner of task status or task metadata.

Use TaskNotes for task lifecycle edits. Use LOCI for Workspace activation and cross-tool orchestration.
