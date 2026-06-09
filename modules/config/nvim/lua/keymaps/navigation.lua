-- Centered scroll and search navigation.
local wk = require("which-key")

wk.add({
  { "n",     "nzzzv",   desc = "Search: next (centered)" },
  { "N",     "Nzzzv",   desc = "Search: prev (centered)" },
  { "<C-d>", "<C-d>zz", desc = "Scroll: half-page down (centered)" },
  { "<C-u>", "<C-u>zz", desc = "Scroll: half-page up (centered)" },
})
