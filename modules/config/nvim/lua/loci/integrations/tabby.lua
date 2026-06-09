local result = require("loci.result")
local async = require("loci.async")

local M = {}
local _available = nil

-- ============================================================================
-- Helpers
-- ============================================================================

local function tab_exists(tab_id)
  if type(tab_id) ~= "number" then
    return false
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if tab == tab_id then
      return true
    end
  end
  return false
end

local function call_on_main(fn)
  if vim.in_fast_event() then
    async.schedule()
  end
  return pcall(fn)
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.available()
  if _available == nil then
    _available = pcall(require, "tabby")
  end
  return _available
end

function M.health()
  return {
    name = "tabby",
    available = M.available(),
    detail = M.available() and "tabby plugin loaded" or "tabby not available",
  }
end

function M.setup(opts)
  return result.ok({})
end

---Get current tab page ID.
---@return number
function M.current_tab_id()
  return vim.api.nvim_get_current_tabpage()
end

---Activate workspace with cached tab or create new tab.
---@param workspace table workspace graph
---@return loci.Result<table>
function M.activate_workspace(workspace)
  local cached = workspace.tabby and workspace.tabby.tab_id_cache

  -- Try to use cached tab if it exists
  if cached ~= nil and cached ~= vim.NIL and tab_exists(cached) then
    local ok, err = call_on_main(function()
      vim.api.nvim_set_current_tabpage(cached)
    end)
    if not ok then
      return result.err("Failed to switch tab: " .. tostring(err), "command_failed", { tab_id = cached })
    end
    return result.ok({
      mode = "cached_tab",
      tab_id = cached,
    })
  end

  -- Create new native tab
  local ok, err = call_on_main(function()
    vim.cmd.tabnew()
  end)
  if not ok then
    return result.err("Failed to create tab: " .. tostring(err), "command_failed")
  end
  local tab_id = M.current_tab_id()

  local mode = M.available() and "tabby_fallback" or "native_tab"
  return result.ok({
    mode = mode,
    tab_id = tab_id,
  })
end

return M
