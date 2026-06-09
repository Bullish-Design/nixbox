local result = require("loci.result")
local async = require("loci.async")

local M = {}
local _available = nil

-- ============================================================================
-- Helpers
-- ============================================================================

local function command_exists(name)
  if vim.in_fast_event() then
    async.schedule()
  end
  return vim.fn.exists(":" .. name) == 2
end

local function exec_command(name)
  if not command_exists(name) then
    return result.err(
      name .. " command is unavailable",
      "integration_unavailable",
      { integration = "wayfinder", command = name }
    )
  end
  if vim.in_fast_event() then
    async.schedule()
  end
  local ok, err = pcall(vim.cmd, name)
  if not ok then
    return result.err(
      name .. " failed: " .. tostring(err),
      "integration_failed",
      { integration = "wayfinder", command = name }
    )
  end
  return result.ok({
    mode = "command",
    command = name,
  })
end

local function get_wayfinder_module()
  local ok, mod = pcall(require, "wayfinder")
  if ok and type(mod) == "table" then
    return mod
  end
  return nil
end

local function direct_trail_api()
  local mod = get_wayfinder_module()
  if not mod then
    return nil
  end
  if type(mod.trail) == "table" then
    return mod.trail
  end
  if type(mod.trails) == "table" then
    return mod.trails
  end
  return nil
end

local function active_trail_name(value)
  if type(value) == "string" then
    return value
  end
  if type(value) ~= "table" then
    return nil
  end
  local wf = value.wayfinder or {}
  local active = wf.active or "main"
  local entry = wf.trails and wf.trails[active]
  return entry and entry.trail_name or nil
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.available()
  if _available == nil then
    local caps = M.capabilities()
    _available = caps.named_load and caps.named_save and caps.named_delete and caps.named_rename
  end
  return _available
end

function M.health()
  local caps = M.capabilities()
  return {
    name = "wayfinder",
    available = M.available(),
    detail = M.available() and "Wayfinder direct named Trail API available" or "Wayfinder named Trail API unavailable",
    capabilities = caps,
  }
end

function M.setup(opts)
  return result.ok({})
end

---Get Wayfinder capabilities.
---@return table
function M.capabilities()
  local api = direct_trail_api()
  return {
    commands = command_exists("WayfinderTrailResume") or command_exists("Wayfinder"),
    named_load = api and type(api.load_named) == "function" or false,
    named_save = api and type(api.save_named) == "function" or false,
    named_delete = api and type(api.delete_named) == "function" or false,
    named_rename = api and type(api.rename) == "function" or false,
    show = command_exists("WayfinderTrailShow"),
    export_quickfix = command_exists("WayfinderExportTrailQuickfix"),
  }
end

---Load a named Trail using the direct API. Returns wayfinder_named_api_unavailable if the
---named API is not available; interactive command fallbacks are not permitted for
---Loci-managed Trail loads.
---@param trail_name string generated Wayfinder Trail name
---@return loci.Result<table>
function M.load_named(trail_name)
  if type(trail_name) ~= "string" or trail_name == "" then
    return result.err("trail_name is required", "invalid_input")
  end

  local api = direct_trail_api()
  if not (api and type(api.load_named) == "function") then
    return result.err(
      "Wayfinder direct named API is unavailable",
      "wayfinder_named_api_unavailable",
      { integration = "wayfinder", trail_name = trail_name }
    )
  end

  local ok, err = pcall(api.load_named, trail_name)
  if not ok then
    return result.err("Wayfinder named Trail load failed: " .. tostring(err), "integration_failed", {
      integration = "wayfinder",
      trail_name = trail_name,
    })
  end
  return result.ok({ action = "load", mode = "direct_api", named = true, trail_name = trail_name })
end

