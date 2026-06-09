# Workspace lifecycle

A Workspace is a concrete working environment inside a repository.

A Workspace may own:

- a branch/worktree binding,
- a Tabby/native tab grouping,
- a Resession tab session,
- one or more Haunt contexts,
- one or more Wayfinder Trail bindings,
- associated Markdown knowledge objects,
- linked source files.

## Create a Workspace

```vim
:LociWorkspaceCreate
```

Then open it:

```vim
:LociWorkspaceSwitch <workspace_id>
```

Without an ID, use the picker:

```vim
:LociWorkspaceSwitch
```

## Repository fallback Workspace

Every repository has a fallback Workspace. It is used for repository-level scratch work and cannot be archived.

Open it with:

```vim
:LociRepositoryOpen
```

## Associate Markdown knowledge

From a Markdown file under `.loci/content/`:

```vim
:LociKnowledgeAdd
```

Or explicitly:

```vim
:LociKnowledgeAdd <workspace_id> content/notes/design.md
:LociKnowledgeSetPrimary <workspace_id> <loci_id>
:LociKnowledgeRemove <workspace_id> <loci_id>
```

`RemoveKnowledge` removes only the Workspace association. It does not delete Markdown.

## Link source files

```vim
:LociFileLink
:LociFileLink src/parser.ts
:LociFileUnlink src/parser.ts
```

Linked files are repository-relative source paths. They are separate from Markdown wikilinks.

## Clone a Workspace

```vim
:LociWorkspaceClone <workspace_id>
```

A clone receives fresh runtime identities:

- new Workspace ID,
- new Resession session name,
- new Haunt context directories,
- new Wayfinder Trail names,
- cleared Tabby runtime cache.

## Archive a Workspace

```vim
:LociWorkspaceArchive <workspace_id> reason text
```

Archiving marks the Workspace as archived. It does not delete Markdown or integration data.

The repository fallback Workspace is protected and cannot be archived.
