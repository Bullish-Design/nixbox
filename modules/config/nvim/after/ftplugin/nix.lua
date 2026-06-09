-- Nix localleader mappings.
local wk = require("which-key")
local buf = vim.api.nvim_get_current_buf()

wk.add({
  { "<localleader>", group = "Nix", buffer = buf },
})

vim.keymap.set("n", "<localleader>b", function() vim.cmd("split | terminal nix build") end, { buffer = buf, desc = "nix build" })
vim.keymap.set("n", "<localleader>c", function() vim.cmd("split | terminal nix flake check") end, { buffer = buf, desc = "nix flake check" })
vim.keymap.set("n", "<localleader>u", function() vim.cmd("split | terminal nix flake update") end, { buffer = buf, desc = "nix flake update" })
