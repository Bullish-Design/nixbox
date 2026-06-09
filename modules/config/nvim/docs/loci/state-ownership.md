# LOCI State Ownership

This document defines authoritative state for runtime identity and picker/index data.

## Canonical active workspace state

Authoritative sources:
- Durable: `.loci/graph/current.json`
- Runtime tab-local: `vim.t.loci_workspace_id`

Rules:
- Activation must write `.loci/graph/current.json`.
- Runtime UI commands should prefer `vim.t.loci_workspace_id` for current tab context.
- Global variables are non-authoritative and should not be required for status resolution.

## Graph vs index ownership

Authoritative domain state:
- `.loci/graph/repository.json`
- `.loci/graph/workspaces/*.json`
- `.loci/graph/projects/*.json`
- `.loci/graph/current.json`

Derived cache/index state:
- `.loci/indexes/projects.json`
- `.loci/indexes/workspaces.json`
- `.loci/indexes/markdown.json`

Rules:
- Graph files are source-of-truth.
- Indexes are rebuildable and never authoritative.
- Read APIs should not hide writes or repairs while serving graph data.
