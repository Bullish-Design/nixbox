local result = require("loci.result")
local graph = require("loci.store.graph")
local workspace_domain = require("loci.domain.workspace")

local M = {}

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

function M.resolve_and_read(workspace_id, opts)
  opts = opts or {}
  local resolved_id = workspace_id
  if not resolved_id or resolved_id == "" then
    local current_r = graph.read_current()
    if not current_r.ok then
      return current_r
    end
    resolved_id = current_r.value.current_workspace_id
    if not resolved_id or resolved_id == vim.NIL or resolved_id == "" then
      return result.err("no active LOCI workspace", "not_found")
    end
  end

  local ws_r = graph.read_workspace(resolved_id)
  if not ws_r.ok then
    return ws_r
  end

  return result.ok({ workspace_id = resolved_id, workspace = ws_r.value }, { op = opts.op })
end

function M.read(workspace_id)
  local read_r = M.resolve_and_read(workspace_id)
  if not read_r.ok then
    return read_r
  end
  return result.ok(read_r.value.workspace)
end

function M.write(workspace)
  if type(workspace) ~= "table" then
    return result.err("workspace must be a table", "invalid_input")
  end
  local write_r = graph.write_workspace(workspace)
  if not write_r.ok then
    return write_r
  end
  return result.ok(workspace)
end

function M.update(workspace_id, mutate, opts)
  opts = opts or {}
  if type(mutate) ~= "function" then
    return result.err("workspace transaction mutator is required", "invalid_input")
  end

  local read_r = M.resolve_and_read(workspace_id, opts)
  if not read_r.ok then
    return read_r
  end

  local resolved_workspace_id = read_r.value.workspace_id
  local workspace = read_r.value.workspace
  local before = vim.deepcopy(workspace)

  local mutate_r = mutate(workspace)
  if mutate_r == nil then
    mutate_r = result.ok(nil)
  elseif type(mutate_r) == "table" and mutate_r.ok == nil then
    mutate_r = result.ok(mutate_r)
  elseif type(mutate_r) ~= "table" or mutate_r.ok == nil then
    return result.err("workspace transaction mutator must return a Result, table, or nil", "invalid_input")
  end

  if not mutate_r.ok then
    return mutate_r
  end

  local validate_r = workspace_domain.validate(workspace)
  if not validate_r.ok then
    return validate_r
  end

  local write_r = graph.write_workspace(workspace)
  if not write_r.ok then
    return write_r
  end

  local changed = vim.deep_equal(before, workspace) == false
  return result.ok({
    workspace_id = resolved_workspace_id,
    workspace = workspace,
    changed = changed,
    payload = mutate_r.value,
  }, { op = opts.op })
end

function M.add_workspace_to_project(project_id, workspace_id)
  if not project_id or project_id == vim.NIL then
    return result.ok(nil)
  end

  local project_r = graph.read_project(project_id)
  if not project_r.ok then
    return project_r
  end

  local project = project_r.value
  project.workspace_ids = project.workspace_ids or {}

  if not contains(project.workspace_ids, workspace_id) then
    table.insert(project.workspace_ids, workspace_id)
  end

  return graph.write_project(project)
end

function M.remove_workspace_from_project(project_id, workspace_id)
  if not project_id or project_id == vim.NIL then
    return result.ok(nil)
  end

  local project_r = graph.read_project(project_id)
  if not project_r.ok then
    return project_r
  end

  local project = project_r.value
  project.workspace_ids = project.workspace_ids or {}

  for i = #project.workspace_ids, 1, -1 do
    if project.workspace_ids[i] == workspace_id then
      table.remove(project.workspace_ids, i)
      break
    end
  end

  return graph.write_project(project)
end

return M
