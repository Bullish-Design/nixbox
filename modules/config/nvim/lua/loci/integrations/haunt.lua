local result = require("loci.result")
local fs = require("loci.store.fs")
local path_store = require("loci.store.path")
local id = require("loci.domain.id")

local M = {}
local _available = nil

-- ============================================================================
-- Helpers
-- ============================================================================

local function get_haunt_api()
  local ok, mod = pcall(require, "haunt.api")
  if not ok then
    return nil
  end
  return mod
end

local function is_valid_context_name(name)
  if type(name) ~= "string" or name == "" or #name > 64 then
    return false
  end
  if name:match("[^a-z0-9%-]") then
    return false
  end
  if name:match("^%-") or name:match("%-$") then
    return false
  end
  return true
end

function M.validate_context_name(name)
  if not is_valid_context_name(name) then
    return result.err("invalid haunt context name: " .. tostring(name), "invalid_input")
  end
  return result.ok(name)
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.available()
  if _available == nil then
    _available = get_haunt_api() ~= nil
  end
  return _available
end

function M.reset_for_tests()
  _available = nil
end

function M.health()
  return {
    name = "haunt",
    available = M.available(),
    detail = M.available() and "haunt plugin loaded" or "haunt not available",
  }
end

function M.setup(opts)
  return result.ok({})
end

---Ensure Haunt context directory exists.
---@param data_dir string relative .loci/integrations/haunt/... path
---@return loci.Result
function M.ensure_context_dir(data_dir)
  local abs_r = M.abs_context_dir(data_dir)
  if not abs_r.ok then
    return abs_r
  end
  return fs.mkdir_p(abs_r.value)
end

---Change Haunt active data directory.
---@param data_dir string absolute path
---@return loci.Result
function M.change_data_dir(data_dir)
  local haunt = get_haunt_api()
  if not haunt then
    return result.err(
      "Haunt is not available",
      "integration_unavailable",
      { integration = "haunt" }
    )
  end

  local ok, changed_or_err = pcall(haunt.change_data_dir, data_dir)
  if not ok then
    return result.err(
      "Haunt change_data_dir failed: " .. tostring(changed_or_err),
      "integration_failed",
      { integration = "haunt", data_dir = data_dir }
    )
  end

  if changed_or_err == false then
    return result.err(
      "Haunt change_data_dir returned false",
      "integration_failed",
      { integration = "haunt", data_dir = data_dir }
    )
  end

  return result.ok({
    changed = true,
    data_dir = data_dir,
  })
end

---Get canonical relative path for a Haunt context.
---@param workspace_id string
---@param context_name string
---@return loci.Result<string>
function M.context_data_dir(workspace_id, context_name)
  if not id.is_valid(workspace_id) then
    return result.err("invalid workspace_id: " .. tostring(workspace_id), "invalid_input")
  end
  local name_r = M.validate_context_name(context_name)
  if not name_r.ok then
    return name_r
  end
  return result.ok(".loci/integrations/haunt/workspaces/" .. workspace_id .. "/" .. context_name)
end

---Convert relative data_dir to absolute path.
---@param data_dir string relative .loci/integrations/haunt/workspaces/... path
---@return loci.Result<string>
function M.abs_context_dir(data_dir)
  if type(data_dir) ~= "string" or data_dir == "" then
    return result.err("haunt data_dir is required", "invalid_input")
  end
  if data_dir:match("%z") or data_dir:match("\\") or data_dir:match("%.%.") then
    return result.err("unsafe haunt data_dir: " .. data_dir, "invalid_input", { data_dir = data_dir })
  end
  if not data_dir:match("^%.loci/integrations/haunt/workspaces/") then
    return result.err(
      "haunt data_dir must be under .loci/integrations/haunt/workspaces",
      "invalid_input",
      { data_dir = data_dir }
    )
  end
  return result.ok(path_store.loci_root() .. "/" .. data_dir:gsub("^%.loci/", ""))
end

