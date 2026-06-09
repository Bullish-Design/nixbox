local result = require("loci.result")
local id = require("loci.domain.id")
local graph = require("loci.store.graph")
local tx = require("loci.service.workspace.tx")

local M = {}

local function now(opts)
  if opts and type(opts.clock) == "function" then
    return opts.clock()
  end
  if opts and type(opts.now) == "string" and opts.now ~= "" then
    return opts.now
  end
  return id.now_iso()
end

---@async
---@param workspace_id string
---@param opts? table
---@return loci.Result<table>
function M.archive(workspace_id, opts)
  opts = opts or {}

  -- Check fallback workspace protection before transaction
  local repo_r = graph.read_repository()
  if repo_r.ok and workspace_id == repo_r.value.default_workspace_id then
    return result.err("cannot archive repository fallback workspace", "invalid_input", {
      workspace_id = workspace_id,
      default_workspace_id = repo_r.value.default_workspace_id,
      protected = true,
    })
  end

  local timestamp = now(opts)
  local archived_project_id = nil

  local archive_r = tx.update(workspace_id, function(workspace)
    -- Double-check inside transaction in case workspace_id was resolved
    if repo_r.ok and workspace.workspace_id == repo_r.value.default_workspace_id then
      return result.err("cannot archive repository fallback workspace", "invalid_input", {
        workspace_id = workspace.workspace_id,
        default_workspace_id = repo_r.value.default_workspace_id,
        protected = true,
      })
    end

    archived_project_id = workspace.project_id

    if workspace.archive then
      if opts.reason then
        workspace.archive.reason = opts.reason
      end
    else
      workspace.archive = {
        archived_at = timestamp,
        reason = opts.reason or vim.NIL,
      }
    end

    return result.ok(workspace)
  end)

  if not archive_r.ok then
    return archive_r
  end

  -- Post-transaction side effect: remove from project
  if opts.remove_from_project and archived_project_id and archived_project_id ~= vim.NIL then
    local proj_r = tx.remove_workspace_from_project(archived_project_id, workspace_id)
    if not proj_r.ok then
      return proj_r
    end
  end

  return archive_r
end

return M
