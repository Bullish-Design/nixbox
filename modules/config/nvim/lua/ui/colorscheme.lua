local variants = { "wave", "dragon", "lotus" }

local function make_diagnostic_color(theme, color)
  local c = require("kanagawa.lib.color")
  return { fg = color, bg = c(color):blend(theme.ui.bg, 0.95):to_hex() }
end

local function kanagawa_overrides(colors)
  local theme = colors.theme

  local mode_backgrounds = {
    Normal = theme.syn.fun,
    Insert = theme.diag.ok,
    Visual = theme.syn.keyword,
    Replace = theme.syn.constant,
    Command = theme.syn.operator,
    Other = theme.syn.type,
  }

  local devinfo_bg = theme.ui.bg_p1
  local filename_bg = theme.ui.bg_dim
  local fileinfo_bg = theme.ui.bg_m1

  local highlights = {
    Pmenu = { fg = theme.ui.pmenu.fg, bg = theme.ui.pmenu.bg },
    PmenuSel = { fg = theme.ui.pmenu.fg_sel, bg = theme.ui.pmenu.bg_sel },
    PmenuSbar = { bg = theme.ui.pmenu.bg_sbar },
    PmenuThumb = { bg = theme.ui.pmenu.bg_thumb },

    DiagnosticVirtualTextHint = make_diagnostic_color(theme, theme.diag.hint),
    DiagnosticVirtualTextInfo = make_diagnostic_color(theme, theme.diag.info),
    DiagnosticVirtualTextWarn = make_diagnostic_color(theme, theme.diag.warning),
    DiagnosticVirtualTextError = make_diagnostic_color(theme, theme.diag.error),

    KanagawaTabLineFill = { bg = theme.ui.bg },
    KanagawaTabLineHead = { fg = theme.syn.fun, bg = theme.ui.bg_m3, bold = true },
    KanagawaTabLineCurrent = { fg = theme.ui.bg_m3, bg = theme.syn.fun, bold = true },
    KanagawaTabLine = { fg = theme.ui.special, bg = theme.ui.bg_m3 },
    KanagawaTabLineCurrentWin = { fg = theme.ui.bg_m3, bg = theme.diag.ok, bold = true },
    KanagawaTabLineWin = { fg = theme.ui.fg_dim, bg = theme.ui.bg_p1 },
    KanagawaTabLineTail = { fg = theme.syn.type, bg = theme.ui.bg_m3, bold = true },

    MiniStatuslineDevinfo = { fg = theme.ui.fg_dim, bg = devinfo_bg },
    MiniStatuslineFilename = { fg = theme.ui.fg_dim, bg = filename_bg },
    MiniStatuslineFileinfo = { fg = theme.ui.fg_dim, bg = fileinfo_bg },
    MiniStatuslineInactive = { fg = theme.ui.nontext, bg = theme.ui.bg_m3 },
    MiniStatuslineModeCommand = { fg = theme.ui.bg, bg = mode_backgrounds.Command, bold = true },
    MiniStatuslineModeInsert = { fg = theme.ui.bg, bg = mode_backgrounds.Insert, bold = true },
    MiniStatuslineModeNormal = { fg = theme.ui.bg_m3, bg = mode_backgrounds.Normal, bold = true },
    MiniStatuslineModeOther = { fg = theme.ui.bg, bg = mode_backgrounds.Other, bold = true },
    MiniStatuslineModeReplace = { fg = theme.ui.bg, bg = mode_backgrounds.Replace, bold = true },
    MiniStatuslineModeVisual = { fg = theme.ui.bg, bg = mode_backgrounds.Visual, bold = true },

    StlSepDevinfoFile = { fg = devinfo_bg, bg = filename_bg },
    StlMetaA = { fg = theme.ui.fg_dim, bg = fileinfo_bg },
    StlMetaB = { fg = theme.ui.fg_dim, bg = devinfo_bg },
    StlSepFileMeta = { fg = fileinfo_bg, bg = filename_bg },
    StlSepMetaType = { fg = devinfo_bg, bg = fileinfo_bg },
    StlSepTypeInfo = { fg = fileinfo_bg, bg = devinfo_bg },
  }

  for suffix, mode_bg in pairs(mode_backgrounds) do
    highlights["StlSep" .. suffix .. "Left"] = { fg = mode_bg, bg = devinfo_bg }
    highlights["StlSep" .. suffix .. "Right"] = { fg = mode_bg, bg = fileinfo_bg }
  end

  return highlights
end

local function apply_kanagawa(variant)
  local selected = variant or "wave"

  require("kanagawa").setup({
    compile = false,
    undercurl = true,
    commentStyle = { italic = true },
    functionStyle = {},
    keywordStyle = { italic = true },
    statementStyle = { bold = true },
    typeStyle = {},
    transparent = false,
    dimInactive = false,
    terminalColors = true,
    colors = {
      palette = {},
      theme = {
        all = {
          ui = {
            bg_gutter = "none",
          },
        },
        wave = {},
        dragon = {},
        lotus = {},
      },
    },
    overrides = kanagawa_overrides,
    theme = selected,
    background = {
      dark = "wave",
      light = "lotus",
    },
  })

  require("kanagawa").load(selected)
  vim.g.kanagawa_variant = selected
end

vim.api.nvim_create_user_command("KanagawaSet", function(opts)
  local variant = opts.args
  for _, v in ipairs(variants) do
    if v == variant then
      apply_kanagawa(variant)
      return
    end
  end

  vim.notify(
    "Invalid Kanagawa variant: "
      .. variant
      .. ". Use one of: "
      .. table.concat(variants, ", "),
    vim.log.levels.ERROR
  )
end, {
  nargs = 1,
  complete = function()
    return variants
  end,
  desc = "Set Kanagawa variant (wave/dragon/lotus)",
})

vim.api.nvim_create_user_command("KanagawaCycle", function()
  local current = vim.g.kanagawa_variant or "wave"
  local current_index = 1

  for i, v in ipairs(variants) do
    if v == current then
      current_index = i
      break
    end
  end

  local next_index = (current_index % #variants) + 1
  local next_variant = variants[next_index]
  apply_kanagawa(next_variant)
  vim.notify("Kanagawa: " .. next_variant, vim.log.levels.INFO)
end, { desc = "Cycle Kanagawa variants" })

apply_kanagawa(vim.g.kanagawa_variant or "wave")