---Get shallow directory information for a context.
---@param data_dir string relative .loci/integrations/haunt/workspaces/... path
---@return loci.Result<table>
function M.context_dir_info(data_dir)
  local abs_r = M.abs_context_dir(data_dir)
  if not abs_r.ok then
    return abs_r
  end

  local abs_dir = abs_r.value
  local stat_r = fs.stat(abs_dir)

  if not stat_r.ok then
    -- Missing directory is not an error
    return result.ok({
      data_dir = data_dir,
      abs_data_dir = abs_dir,
      exists = false,
      is_dir = false,
      non_empty = false,
      file_count = 0,
    })
  end

  local stat = stat_r.value
  if stat.type ~= "directory" then
    return result.err("haunt data_dir exists but is not a directory: " .. abs_dir, "conflict", {
      data_dir = data_dir,
      path = abs_dir,
    })
  end

  -- Read directory to count files
  local entries_r = fs.readdir(abs_dir)
  local file_count = 0
  if entries_r.ok then
    file_count = #entries_r.value
  end

  return result.ok({
    data_dir = data_dir,
    abs_data_dir = abs_dir,
    exists = true,
    is_dir = true,
    non_empty = file_count > 0,
    file_count = file_count,
  })
end

---Check if a data_dir is canonical for a workspace/context pair.
---@param workspace_id string
---@param context_name string
---@param data_dir string
---@return boolean
function M.is_canonical_context_dir(workspace_id, context_name, data_dir)
  local canonical_r = M.context_data_dir(workspace_id, context_name)
  if not canonical_r.ok then
    return false
  end
  return canonical_r.value == data_dir
end

---Move a context directory for rename.
---@param old_data_dir string relative path
---@param new_data_dir string relative path
---@param opts? table {allow_existing_empty=boolean}
---@return loci.Result<table>
function M.move_context_dir(old_data_dir, new_data_dir, opts)
  opts = opts or {}

  local old_abs_r = M.abs_context_dir(old_data_dir)
  if not old_abs_r.ok then
    return old_abs_r
  end

  local new_abs_r = M.abs_context_dir(new_data_dir)
  if not new_abs_r.ok then
    return new_abs_r
  end

  local old_abs = old_abs_r.value
  local new_abs = new_abs_r.value

  -- Check old directory
  local old_info_r = M.context_dir_info(old_data_dir)
  if not old_info_r.ok then
    return old_info_r
  end

  local old_info = old_info_r.value

  -- If old directory doesn't exist, ensure new parent and create new directory
  if not old_info.exists then
    local parent = new_abs:match("^(.*/)[^/]+/?$") or ""
    if parent ~= "" then
      local mkdir_r = fs.mkdir_p(parent)
      if not mkdir_r.ok then
        return mkdir_r
      end
    end
    local mkdir_r = fs.mkdir_p(new_abs)
    if not mkdir_r.ok then
      return mkdir_r
    end
    return result.ok({
      moved = false,
      created = true,
      old_data_dir = old_data_dir,
      old_abs_data_dir = old_abs,
      new_data_dir = new_data_dir,
      new_abs_data_dir = new_abs,
    })
  end

  -- Check new directory
  local new_info_r = M.context_dir_info(new_data_dir)
  if not new_info_r.ok then
    return new_info_r
  end

  local new_info = new_info_r.value
  if new_info.exists then
    if not (opts.allow_existing_empty and new_info.file_count == 0) then
      return result.err("target haunt context directory already exists", "conflict", {
        old_data_dir = old_data_dir,
        new_data_dir = new_data_dir,
        new_exists = true,
      })
    end
  end

  -- Ensure parent of new directory exists
  local parent = new_abs:match("^(.*/)[^/]+/?$") or ""
  if parent ~= "" then
    local mkdir_r = fs.mkdir_p(parent)
    if not mkdir_r.ok then
      return mkdir_r
    end
  end

  -- Move the directory
  local rename_r = fs.rename(old_abs, new_abs)
  if not rename_r.ok then
    return result.err("failed to move haunt context directory: " .. tostring(rename_r.err), "io_write_failed", {
      old_data_dir = old_data_dir,
      new_data_dir = new_data_dir,
      error = rename_r.err,
    })
  end

  return result.ok({
    moved = true,
    created = false,
    old_data_dir = old_data_dir,
    old_abs_data_dir = old_abs,
    new_data_dir = new_data_dir,
    new_abs_data_dir = new_abs,
  })
end

