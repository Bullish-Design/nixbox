local result = require("loci.result")
local path = require("loci.store.path")
local fs = require("loci.store.fs")
local config = require("loci.config")

local M = {}
local _available = nil

-- ============================================================================
-- Availability and Health
-- ============================================================================

---Check if obsidian.nvim is available
function M.available()
  if _available == nil then
    _available = pcall(require, "obsidian")
  end
  return _available
end

---Get health status of obsidian integration
function M.health()
  return {
    name = "obsidian",
    available = M.available(),
    detail = M.available() and "obsidian.nvim loaded" or "obsidian.nvim not loaded; filesystem bridge can still work",
  }
end

function M.setup(opts)
  return M.ensure_content_symlink(opts)
end

-- ============================================================================
-- Path Validation Helpers
-- ============================================================================

local function expand_home(value)
  if type(value) ~= "string" then
    return value
  end
  if value == "~" then
    return vim.uv.os_homedir()
  end
  return (value:gsub("^~/", vim.uv.os_homedir() .. "/"))
end

local function contains_null(value)
  return type(value) == "string" and value:match("%z") ~= nil
end

local function is_plain_segment(value)
  return type(value) == "string"
    and value ~= ""
    and not value:match("%z")
    and not value:match("[/\\]")
    and value ~= "."
    and value ~= ".."
end

local function is_safe_relative_path(value)
  return type(value) == "string"
    and value ~= ""
    and not value:match("^/")
    and not value:match("%z")
    and not value:match("\\")
    and not value:match("%.%.")
end

---Normalize a path for comparison
function M._normalize_path(abs_path)
  if not abs_path then
    return nil
  end
  return vim.fs.normalize(abs_path)
end

-- ============================================================================
-- Path Computation
-- ============================================================================

---Compute and validate vault paths
---@param opts? table
---@return loci.Result
function M.paths(opts)
  opts = opts or {}
  local cfg = opts.config or config.get()
  local ob = (cfg.integrations and cfg.integrations.obsidian) or {}

  -- Check if Obsidian integration is disabled
  if ob.enabled == false then
    return result.ok({
      enabled = false,
      configured = false,
      status = "disabled",
    })
  end

  -- Get vault paths from integrations.obsidian
  local vault_path = expand_home(ob.vault_path)
  local project_path = ob.project_path
  local symlink_name = ob.symlink_name or "loci"

  -- Validate required config
  if type(vault_path) ~= "string" or vault_path == "" or type(project_path) ~= "string" or project_path == "" then
    return result.ok({
      enabled = true,
      configured = false,
      status = "not_configured",
      reason = "integrations.obsidian.vault_path and integrations.obsidian.project_path are required",
    })
  end

  -- Validate vault_path
  if contains_null(vault_path) then
    return result.err("integrations.obsidian.vault_path contains a null byte", "invalid_input", { value = vault_path })
  end

  -- Validate project_path
  if not is_safe_relative_path(project_path) then
    return result.err("integrations.obsidian.project_path must be a safe relative path", "invalid_input", { value = project_path })
  end

  -- Validate symlink_name
  if not is_plain_segment(symlink_name) then
    return result.err("integrations.obsidian.symlink_name must be a single path segment", "invalid_input", { value = symlink_name })
  end

  -- Compute normalized paths
  local vault_root = vim.fs.normalize(vault_path)
  local vault_project = vim.fs.normalize(vault_root .. "/" .. project_path)
  local link_path = vim.fs.normalize(vault_project .. "/" .. symlink_name)
  local target = vim.fs.normalize(path.must_content_path())

  return result.ok({
    enabled = true,
    configured = true,
    vault_root = vault_root,
    vault_project = vault_project,
    link_path = link_path,
    target = target,
    symlink_name = symlink_name,
  })
end

-- ============================================================================
-- Symlink Inspection
-- ============================================================================

local function readlink(link_path)
  local ok, target_or_err = pcall(vim.uv.fs_readlink, link_path)
  if not ok then
    return nil, target_or_err
  end
  return target_or_err, nil
end

