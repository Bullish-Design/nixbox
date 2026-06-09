-- Setup only — no mappings. All mappings are defined in keymaps/ and plugin configs.
require("which-key").setup({
  preset = "helix", -- "modern", "helix", "classic"
  delay = 100,
  triggers = {
    { "<auto>", mode = "nxso" },
    { ",", mode = { "n", "v" } },
  },
  win = { border = "rounded" },
  sort = { "alphanum" }, -- "local", "order", "group", "alphanum", "mod" },
  icons = {
    mappings = false,
  },
  plugins = {
    marks = true,
    registers = true,
    spelling = { enabled = false },
    presets = {
      operators = true,
      motions = false, -- registers "," as a keymap, blocking the trigger
      text_objects = true,
      windows = true,
      nav = true,
      z = true,
      -- g = true,
    },
  },
})
