local M = {}
local config = {}
function M.get_config() return config end

local default_config = {
  sidebar = { width = 42, filetype = "sidequest", focus_on_open = true, restore_focus_on_close = true },
  keymaps = {
    strict = true,
    nowait = true,
    block_global_prefixes = true,
    reserved = { q = "close", ["<Esc>"] = "back_or_close", ["<BS>"] = "back", h = "home", r = "refresh", ["?"] = "help" },
    blocked_prefixes = { "<leader>", "g", "z", "[", "]" },
  },
  context = { providers = { "cwd", "project_root", "git", "lsp", "diagnostics", "buffers", "sessions" } },
  trees = {},
  default_tree = "workspace",
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})
  if not config.trees.workspace then config.trees.workspace = require("sidequest.pages.workspace") end
  local s = require("sidequest.state").get()
  for name, tree_def in pairs(config.trees) do if not s.stacks[name] then s.stacks[name] = { tree_def.root or "overview" } end end
  s.active_tree = config.default_tree
  s.initialized = true
  vim.api.nvim_create_user_command("Sidequest", function() M.toggle() end, { desc = "Sidequest: toggle" })
  vim.api.nvim_create_user_command("SidequestOpen", function() M.open() end, { desc = "Sidequest: open" })
  vim.api.nvim_create_user_command("SidequestClose", function() M.close() end, { desc = "Sidequest: close" })
  vim.api.nvim_create_user_command("SidequestRefresh", function() M.refresh() end, { desc = "Sidequest: refresh" })
  vim.api.nvim_create_user_command("SidequestTree", function(cmd) M.open_tree(cmd.args) end, { nargs = 1, desc = "Sidequest: switch tree" })
  vim.api.nvim_create_user_command("SidequestKeymaps", function() M.show_keymaps() end, { desc = "Sidequest: show keymaps" })

  -- <localleader> discoverable layer for the sidequest sidebar buffer.
  -- The existing single-char keys remain as-is; localleader versions add
  -- discoverability and appear in <leader>? (which-key buffer-local view).
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("SidequestLocalleader", { clear = true }),
    pattern = config.sidebar.filetype,
    callback = function(event)
      local wk = require("which-key")
      local buf = event.buf
      wk.add({
        { "<localleader>",  group = "Sidequest",                                                              buffer = buf },
        { "<localleader>q", function() M.close() end,                                                        desc = "Close",         buffer = buf },
        { "<localleader>h", function() M.home() end,                                                         desc = "Home page",     buffer = buf },
        { "<localleader>r", function() M.refresh() end,                                                      desc = "Refresh",       buffer = buf },
        { "<localleader>?", "<cmd>SidequestKeymaps<cr>",                                                     desc = "Help/keymaps",  buffer = buf },
        { "<localleader>g", function() M.open_tree("git", { focus = true }) end,                             desc = "Git page",      buffer = buf },
        { "<localleader>s", function() M.open_tree("sessions", { focus = true }) end,                        desc = "Sessions page", buffer = buf },
      })
    end,
  })
end

function M.open(opts)
  opts = opts or {}
  local sidebar = require("sidequest.sidebar")
  if not sidebar.is_open() then sidebar.open({ focus = opts.focus ~= false }) elseif opts.focus ~= false then sidebar.focus() end
  M._render()
end
function M.close() require("sidequest.sidebar").close() end
function M.toggle(opts) if require("sidequest.sidebar").is_open() then M.close() else M.open(opts or {}) end end
function M.focus() require("sidequest.sidebar").focus() end
function M.refresh() M._render() end

function M.open_tree(name, opts)
  local state_mod = require("sidequest.state")
  local s = state_mod.get()
  if not config.trees[name] then vim.notify("Sidequest: unknown tree '" .. name .. "'", vim.log.levels.WARN); return end
  s.active_tree = name
  if not s.stacks[name] then s.stacks[name] = { config.trees[name].root or "overview" } end
  local tree = config.trees[name]
  if tree and tree.tabs and #tree.tabs > 0 and not state_mod.current_tab() then
    state_mod.switch_tab(tree.tabs[1].id)
  end
  M.open(opts or {})
end

function M.go(page) require("sidequest.state").push_page(page); M._render() end
function M.back() if require("sidequest.state").pop_page() then M._render(); return true end return false end
function M.home() local st = require("sidequest.state"); st.reset_stack(st.get().active_tree); M._render() end
function M.switch_tab(id) require("sidequest.state").switch_tab(id); M._render() end
function M.next_tab()
  local state_mod = require("sidequest.state")
  local s = state_mod.get()
  local tree_def = config.trees[s.active_tree]
  if not tree_def or not tree_def.tabs then return end
  local current = s.tabs[s.active_tree]
  for i, tab in ipairs(tree_def.tabs) do
    if tab.id == current then
      local next_idx = (i % #tree_def.tabs) + 1
      M.switch_tab(tree_def.tabs[next_idx].id)
      return
    end
  end
end
function M.prev_tab()
  local state_mod = require("sidequest.state")
  local s = state_mod.get()
  local tree_def = config.trees[s.active_tree]
  if not tree_def or not tree_def.tabs then return end
  local current = s.tabs[s.active_tree]
  for i, tab in ipairs(tree_def.tabs) do
    if tab.id == current then
      local prev_idx = ((i - 2) % #tree_def.tabs) + 1
      M.switch_tab(tree_def.tabs[prev_idx].id)
      return
    end
  end
end

function M.show_keymaps()
  local state = require("sidequest.state").get()
  local lines = { "Sidequest keymaps for buffer " .. (state.buf or "nil"), "", "Tree: " .. state.active_tree, "Page: " .. require("sidequest.state").current_page(), "Strict mode: " .. tostring(config.keymaps.strict), "", "Owned mappings:" }
  for _, m in ipairs(state.active_keymaps or {}) do table.insert(lines, string.format("  %-12s %s", m.lhs, m.desc or "")) end
  if config.keymaps.blocked_prefixes then table.insert(lines, ""); table.insert(lines, "Blocked prefixes:"); table.insert(lines, "  " .. table.concat(config.keymaps.blocked_prefixes, "  ")) end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M._render()
  local s = require("sidequest.state").get()
  local buf = require("sidequest.sidebar").ensure_buf()
  local ctx = require("sidequest.context").gather(config.context.providers)
  s.ctx = ctx
  s.ctx_version = s.ctx_version + 1
  local tree_def = config.trees[s.active_tree]
  if not tree_def then return end
  local state_mod = require("sidequest.state")
  local page_name = state_mod.current_page()
  local page
  if tree_def.tabs then
    local active_tab = state_mod.current_tab()
    if active_tab and tree_def.tab_pages and tree_def.tab_pages[active_tab] then
      page = tree_def.tab_pages[active_tab][page_name]
    end
  end
  if not page then page = tree_def.pages and tree_def.pages[page_name] end
  if not page then vim.notify("Sidequest: page '" .. page_name .. "' not found in tree '" .. s.active_tree .. "'", vim.log.levels.WARN); return end
  ctx._previous_page = page_name
  local items = require("sidequest.render").render(buf, s.win, page, ctx)
  require("sidequest.keymaps").apply(buf, config, page.keys, items, ctx)
end

function M.register_tree(name, def)
  config.trees[name] = def
  local s = require("sidequest.state").get()
  if not s.stacks[name] then s.stacks[name] = { def.root or "overview" } end
end
function M.register_action(name, fn) require("sidequest.actions").register(name, fn) end
function M.register_context(name, fn) require("sidequest.context").register(name, fn) end

return M
