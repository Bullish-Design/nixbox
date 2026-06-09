# LOCI

LOCI is a repository-local Neovim orchestration layer for Markdown-driven software work.

It coordinates:

```text
Repository -> Project -> Workspace
```

Markdown remains the knowledge layer. LOCI owns resumable editor/runtime state.

## Ownership model

| Concern | Owner |
|---|---|
| Notes, prose, links, task metadata | Markdown / Obsidian / TaskNotes |
| Task status, priority, due dates, timers, completion | TaskNotes |
| Bases dashboards | Obsidian Bases |
| Markdown backlinks/navigation | Obsidian / markdown-oxide |
| Code annotations | Haunt |
| Exploration Trails | Wayfinder |
| Editor sessions | Resession |
| Tab/window grouping | Tabby / Neovim |
| Cross-tool orchestration | LOCI |

## Start here

1. [Repository initialization](repository-initialization.md)
2. [Workspace lifecycle](workspace-lifecycle.md)
3. [Haunt contexts](haunt-contexts.md)
4. [Wayfinder Trails](wayfinder-trails.md)
5. [Obsidian symlink setup](obsidian-symlink-setup.md)
6. [TaskNotes delegation boundary](tasknotes-delegation.md)
7. [Troubleshooting with LOCI Doctor](troubleshooting.md)

## Canonical model

Loci treats graph JSON as the source of truth. Runtime integrations such as
Haunt, Wayfinder, Resession, and Tabby are projections of committed graph state.

Normal operations use strict canonical data. Doctor/repair commands may perform
tolerant scans and report noncanonical files, but normal commands do not
silently support old or ambiguous shapes.

## Core commands

```vim
:LociInit
:LociHealth
:LociDoctor
:LociRefresh
:LociRepositoryOpen
:LociProjectCreate
:LociProjectSwitch
:LociWorkspaceCreate
:LociWorkspaceSwitch
:LociWorkspaceSwitch
:LociHauntList
:LociTrailList
```
