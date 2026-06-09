local result = require("loci.result")
local activation_service = require("loci.service.activation")

local M = {}

-- ============================================================================
-- Workspace ID Resolution
-- ============================================================================

---Resolve workspace_id from explicit input or current activation context.
---@param workspace_id? string
---@return loci.Result<string>
function M.resolve_workspace_id(workspace_id)
  if workspace_id and workspace_id ~= "" then
    return result.ok(workspace_id)
  end

  local current_r = activation_service.current()
  if not current_r.ok then
    return current_r
  end

  local current = current_r.value
  if not current.workspace_id or current.workspace_id == vim.NIL then
    return result.err("no active LOCI workspace", "not_found")
  end

  return result.ok(current.workspace_id)
end

return M
