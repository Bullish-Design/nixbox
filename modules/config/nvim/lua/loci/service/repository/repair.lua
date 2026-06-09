local result = require("loci.result")
local graph = require("loci.store.graph")
local create = require("loci.service.repository.create")
local id = require("loci.domain.id")

local M = {}

local function is_missing(r)
  return r ~= nil and r.code == "not_found"
end

local function now(opts)
  if opts and type(opts.now) == "string" and opts.now ~= "" then
    return opts.now
  end
  return id.now_iso()
end

function M.repair(opts)
  opts = opts or {}
  local actions = {}

  local repo_r = graph.read_repository()
  if not repo_r.ok then
    return result.err("Repository graph is not readable; cannot repair", "repair_blocked_invalid_repository", { cause = repo_r })
  end
  local repo = repo_r.value

  local fallback_r = graph.read_workspace(repo.default_workspace_id)
  if fallback_r.ok then
  elseif is_missing(fallback_r) then
    local create_r = create.create_fallback_workspace_public(repo)
    if not create_r.ok then return create_r end
    actions[#actions + 1] = { action = "created_fallback_workspace", id = repo.default_workspace_id }
  else
    return result.err("Fallback workspace is corrupt; manual recovery required", "repair_blocked_corrupt_fallback", { cause = fallback_r, id = repo.default_workspace_id })
  end

  local current_r = graph.read_current()
  if current_r.ok then
  elseif is_missing(current_r) then
    local write_r = graph.write_current({
      current_workspace_id = repo.default_workspace_id,
      current_project_id = nil,
      workspace_id = repo.default_workspace_id,
      project_id = nil,
      repository_id = repo.repository_id,
      activated_at = now(opts),
      updated_at = now(opts),
    })
    if not write_r.ok then return write_r end
    actions[#actions + 1] = { action = "created_current_pointer" }
  else
    return result.err("Current pointer is corrupt; manual recovery required", "repair_blocked_corrupt_current", { cause = current_r })
  end

  local dirs_r = create.ensure_repository_dirs_public()
  if not dirs_r.ok then return dirs_r end
  actions[#actions + 1] = { action = "ensured_directories" }

  return result.ok({ actions = actions, repaired = #actions > 0 })
end

return M
