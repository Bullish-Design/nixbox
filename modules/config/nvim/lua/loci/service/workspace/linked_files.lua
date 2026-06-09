local result = require("loci.result")
local tx = require("loci.service.workspace.tx")
local path = require("loci.store.path")

local M = {}

local function normalize_slashes(value)
  return value:gsub("\\", "/")
end

local function reject_unsafe_rel(rel)
  if rel == nil or rel == "" then
    return "path is required"
  end
  if rel:match("%z") then
    return "path contains null byte"
  end
  if rel:match("^/") or rel:match("^%a:[/\\]") then
    return "stored linked file path must be repository-relative"
  end
  for part in rel:gmatch("[^/]+") do
    if part == ".." then
      return "path traversal is not allowed"
    end
  end
  return nil
end

local function entry_from_path(path_input, opts)
  opts = opts or {}

  if not path_input or path_input == "" then
    return result.err("path is required", "invalid_input")
  end

  local rel_path
  if path_input:match("^/") or path_input:match("^%a:[/\\]") then
    rel_path = path.relative(path_input)
    if not rel_path then
      return result.err("file is outside repository root", "invalid_input")
    end
  else
    rel_path = path_input
  end

  rel_path = normalize_slashes(rel_path)
  local err = reject_unsafe_rel(rel_path)
  if err then
    return result.err(err, "invalid_input")
  end

  if rel_path:match("^%.loci/content/") then
    return result.err("linked files cannot be Markdown under .loci/content/; use knowledge association instead", "invalid_input")
  end

  return result.ok({ path = rel_path, role = opts.role or "reference" })
end

local function add_entry(list, entry)
  if not list or type(list) ~= "table" then
    list = {}
  end
  local found_idx = nil
  for i, item in ipairs(list) do
    if item.path == entry.path then
      found_idx = i
      break
    end
  end
  if found_idx then
    list[found_idx].role = entry.role
  else
    table.insert(list, entry)
  end
  return result.ok(list)
end

local function remove_entry(list, path_input)
  if not list or type(list) ~= "table" then
    list = {}
  end
  if not path_input or path_input == "" then
    return result.err("path is required", "invalid_input")
  end

  local rel_path
  if path_input:match("^/") or path_input:match("^%a:[/\\]") then
    rel_path = path.relative(path_input)
  else
    rel_path = path_input
  end
  if not rel_path then
    return result.err("path is not under repository root", "invalid_input")
  end
  rel_path = normalize_slashes(rel_path)

  local found = false
  for i = #list, 1, -1 do
    if list[i].path == rel_path then
      table.remove(list, i)
      found = true
      break
    end
  end
  if not found then
    return result.err("linked file not found: " .. rel_path, "not_found")
  end
  return result.ok(list)
end

-- ============================================================================
-- Public API: linked files
-- ============================================================================

---@async
---@param workspace_id string
---@param opts? table
---@return loci.Result<table>
function M.link_current_file(workspace_id, opts)
  opts = opts or {}

  if not opts.path or opts.path == "" then
    return result.err("path is required", "invalid_input")
  end

  local entry_r = entry_from_path(opts.path, opts)
  if not entry_r.ok then
    return entry_r
  end

  local entry = entry_r.value

  local update_r = tx.update(workspace_id, function(workspace)
    local add_r = add_entry(workspace.linked_files, entry)
    if not add_r.ok then
      return add_r
    end

    workspace.linked_files = add_r.value

    return result.ok(workspace)
  end)
  if not update_r.ok then
    return update_r
  end
  return result.ok(update_r.value.workspace)
end

---@async
---@param workspace_id string
---@param path_or_opts? string|table
---@return loci.Result<table>
function M.unlink_current_file(workspace_id, path_or_opts)
  local opts = {}
  local target_path = nil

  if type(path_or_opts) == "string" then
    target_path = path_or_opts
  elseif type(path_or_opts) == "table" then
    opts = path_or_opts
    target_path = opts.path
  end

  if not target_path or target_path == "" then
    return result.err("path is required", "invalid_input")
  end

  local update_r = tx.update(workspace_id, function(workspace)
    local remove_r = remove_entry(workspace.linked_files, target_path)
    if not remove_r.ok then
      return remove_r
    end

    workspace.linked_files = remove_r.value

    return result.ok(workspace)
  end)
  if not update_r.ok then
    return update_r
  end
  return result.ok(update_r.value.workspace)
end

return M