---Delete a context directory with optional confirmation.
---@param data_dir string relative path
---@param opts? table {confirm=boolean, keep_data=boolean, missing_ok=boolean}
---@return loci.Result<table>
function M.delete_context_dir(data_dir, opts)
  opts = opts or {}
  if opts.missing_ok == nil then
    opts.missing_ok = true
  end

  local abs_r = M.abs_context_dir(data_dir)
  if not abs_r.ok then
    return abs_r
  end

  local abs_dir = abs_r.value

  -- Check if keeping data
  if opts.keep_data == true then
    return result.ok({
      deleted = false,
      kept = true,
      data_dir = data_dir,
    })
  end

  -- Get directory info
  local info_r = M.context_dir_info(data_dir)
  if not info_r.ok then
    return info_r
  end

  local info = info_r.value

  -- If missing, return ok if missing_ok
  if not info.exists then
    if opts.missing_ok then
      return result.ok({
        deleted = false,
        missing = true,
        data_dir = data_dir,
      })
    else
      return result.err("haunt context directory not found: " .. data_dir, "not_found", {
        data_dir = data_dir,
      })
    end
  end

  -- If non-empty and not confirmed, return conflict
  if info.non_empty and opts.confirm ~= true then
    return result.err("haunt context directory is non-empty", "conflict", {
      data_dir = data_dir,
      requires_confirmation = true,
      file_count = info.file_count,
    })
  end

  -- Delete the directory recursively
  local rm_r = M._rm_rf(abs_dir)
  if not rm_r.ok then
    return rm_r
  end

  return result.ok({
    deleted = true,
    data_dir = data_dir,
  })
end

---Recursive delete helper (private).
---@private
function M._rm_rf(abs_path)
  local stat_r = fs.stat(abs_path)
  if not stat_r.ok then
    return result.ok({ deleted = false, missing = true })
  end

  local stat = stat_r.value
  if stat.type == "file" then
    local unlink_r = fs.unlink(abs_path)
    if not unlink_r.ok then
      return unlink_r
    end
    return result.ok({ deleted = true })
  end

  if stat.type ~= "directory" then
    return result.err("cannot delete non-file/non-directory: " .. abs_path, "invalid_input", { path = abs_path })
  end

  local entries_r = fs.readdir(abs_path)
  if not entries_r.ok then
    return result.err("could not read directory: " .. entries_r.err, "io_read_failed", { path = abs_path })
  end

  for _, entry in ipairs(entries_r.value) do
    local child_r = M._rm_rf(abs_path .. "/" .. entry.name)
    if not child_r.ok then
      return child_r
    end
  end

  local rmdir_r = fs.rmdir(abs_path)
  if not rmdir_r.ok then
    return result.err("rmdir failed: " .. tostring(rmdir_r.err), "io_write_failed", { path = abs_path })
  end

  return result.ok({ deleted = true, path = abs_path })
end

---Activate workspace by switching Haunt context.
---@param workspace table workspace graph
---@return loci.Result<table>
function M.activate_workspace(workspace)
  -- Check for haunt config
  if not workspace.haunt or not workspace.haunt.active then
    return result.ok({
      changed = false,
      reason = "missing haunt config",
    })
  end

  local active_context = workspace.haunt.contexts[workspace.haunt.active]
  if not active_context then
    return result.err(
      "Active haunt context not found: " .. workspace.haunt.active,
      "integration_failed",
      { integration = "haunt", active = workspace.haunt.active }
    )
  end

  if not active_context.data_dir then
    return result.err(
      "Haunt context missing data_dir",
      "integration_failed",
      { integration = "haunt", active = workspace.haunt.active }
    )
  end

  local abs_r = M.abs_context_dir(active_context.data_dir)
  if not abs_r.ok then
    return abs_r
  end
  local abs_dir = abs_r.value

  -- Ensure directory exists
  local ensure_r = fs.mkdir_p(abs_dir)
  if not ensure_r.ok then
    return ensure_r
  end

  -- Change Haunt data directory
  local change_r = M.change_data_dir(abs_dir)
  if not change_r.ok then
    -- Haunt unavailable is a soft failure
    if change_r.code == "integration_unavailable" then
      return result.ok({
        changed = false,
        reason = "haunt not available",
      })
    end
    return change_r
  end

  return result.ok({
    changed = true,
    data_dir = abs_dir,
  })
end

return M
