local result = require("loci.result")

local M = {}
local _available = nil

-- ============================================================================
-- Helpers
-- ============================================================================

local function get_resession()
  local ok, mod = pcall(require, "resession")
  if not ok then
    return nil
  end
  return mod
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.available()
  if _available == nil then
    _available = get_resession() ~= nil
  end
  return _available
end

function M.health()
  return {
    name = "resession",
    available = M.available(),
    detail = M.available() and "resession plugin loaded" or "resession not available",
  }
end

function M.setup(opts)
  return result.ok({})
end

---Load session for workspace.
---@param workspace table workspace graph
---@return loci.Result<table>
function M.load_session(workspace)
  local resession = get_resession()
  if not resession then
    return result.err(
      "Resession is not available",
      "integration_unavailable",
      { integration = "resession" }
    )
  end

  local name = workspace.resession and workspace.resession.session_name
  if not name or name == "" then
    return result.ok({
      loaded = false,
      reason = "missing session name",
    })
  end

  -- Prefer tab-scoped API if available
  local load_fn = resession.load
  if type(resession.load_tab) == "function" then
    load_fn = resession.load_tab
  end

  local ok, err = pcall(load_fn, name, { dir = "session", silence_errors = true })
  if not ok then
    return result.err(
      "Resession load failed: " .. tostring(err),
      "integration_failed",
      { integration = "resession", session_name = name }
    )
  end

  return result.ok({
    loaded = true,
    session_name = name,
  })
end

---Save session for workspace.
---@param workspace table workspace graph
---@return loci.Result<table>
function M.save_session(workspace)
  local resession = get_resession()
  if not resession then
    return result.err(
      "Resession is not available",
      "integration_unavailable",
      { integration = "resession" }
    )
  end

  local name = workspace.resession and workspace.resession.session_name
  if not name or name == "" then
    return result.ok({
      saved = false,
      reason = "missing session name",
    })
  end

  -- Prefer tab-scoped API if available
  local save_fn = resession.save
  if type(resession.save_tab) == "function" then
    save_fn = resession.save_tab
  end

  local ok, err = pcall(save_fn, name, { dir = "session", notify = false })
  if not ok then
    return result.err(
      "Resession save failed: " .. tostring(err),
      "integration_failed",
      { integration = "resession", session_name = name }
    )
  end

  return result.ok({
    saved = true,
    session_name = name,
  })
end

return M