---Save the active Trail.
---@param trail_name_or_workspace string|table generated Trail name or workspace graph
---@param opts? table {save_as = false}
---@return loci.Result<table>
function M.save_active(trail_name_or_workspace, opts)
  opts = opts or {}
  local trail_name = active_trail_name(trail_name_or_workspace)

  if type(trail_name) ~= "string" or trail_name == "" then
    return result.err("trail_name could not be resolved", "invalid_input")
  end

  local api = direct_trail_api()
  if not (api and type(api.save_named) == "function") then
    return result.err(
      "Wayfinder direct named API is unavailable",
      "wayfinder_named_api_unavailable",
      { integration = "wayfinder", trail_name = trail_name }
    )
  end

  local ok, err = pcall(api.save_named, trail_name)
  if not ok then
    return result.err("Wayfinder named Trail save failed: " .. tostring(err), "integration_failed", {
      integration = "wayfinder",
      trail_name = trail_name,
    })
  end
  return result.ok({ action = "save", mode = "direct_api", named = true, trail_name = trail_name })
end

---Resume the last active Trail.
---@param opts? table
---@return loci.Result<table>
function M.resume(opts)
  local r = exec_command("WayfinderTrailResume")
  if not r.ok then
    return r
  end
  return result.ok({
    action = "resume",
    mode = "command",
    command = "WayfinderTrailResume",
  })
end

---Show Trail UI.
---@param opts? table
---@return loci.Result<table>
function M.show(opts)
  local r = exec_command("WayfinderTrailShow")
  if not r.ok then
    return r
  end
  return result.ok({ action = "show", mode = "command", command = "WayfinderTrailShow" })
end

---Delete a named Trail using the direct API. Returns wayfinder_named_api_unavailable if the
---named API is not available; interactive command fallbacks are not permitted for
---Loci-managed Trail deletes.
---@param trail_name string
---@return loci.Result<table>
function M.delete_named(trail_name)
  if type(trail_name) ~= "string" or trail_name == "" then
    return result.err("trail_name is required", "invalid_input")
  end

  local api = direct_trail_api()
  if not (api and type(api.delete_named) == "function") then
    return result.err(
      "Wayfinder direct named API is unavailable",
      "wayfinder_named_api_unavailable",
      { integration = "wayfinder", trail_name = trail_name }
    )
  end

  local ok, err = pcall(api.delete_named, trail_name)
  if not ok then
    return result.err("Wayfinder named Trail delete failed: " .. tostring(err), "integration_failed", {
      integration = "wayfinder",
      trail_name = trail_name,
    })
  end
  return result.ok({ action = "delete", mode = "direct_api", named = true, trail_name = trail_name })
end

---Rename a Trail using the direct API. Returns wayfinder_named_api_unavailable if the
---named API is not available; interactive command fallbacks are not permitted for
---Loci-managed Trail renames.
---@param old_trail_name string
---@param new_trail_name string
---@return loci.Result<table>
function M.rename(old_trail_name, new_trail_name)
  if type(old_trail_name) ~= "string" or old_trail_name == "" then
    return result.err("old_trail_name is required", "invalid_input")
  end
  if type(new_trail_name) ~= "string" or new_trail_name == "" then
    return result.err("new_trail_name is required", "invalid_input")
  end

  local api = direct_trail_api()
  if not (api and type(api.rename) == "function") then
    return result.err(
      "Wayfinder direct named API is unavailable",
      "wayfinder_named_api_unavailable",
      { integration = "wayfinder", old_trail_name = old_trail_name, new_trail_name = new_trail_name }
    )
  end

  local ok, err = pcall(api.rename, old_trail_name, new_trail_name)
  if not ok then
    return result.err("Wayfinder Trail rename failed: " .. tostring(err), "integration_failed", {
      integration = "wayfinder",
      old_trail_name = old_trail_name,
      new_trail_name = new_trail_name,
    })
  end
  return result.ok({
    action = "rename",
    mode = "direct_api",
    named = true,
    old_trail_name = old_trail_name,
    new_trail_name = new_trail_name,
  })
end

---Export Trail to quickfix.
---@param opts? table
---@return loci.Result<table>
function M.export_quickfix(opts)
  local r = exec_command("WayfinderExportTrailQuickfix")
  if not r.ok then
    return r
  end
  return result.ok({ action = "export_quickfix", mode = "command", command = "WayfinderExportTrailQuickfix" })
end

return M
