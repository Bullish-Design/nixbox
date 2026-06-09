vim.o.showtabline = 2

local theme = {
  fill = "KanagawaTabLineFill",
  head = "KanagawaTabLineHead",
  current_tab = "KanagawaTabLineCurrent",
  tab = "KanagawaTabLine",
  current_win = "KanagawaTabLineCurrentWin",
  win = "KanagawaTabLineWin",
  tail = "KanagawaTabLineTail",
}

local api = require("tabby.module.api")
local has_devicons, devicons = pcall(require, "mini.icons")

local function tab_name(tab)
  return (tab.name():gsub("%[..%]", ""))
end

local function buffer_name(name)
  if not name or name == "" then
    return "[No Name]"
  end
  if name:find("NvimTree") then
    return "NvimTree"
  end
  return name
end

local function icon_for_name(name)
  if not has_devicons then
    return ""
  end
  local icon = devicons.get("file", name)
  return icon or ""
end

local function get_hl(tab)
  return tab.is_current() and theme.current_tab or theme.tab
end

local function get_opening_sep(tab)
  local current_tab_number = api.get_tab_number(api.get_current_tab())
  return tab.number() > current_tab_number and "◥" or "◢"
end

local function get_closing_sep(tab)
  local current_tab_number = api.get_tab_number(api.get_current_tab())
  return tab.number() < current_tab_number and "◤" or "◣"
end

local function tab_window_count(tab)
  local wins = api.get_tab_wins(tab.id)
  return #wins > 1 and ("[" .. #wins .. "]") or ""
end

local function tab_modified(tabid)
  local wins = api.get_tab_wins(tabid)
  for _, winid in ipairs(wins) do
    local ok, bufid = pcall(vim.api.nvim_win_get_buf, winid)
    if ok and vim.api.nvim_buf_is_valid(bufid) and vim.bo[bufid].modified then
      return ""
    end
  end
  return ""
end

local function lsp_diag(bufid)
  if not bufid or not vim.api.nvim_buf_is_valid(bufid) then
    return ""
  end

  local errors = #vim.diagnostic.get(bufid, { severity = vim.diagnostic.severity.ERROR })
  local warnings = #vim.diagnostic.get(bufid, { severity = vim.diagnostic.severity.WARN })
  local modified = vim.bo[bufid].modified

  if errors > 0 then
    return modified and "" or ""
  elseif warnings > 0 then
    return modified and "" or ""
  end

  return modified and "" or ""
end

require("tabby.tabline").set(function(line)
  return {
    {
      { "   ", hl = theme.head },
      line.sep("", theme.head, theme.fill),
    },
    line.tabs().foreach(function(tab)
      local hl = get_hl(tab)
      local name = tab_name(tab)

      return {
        line.sep(get_opening_sep(tab), hl, theme.fill),
        icon_for_name(name),
        " ",
        tab.in_jump_mode() and tab.jump_key() or tab.number(),
        " ",
        name,
        tab_window_count(tab),
        " ",
        tab_modified(tab.id),
        line.sep(get_closing_sep(tab), hl, theme.fill),
        hl = hl,
        margin = " ",
      }
    end),
    line.spacer(),
    line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
      local hl = win.is_current() and theme.current_win or theme.win
      local bufid = win.buf().id
      local name = buffer_name(win.buf_name())

      return {
        line.sep("", hl, theme.fill),
        win.file_icon(),
        " ",
        name,
        " ",
        lsp_diag(bufid),
        line.sep("", hl, theme.fill),
        hl = hl,
        margin = " ",
      }
    end),
    {
      line.sep("", theme.tail, theme.fill),
      { "  ", hl = theme.tail },
    },
    hl = theme.fill,
  }
end)
