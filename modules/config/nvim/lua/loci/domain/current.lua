local id = require("loci.domain.id")
local result = require("loci.result")

local M = {}

function M.validate(value)
  if type(value) ~= "table" then
    return result.err("current pointer must be a table", "validation_failed")
  end

  local ws = value.current_workspace_id
  if ws ~= nil and ws ~= vim.NIL and not id.is_valid(ws) then
    return result.err("invalid current_workspace_id", "validation_failed")
  end

  local project = value.current_project_id
  if project ~= nil and project ~= vim.NIL and not id.is_valid(project) then
    return result.err("invalid current_project_id", "validation_failed")
  end

  if value.updated_at ~= nil and value.updated_at ~= vim.NIL and type(value.updated_at) ~= "string" then
    return result.err("updated_at must be a string", "validation_failed")
  end

  return result.ok(value)
end

return M
