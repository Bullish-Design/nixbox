local statusline = require("mini.statusline")

local mode_sep = setmetatable({
  MiniStatuslineModeNormal = "StlSepNormal",
  MiniStatuslineModeInsert = "StlSepInsert",
  MiniStatuslineModeVisual = "StlSepVisual",
  MiniStatuslineModeReplace = "StlSepReplace",
  MiniStatuslineModeCommand = "StlSepCommand",
  MiniStatuslineModeOther = "StlSepOther",
}, { __index = function() return "StlSepOther" end })

local function section_git_with_branch(trunc_width)
  local git = statusline.section_git({ trunc_width = trunc_width or 120 })
  local summary = vim.b.minigit_summary or {}
  local head = summary.head_name or summary.head or ""

  if head ~= "" and not git:find(head, 1, true) then
    if git == "" then
      git = " " .. head
    else
      git = git .. " " .. head
    end
  end

  return git
end

local active = function()
  local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
  local git = section_git_with_branch(120)
  local diff = statusline.section_diff({ trunc_width = 120 })
  local diagnostics = statusline.section_diagnostics({ trunc_width = 120 })
  local lsp = statusline.section_lsp({ trunc_width = 120 })
  local filename = statusline.section_filename({ trunc_width = 140 })
  local location = statusline.section_location({ trunc_width = 999 })
  local search = statusline.section_searchcount({ trunc_width = 200 })
  local filetype = vim.bo.filetype ~= "" and vim.bo.filetype or "text"
  local encoding = (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding) .. " " .. vim.bo.fileformat
  local line = vim.fn.line(".")
  local total_lines = math.max(vim.fn.line("$"), 1)
  local progress = string.format("%d%%", math.floor((line / total_lines) * 100))

  local sep = mode_sep[mode_hl]

  return statusline.combine_groups({
    { hl = mode_hl, strings = { mode } },
    "%#" .. sep .. "Left#",
    " ",
    "%<",
    { hl = "MiniStatuslineDevinfo", strings = { git } },
    "%#StlSepDevinfoFile#",
    " ",
    { hl = "MiniStatuslineFilename", strings = { filename } },
    "%=",
    "%#StlSepFileMeta#",
    " ",
    { hl = "StlMetaA", strings = { encoding } },
    "%#StlSepMetaType#",
    " ",
    { hl = "StlMetaB", strings = { filetype } },
    "%#StlSepTypeInfo#",
    " ",
    { hl = "MiniStatuslineFileinfo", strings = { diff, diagnostics, lsp } },
    "%#" .. sep .. "Right#",
    " ",
    { hl = mode_hl, strings = { progress, search, location } },
  })
end

local inactive = function()
  return "%#MiniStatuslineInactive#%f%m%r%="
end

statusline.setup({
  content = { active = active, inactive = inactive },
  use_icons = true,
})
