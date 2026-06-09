---
--- LOCI Service: Workspace
---
--- This module has been refactored into focused submodules:
--- - core.lua: workspace creation, opening, info, markdown helpers
--- - archive.lua: workspace archival
--- - knowledge.lua: knowledge object management
--- - linked_files.lua: linked file association
--- - clone.lua: workspace cloning
--- - haunt.lua: Haunt context lifecycle
--- - trails.lua: Wayfinder Trail lifecycle
--- - resolve.lua: workspace ID resolution helpers
--- - validation.lua: haunt and trail validation helpers
---
--- This init.lua re-exports canonical workspace service APIs from focused modules.
---

local M = vim.tbl_extend(
  "force",
  {},
  require("loci.service.workspace.core"),
  require("loci.service.workspace.archive"),
  require("loci.service.workspace.knowledge"),
  require("loci.service.workspace.linked_files"),
  require("loci.service.workspace.clone"),
  require("loci.service.workspace.haunt"),
  require("loci.service.workspace.trails")
)

-- ============================================================================
-- Refresh (delegates to store.refresh)
-- ============================================================================

---Refresh workspace graph.
---@async
---@param workspace_id string
---@param opts? table
---@return loci.Result<table>
function M.refresh(workspace_id, opts)
  local refresh = require("loci.store.refresh")
  return refresh.run(opts)
end

---@async
---@return loci.Result<table[]>
function M.index_entries(opts)
  return M.picker_entries(opts)
end

---@async
---@return loci.Result<table[]>
function M.list()
  local graph = require("loci.store.graph")
  return graph.list_workspaces()
end

---@async
---@param opts? table
---@return loci.Result<table[]>
function M.picker_entries(opts)
  local json_store = require("loci.store.json")
  local p = require("loci.store.path")
  local index_path = p.must_index_path("workspaces.json")
  local r = json_store.read(index_path)
  if not r.ok then
    return r
  end
  return require("loci.result").ok((r.value and r.value.workspaces) or {})
end

---@param workspace_id string
---@return boolean
function M.exists(workspace_id)
  local graph = require("loci.store.graph")
  local r = graph.read_workspace(workspace_id)
  return r.ok == true
end

---@async
---@param opts? table
---@return loci.Result
function M.refresh_all(opts)
  local refresh = require("loci.store.refresh")
  return refresh.run(opts)
end

return M
