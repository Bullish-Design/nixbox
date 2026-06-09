local function should_persist_buffer(bufnr)
  local buftype = vim.bo[bufnr].buftype
  if buftype == "help" then return true end
  if buftype ~= "" and buftype ~= "acwrite" then return false end
  if vim.api.nvim_buf_get_name(bufnr) == "" then return false end
  return vim.bo[bufnr].buflisted
end

require("resession").setup({
  autosave = {
    enabled = true,
    interval = 120,
    notify = false,
  },
  buf_filter = function(bufnr)
    return should_persist_buffer(bufnr)
  end,
  -- Tab-scoped sessions should not persist plugin UI buffers like NeogitStatus.
  tab_buf_filter = function(_tabpage, bufnr)
    return should_persist_buffer(bufnr)
  end,
  extensions = {
    quickfix = {},
  },
})

local resession = require("resession")

-- ── Hooks ──────────────────────────────────────────────────────────────────────

resession.add_hook("pre_save", function()
  -- Persist sidequest state across sessions
  local issue = require("sidequest.issue")
  local data = issue.load()
  vim.g.sidequest_active_issue = data.active_issue
end)

resession.add_hook("post_save", function()
  local sq = require("sidequest")
  local sidebar = require("sidequest.sidebar")
  if sidebar.is_open() then
    sq.refresh()
  end
end)

resession.add_hook("post_load", function()
  -- Restore sidequest state
  if vim.g.sidequest_active_issue then
    local issue = require("sidequest.issue")
    local data = issue.load()
    data.active_issue = vim.g.sidequest_active_issue
    issue.save(data)
  end

  -- Refresh sidequest sidebar if open
  local sq = require("sidequest")
  local sidebar = require("sidequest.sidebar")
  if sidebar.is_open() then
    vim.defer_fn(function() sq.refresh() end, 100)
  end

  -- Force tabline redraw so Tabby picks up restored tab names
  vim.defer_fn(function() vim.cmd.redrawtabline() end, 50)
end)

-- ── Auto-save on exit ──────────────────────────────────────────────────────────

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    resession.save_all({ notify = false })
  end,
})

-- ── Session helpers ────────────────────────────────────────────────────────────

local M = {}

--- Save the current tabpage as a tab-scoped workspace session.
--- Uses the Tabby tab name as the default session name.
function M.save_workspace()
  local name = nil
  local ok, tab_name_mod = pcall(require, "tabby.feature.tab_name")
  if ok then
    local api = require("tabby.module.api")
    local raw = tab_name_mod.get_raw(api.get_current_tab())
    if raw ~= "" then
      name = raw
    end
  end
  resession.save_tab(name, { dir = "workspace" })
end

--- Load a tab-scoped workspace session into the current tabpage.
function M.load_workspace()
  resession.load(nil, { dir = "workspace" })
end

--- Delete a saved workspace session.
function M.delete_workspace()
  resession.delete(nil, { dir = "workspace" })
end

return M
