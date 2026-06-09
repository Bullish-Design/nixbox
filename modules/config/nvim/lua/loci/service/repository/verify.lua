local result = require("loci.result")
local graph = require("loci.store.graph")

local M = {}

function M.verify_existing(opts)
  opts = opts or {}

  local repo_r = graph.read_repository()
  if not repo_r.ok then return repo_r end

  local fallback_r = graph.read_workspace(repo_r.value.default_workspace_id)
  if not fallback_r.ok then
    return result.err("Repository fallback workspace is not valid", "repository_verify_failed", { cause = fallback_r })
  end

  local current_r = graph.read_current()
  if not current_r.ok and current_r.code ~= "not_found" then
    return result.err("Repository current pointer is invalid", "repository_verify_failed", { cause = current_r })
  end

  return result.ok({ repository = repo_r.value, fallback_workspace = fallback_r.value, current = current_r.ok and current_r.value or nil })
end

return M
