local M = {}

function M.render_tab_strip(tree_def, active_tab)
  local lines = {}
  local parts = {}
  for i, tab in ipairs(tree_def.tabs) do
    if tab.id == active_tab then
      table.insert(parts, "[" .. i .. " " .. tab.label .. "]")
    else
      table.insert(parts, " " .. i .. " " .. tab.label .. " ")
    end
  end
  table.insert(lines, "  " .. table.concat(parts, "  "))
  table.insert(lines, "  " .. string.rep("─", 38))
  table.insert(lines, "")
  return lines
end

function M.render(buf, win, page, ctx)
  local lines, items = {}, {}
  local state_mod = require("sidequest.state")
  local tree_def = require("sidequest").get_config().trees[state_mod.get().active_tree]
  if tree_def and tree_def.tabs then
    local active_tab = state_mod.current_tab()
    if active_tab then
      for _, line in ipairs(M.render_tab_strip(tree_def, active_tab)) do
        table.insert(lines, line)
      end
    end
  end
  local title = page.title
  if type(title) == "function" then title = title(ctx) end
  if title then
    table.insert(lines, "")
    table.insert(lines, "  " .. title)
    table.insert(lines, "  " .. string.rep("─", #title))
    table.insert(lines, "")
  end

  for _, section_def in ipairs(page.sections or {}) do
    local section = section_def
    if type(section) == "string" then
      section = page.section_defs and page.section_defs[section_def]
      if not section then goto continue end
    end

    if section.title then
      table.insert(lines, "  " .. section.title)
      table.insert(lines, "")
    end

    if section.type == "actions" then
      for _, item in ipairs(section.items or {}) do
        local key_display = item.key and ("[" .. item.key .. "]") or "   "
        table.insert(lines, "  " .. key_display .. " " .. (item.icon or "") .. item.label)
        table.insert(items, item)
      end
      table.insert(lines, "")
    elseif section.type == "lines" then
      for _, line in ipairs(section.render and section.render(ctx) or {}) do table.insert(lines, "  " .. line) end
      table.insert(lines, "")
    elseif section.type == "separator" then
      local width = win and vim.api.nvim_win_get_width(win) or 40
      table.insert(lines, "  " .. string.rep("─", width - 4))
      table.insert(lines, "")
    elseif section.type == "padding" then
      for _ = 1, (section.count or 1) do table.insert(lines, "") end
    end
    ::continue::
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return items
end

return M
