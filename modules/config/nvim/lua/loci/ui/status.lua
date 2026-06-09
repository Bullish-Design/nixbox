local graph = require("loci.store.graph")
local result = require("loci.result")
-- BOUNDARY EXCEPTION: status uses graph reads as a fallback for early startup
-- before activation callback has provided a cache snapshot.

local M = {}

-- ============================================================================
-- In-memory cache
-- ============================================================================

local cache = {
  repository_id = nil,
  repository_label = nil,
  project_id = nil,
  project_label = nil,
  workspace_id = nil,
  workspace_label = nil,
  refreshed_at = nil,
}

-- ============================================================================
-- Public API
-- ============================================================================

---Get current runtime IDs.
---@return table
function M.current_ids()
  local current_r = graph.read_current()
  local current = (current_r.ok and current_r.value) or {}
  return {
    repository_id = cache.repository_id or current.repository_id,
    project_id = cache.project_id or current.project_id,
    workspace_id = vim.t.loci_workspace_id or cache.workspace_id,
  }
end

---Get current snapshot (best-effort, returns partial data without throwing).
---@param opts? table
---@return loci.Result<{repository,project,workspace,current,ids,diagnostics}>
function M.current_snapshot(opts)
  opts = opts or {}
  local snapshot = {
    repository = nil,
    project = nil,
    workspace = nil,
    current = nil,
    ids = M.current_ids(),
    diagnostics = {},
  }

  -- Try to read repository
  if snapshot.ids.repository_id then
    local repo_r = graph.read_repository()
    if repo_r.ok then
      snapshot.repository = repo_r.value
    else
      table.insert(snapshot.diagnostics, "failed to read repository: " .. repo_r.err)
    end
  end

  -- Try to read workspace
  if snapshot.ids.workspace_id then
    local ws_r = graph.read_workspace(snapshot.ids.workspace_id)
    if ws_r.ok then
      snapshot.workspace = ws_r.value
    else
      table.insert(snapshot.diagnostics, "failed to read workspace: " .. ws_r.err)
    end
  end

  -- Try to read project
  if snapshot.ids.project_id and snapshot.ids.project_id ~= vim.NIL then
    local proj_r = graph.read_project(snapshot.ids.project_id)
    if proj_r.ok then
      snapshot.project = proj_r.value
    else
      table.insert(snapshot.diagnostics, "failed to read project: " .. proj_r.err)
    end
  end

  return result.ok(snapshot)
end

---Clear the in-memory cache.
function M.clear_cache()
  cache.repository_id = nil
  cache.repository_label = nil
  cache.project_id = nil
  cache.project_label = nil
  cache.workspace_id = nil
  cache.workspace_label = nil
  cache.refreshed_at = nil
end

---Get label for a repository.
---@param repository? table repository graph
---@return string|nil
function M.repository_label(repository)
  if not repository then
    return nil
  end

  if repository.name and repository.name ~= "" then
    return repository.name
  end

  if repository.repository_id and repository.repository_id ~= "" then
    return repository.repository_id
  end

  return nil
end

---Get label for a project.
---@param project table project graph
---@return string|nil
function M.project_label(project)
  if not project then
    return nil
  end  if project.title_cache and project.title_cache ~= "" then
    return project.title_cache
  end

  if project.project_id and project.project_id ~= "" then
    return project.project_id
  end

  return nil
end

---Get label for a workspace.
---@param workspace table workspace graph
---@return string
function M.workspace_label(workspace)
  if not workspace then
    return "LOCI"
  end

  -- Try tabby.label first
  if workspace.tabby and workspace.tabby.label and workspace.tabby.label ~= "" then
    return workspace.tabby.label
  end

  -- Fall back to name
  if workspace.name and workspace.name ~= "" then
    return workspace.name
  end

  -- Fall back to workspace_id
  if workspace.workspace_id and workspace.workspace_id ~= "" then
    return workspace.workspace_id
  end

  return "LOCI"
end

---Get current workspace label.
---@return string
function M.current_label()
  -- Try runtime first
  local workspace_id = vim.t.loci_workspace_id or cache.workspace_id
  if not workspace_id then
    -- Try to read from current.json as fallback
    local current_r = graph.read_current()
    if current_r.ok and current_r.value then
      workspace_id = current_r.value.workspace_id
    end
  end

  if not workspace_id then
    return "LOCI"
  end

  if cache.workspace_label and cache.workspace_label ~= "" then
    return cache.workspace_label
  end

  local ws_r = graph.read_workspace(workspace_id)
  if ws_r.ok and ws_r.value then
    return M.workspace_label(ws_r.value)
  end

  return "LOCI"
end

---Get current project label if available.
---@param opts? table
---@return string|nil
function M.current_project_label(opts)
  local ids = M.current_ids()
  if not ids.project_id or ids.project_id == vim.NIL then
    return nil
  end

  -- Return cached label if available
  if cache.project_label then
    return cache.project_label
  end

  -- Try to read project label
  local proj_r = graph.read_project(ids.project_id)
  if proj_r.ok then
    return M.project_label(proj_r.value)
  end

  return nil
end

---Get statusline string with workspace and project labels.
---@param opts? table {separator=nil}
---@return string
function M.statusline(opts)
  opts = opts or {}
  local sep = opts.separator or " · "

  local workspace_label = M.current_label()
  local project_label = M.current_project_label()

  if project_label then
    return workspace_label .. sep .. project_label
  else
    return workspace_label
  end
end

---Get tabline label (workspace label only).
---@param opts? table
---@return string
function M.tabline_label(opts)
  return M.current_label()
end

---Get component string (alias for statusline).
---@param opts? table
---@return string
function M.component(opts)
  return M.statusline(opts)
end

---Refresh in-memory cache after activation.
---@param snapshot? table {repository, project, workspace}
---@return loci.Result
function M.refresh_cache(snapshot)
  snapshot = snapshot or {}

  if snapshot.repository then
    cache.repository_id = snapshot.repository.repository_id
    cache.repository_label = M.repository_label(snapshot.repository)
  end

  if snapshot.project then
    cache.project_id = snapshot.project.project_id
    cache.project_label = M.project_label(snapshot.project)
  end

  if snapshot.workspace then
    cache.workspace_id = snapshot.workspace.workspace_id
    cache.workspace_label = M.workspace_label(snapshot.workspace)
  end

  cache.refreshed_at = os.time()
  return result.ok()
end

return M
