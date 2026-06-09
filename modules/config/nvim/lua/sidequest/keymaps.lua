local M = {}
local owned = {}

function M.set(buf, mode, lhs, rhs, opts)
  opts = vim.tbl_extend("force", opts or {}, { buffer = buf, noremap = true, silent = true, nowait = true })
  vim.keymap.set(mode, lhs, rhs, opts)
  table.insert(owned, { buf = buf, mode = mode, lhs = lhs, desc = opts.desc })
end

function M.clear(buf)
  for _, map in ipairs(owned) do
    if map.buf == buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.keymap.del, map.mode, map.lhs, { buffer = buf })
    end
  end
  owned = vim.tbl_filter(function(m) return m.buf ~= buf end, owned)
end

function M.apply(buf, config, page_keys, items, ctx)
  local state = require("sidequest.state").get()
  local actions = require("sidequest.actions")
  M.clear(buf)

  local reserved = config.keymaps and config.keymaps.reserved or {}
  for lhs, action_name in pairs(reserved) do
    local fn = actions.get(action_name)
    if fn then M.set(buf, "n", lhs, function() fn(ctx) end, { desc = "Sidequest: " .. action_name }) end
  end
  local tree_def = config.trees and config.trees[require("sidequest.state").get().active_tree]
  if tree_def and tree_def.tabs then
    for i, tab in ipairs(tree_def.tabs) do
      M.set(buf, "n", tostring(i), function() require("sidequest").switch_tab(tab.id) end, { desc = "Sidequest: tab " .. tab.label })
    end
    M.set(buf, "n", "H", function() require("sidequest").prev_tab() end, { desc = "Sidequest: prev tab" })
    M.set(buf, "n", "L", function() require("sidequest").next_tab() end, { desc = "Sidequest: next tab" })
  end

  if page_keys then
    for key, def in pairs(page_keys) do
      local resolved = actions.resolve(def, ctx)
      if resolved then
        local wrapped = resolved
        if def.close then wrapped = function() require("sidequest").close(); resolved() end end
        M.set(buf, "n", key, wrapped, { desc = "Sidequest: " .. (def.desc or def.action or "action") })
      end
    end
  end

  if items then
    for _, item in ipairs(items) do
      if item.key then
        local resolved = actions.resolve(item, ctx)
        if resolved then
          local wrapped = resolved
          if item.close then wrapped = function() require("sidequest").close(); resolved() end end
          M.set(buf, "n", item.key, wrapped, { desc = "Sidequest: " .. (item.label or item.action or "action") })
        end
      end
    end
  end

  if config.keymaps and config.keymaps.strict and config.keymaps.blocked_prefixes then
    for _, prefix in ipairs(config.keymaps.blocked_prefixes) do
      local already_mapped = false
      for _, m in ipairs(owned) do
        if m.buf == buf and m.lhs == prefix then already_mapped = true; break end
      end
      if not already_mapped then
        M.set(buf, "n", prefix, function() vim.notify("Key disabled in Sidequest: " .. prefix, vim.log.levels.INFO) end, { desc = "Sidequest: blocked" })
      end
    end
  end

  state.keymap_version = state.keymap_version + 1
  state.active_keymaps = {}
  for _, m in ipairs(owned) do
    if m.buf == buf then table.insert(state.active_keymaps, m) end
  end
end

function M.get_active()
  return require("sidequest.state").get().active_keymaps or {}
end

return M
