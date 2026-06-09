local M = {}

local function project_id_or_nil(project_id)
  if project_id == nil or project_id == vim.NIL or project_id == "" then
    return nil
  end
  return project_id
end

---@param plan table
function M.apply_activation(plan)
  vim.g.loci_repository_id = plan.repository.repository_id
  vim.g.loci_project_id = project_id_or_nil(plan.workspace.project_id)
  vim.t.loci_workspace_id = plan.workspace.workspace_id
end

---@return string|nil
function M.get_tab_workspace_id()
  local tab_id = vim.t.loci_workspace_id
  if tab_id and tab_id ~= "" then
    return tab_id
  end
  return nil
end

function M.clear_runtime()
  vim.g.loci_project_id = nil
  vim.t.loci_workspace_id = nil
end

---@param workspace_id string
function M.set_tab_workspace_id(workspace_id)
  vim.t.loci_workspace_id = workspace_id
end

return M
