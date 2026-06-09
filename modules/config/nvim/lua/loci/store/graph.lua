local result = require("loci.result")
local id = require("loci.domain.id")
local current_domain = require("loci.domain.current")
local project_domain = require("loci.domain.project")
local workspace_domain = require("loci.domain.workspace")
local path = require("loci.store.path")
local fs = require("loci.store.fs")
local json = require("loci.store.json")

local M = {}

local function require_valid_id(value, label)
  if not id.is_valid(value) then
    return result.err("invalid " .. label .. ": " .. tostring(value), "invalid_input", { id = value })
  end
  return result.ok(value)
end

local function map_read_code(read_r)
  if read_r.code == "not_found" then return "not_found" end
  if read_r.code == "invalid_json" or read_r.code == "decode_failed" then return "invalid_json" end
  if read_r.code == "permission_denied" then return "permission_denied" end
  if read_r.code == "io_read_failed" then return "io_read_failed" end
  return read_r.code or "io_read_failed"
end

local function project_path(project_id)
  return path.must_graph_path("projects/" .. project_id .. ".json")
end

local function workspace_path(workspace_id)
  return path.must_graph_path("workspaces/" .. workspace_id .. ".json")
end

function M.read_repository()
  return json.read(path.loci_root() .. "/repository.json")
end

function M.write_repository(repository)
  local repository_domain = require("loci.domain.repository")
  local r = repository_domain.validate(repository)
  if not r.ok then return r end
  return json.write(path.loci_root() .. "/repository.json", repository)
end

function M.read_project(project_id)
  local valid = require_valid_id(project_id, "project_id")
  if not valid.ok then return valid end
  local read_r = json.read(project_path(project_id))
  if not read_r.ok then
    return result.err(read_r.err, map_read_code(read_r), read_r.meta)
  end
  local validate_r = project_domain.validate(read_r.value)
  if not validate_r.ok then
    return result.err(validate_r.err, "invalid_graph", { project_id = project_id, path = project_path(project_id) })
  end
  return result.ok(read_r.value)
end

function M.write_project(project)
  if type(project) ~= "table" then return result.err("project must be a table", "invalid_input") end
  local valid = require_valid_id(project.project_id, "project_id")
  if not valid.ok then return valid end
  local validate_r = project_domain.validate(project)
  if not validate_r.ok then return result.err(validate_r.err, validate_r.code or "invalid_input", { project_id = project.project_id }) end
  return json.write(project_path(project.project_id), project)
end

function M.read_workspace(workspace_id)
  local valid = require_valid_id(workspace_id, "workspace_id")
  if not valid.ok then return valid end
  local read_r = json.read(workspace_path(workspace_id))
  if not read_r.ok then
    return result.err(read_r.err, map_read_code(read_r), read_r.meta)
  end
  local validate_r = workspace_domain.validate(read_r.value)
  if not validate_r.ok then
    return result.err(validate_r.err or "invalid workspace graph", "invalid_graph", { workspace_id = workspace_id, path = workspace_path(workspace_id) })
  end
  return result.ok(read_r.value)
end

function M.write_workspace(workspace)
  if type(workspace) ~= "table" then return result.err("workspace must be a table", "invalid_input") end
  local valid = require_valid_id(workspace.workspace_id, "workspace_id")
  if not valid.ok then return valid end
  local validate_r = workspace_domain.validate(workspace)
  if not validate_r.ok then return result.err(validate_r.err or "invalid workspace", "invalid_input", { workspace_id = workspace.workspace_id }) end
  return json.write(workspace_path(workspace.workspace_id), workspace)
end

function M.read_current()
  local read_r = json.read(path.must_graph_path("current.json"))
  if not read_r.ok then
    return result.err(read_r.err, map_read_code(read_r), read_r.meta)
  end
  local validate_r = current_domain.validate(read_r.value)
  if not validate_r.ok then
    return result.err(validate_r.err, "invalid_graph", { path = path.must_graph_path("current.json") })
  end
  return result.ok(read_r.value)
end

function M.write_current(current)
  local validate_r = current_domain.validate(current)
  if not validate_r.ok then
    return result.err(validate_r.err, "invalid_input")
  end
  return json.write(path.must_graph_path("current.json"), current)
end

local function list_graph_dir(rel_dir, read_one)
  local dir = path.must_graph_path(rel_dir)
  local entries, err = fs.readdir_raw(dir)
  if err then return result.err("could not list graph directory: " .. err, "io_read_failed", { path = dir }) end
  table.sort(entries)
  local items = {}
  for _, filename in ipairs(entries) do
    local entity_id = filename:match("^(.*)%.json$")
    if entity_id then
      local r = read_one(entity_id)
      if not r.ok then return r end
      items[#items + 1] = r.value
    end
  end
  return result.ok(items)
end

local function scan_graph_dir_tolerant(rel_dir, read_one)
  local dir = path.must_graph_path(rel_dir)
  local entries, err = fs.readdir_raw(dir)
  if err then return result.err("could not list graph directory: " .. err, "io_read_failed", { path = dir }) end
  table.sort(entries)
  local items, diagnostics = {}, {}
  for _, filename in ipairs(entries) do
    local entity_id = filename:match("^(.*)%.json$")
    if entity_id then
      local r = read_one(entity_id)
      if r.ok then
        items[#items + 1] = r.value
      else
        diagnostics[#diagnostics + 1] = { code = r.code or "invalid_graph", message = r.err, path = path.must_graph_path(rel_dir .. "/" .. filename), entity_id = entity_id }
      end
    end
  end
  return result.ok({ items = items, diagnostics = diagnostics })
end

function M.list_projects_strict() return list_graph_dir("projects", M.read_project) end
function M.list_workspaces_strict() return list_graph_dir("workspaces", M.read_workspace) end
function M.scan_projects_tolerant() return scan_graph_dir_tolerant("projects", M.read_project) end
function M.scan_workspaces_tolerant() return scan_graph_dir_tolerant("workspaces", M.read_workspace) end

function M.list_projects() return M.list_projects_strict() end
function M.list_workspaces() return M.list_workspaces_strict() end
function M.scan_projects() return M.scan_projects_tolerant() end
function M.scan_workspaces() return M.scan_workspaces_tolerant() end

return M
