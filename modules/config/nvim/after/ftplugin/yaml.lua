-- YAML localleader mappings.
local wk = require("which-key")
local buf = vim.api.nvim_get_current_buf()

wk.add({
  { "<localleader>", group = "YAML", buffer = buf },
})

vim.keymap.set("n", "<localleader>f", function() vim.lsp.buf.format({ async = true }) end, { buffer = buf, desc = "Format buffer" })
vim.keymap.set("n", "<localleader>d", vim.diagnostic.open_float, { buffer = buf, desc = "Line diagnostics" })
