local M = {}

local state = {
  initialized = false,
  buf = nil,
  win = nil,
  previous_win = nil,
  active_tree = "workspace",
  stacks = {
    workspace = { "overview" },
  },
  tabs = {
    workspace = "code",
  },
  tab_stacks = {
    workspace = {
      code = { "overview" },
      testing = { "overview" },
      notes = { "overview" },
    },
  },
  ctx = nil,
  ctx_version = 0,
  keymap_version = 0,
  active_keymaps = {},
}

function M.get()
  return state
end

function M.reset_stack(tree)
  local trees = require("sidequest").get_config().trees or {}
  local def = trees[tree]
  local root = def and def.root or "overview"
  state.stacks[tree] = { root }
end

function M.current_page()
  local tree = state.active_tree
  local tab = state.tabs and state.tabs[tree]
  if tab and state.tab_stacks and state.tab_stacks[tree] then
    local stack = state.tab_stacks[tree][tab]
    return stack and stack[#stack] or "overview"
  end
  local stack = state.stacks[tree]
  return stack and stack[#stack] or "overview"
end

function M.push_page(page)
  local tree = state.active_tree
  local tab = state.tabs and state.tabs[tree]
  if tab and state.tab_stacks and state.tab_stacks[tree] then
    table.insert(state.tab_stacks[tree][tab], page)
  else
    table.insert(state.stacks[tree], page)
  end
end

function M.pop_page()
  local tree = state.active_tree
  local tab = state.tabs and state.tabs[tree]
  local stack
  if tab and state.tab_stacks and state.tab_stacks[tree] then
    stack = state.tab_stacks[tree][tab]
  else
    stack = state.stacks[tree]
  end
  if #stack > 1 then
    table.remove(stack)
    return true
  end
  return false
end

function M.current_tab()
  local tree = state.active_tree
  return state.tabs and state.tabs[tree] or nil
end

function M.switch_tab(tab_id)
  local tree = state.active_tree
  if not state.tabs then state.tabs = {} end
  state.tabs[tree] = tab_id
  if not state.tab_stacks then state.tab_stacks = {} end
  if not state.tab_stacks[tree] then state.tab_stacks[tree] = {} end
  if not state.tab_stacks[tree][tab_id] then state.tab_stacks[tree][tab_id] = { "overview" } end
end

return M