local function normalize_existing_target(link_path, raw_target)
  if type(raw_target) ~= "string" then
    return nil
  end
  if raw_target:match("^/") then
    return vim.fs.normalize(raw_target)
  end
  local parent = vim.fs.dirname(link_path)
  return vim.fs.normalize(parent .. "/" .. raw_target)
end

---Inspect an existing symlink
---@param opts? table
---@return loci.Result
function M.inspect_content_symlink(opts)
  opts = opts or {}
  local p = opts.paths or {}

  if not p.link_path or not p.target then
    local paths_r = M.paths(opts)
    if not paths_r.ok then
      return paths_r
    end
    p = paths_r.value
    if not p.configured then
      return result.ok({
        enabled = p.enabled,
        configured = false,
        exists = false,
      })
    end
  end

  local stat = vim.uv.fs_lstat(p.link_path)

  if not stat then
    return result.ok({
      exists = false,
      is_symlink = false,
      correct = false,
      link_path = p.link_path,
      target = p.target,
    })
  end

  if stat.type == "link" then
    local raw_target, err = readlink(p.link_path)
    if err then
      return result.err("could not read symlink target: " .. tostring(err), "io_read_failed", {
        link_path = p.link_path,
      })
    end

    local actual_target = normalize_existing_target(p.link_path, raw_target)
    local correct = actual_target == vim.fs.normalize(p.target)

    return result.ok({
      exists = true,
      is_symlink = true,
      correct = correct,
      link_path = p.link_path,
      target = p.target,
      actual_target = actual_target,
    })
  else
    -- Non-symlink file or directory
    return result.ok({
      exists = true,
      is_symlink = false,
      correct = false,
      link_path = p.link_path,
      target = p.target,
      kind = stat.type,
    })
  end
end

-- ============================================================================
-- Symlink Creation
-- ============================================================================

---Ensure the Obsidian vault symlink exists and points correctly
---@param opts? table
---@return loci.Result
function M.ensure_content_symlink(opts)
  opts = opts or {}

  -- Compute paths
  local paths_r = M.paths(opts)
  if not paths_r.ok then
    return paths_r
  end

  local p = paths_r.value

  -- Return skipped if disabled or not configured
  if p.enabled == false or p.configured == false then
    return result.ok(vim.tbl_extend("force", p, {
      created = false,
    }))
  end

  -- Verify target exists
  local target_stat = vim.uv.fs_stat(p.target)
  if not target_stat or target_stat.type ~= "directory" then
    return result.err("LOCI content target does not exist: " .. p.target, "not_found", { target = p.target })
  end

  -- Create parent directories
  local mkdir_r = fs.mkdir_p(p.vault_project)
  if not mkdir_r.ok then
    return mkdir_r
  end

  -- Inspect existing symlink
  local inspect_r = M.inspect_content_symlink({ paths = p })
  if not inspect_r.ok then
    return inspect_r
  end

  local inspect = inspect_r.value

  -- Check if symlink already exists correctly
  if inspect.exists and inspect.correct then
    return result.ok(vim.tbl_extend("force", p, {
      created = false,
      existed = true,
      status = "ok",
    }))
  end

  -- Check for conflicts
  if inspect.exists then
    return result.err(
      "Obsidian vault link path already exists and does not point to LOCI content",
      "conflict",
      {
        link_path = p.link_path,
        expected_target = p.target,
        actual_target = inspect.actual_target,
        kind = inspect.kind,
      }
    )
  end

  -- Create the symlink
  local ok, symlink_err = pcall(vim.uv.fs_symlink, p.target, p.link_path)
  if not ok then
    return result.err(
      "could not create Obsidian vault symlink: " .. tostring(symlink_err),
      "io_write_failed",
      {
        link_path = p.link_path,
        target = p.target,
      }
    )
  end

  if type(symlink_err) == "string" and symlink_err ~= "" then
    return result.err(
      "could not create Obsidian vault symlink: " .. tostring(symlink_err),
      "io_write_failed",
      {
        link_path = p.link_path,
        target = p.target,
      }
    )
  end

  return result.ok(vim.tbl_extend("force", p, {
    created = true,
    existed = false,
    status = "created",
  }))
end

return M
