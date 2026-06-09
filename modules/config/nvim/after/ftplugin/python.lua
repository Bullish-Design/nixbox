-- Python localleader mappings.
local wk = require("which-key")
local buf = vim.api.nvim_get_current_buf()

wk.add({
  { "<localleader>", group = "Python", buffer = buf },
  { "<localleader>t", group = "Test", buffer = buf },
})

vim.keymap.set("n", "<localleader>tt", function() require("neotest").run.run() end, { buffer = buf, desc = "Test: nearest" })
vim.keymap.set("n", "<localleader>tT", function() require("neotest").run.run(vim.fn.expand("%")) end, { buffer = buf, desc = "Test: file" })
vim.keymap.set("n", "<localleader>tl", function() require("neotest").run.run_last() end, { buffer = buf, desc = "Test: last" })
vim.keymap.set("n", "<localleader>ts", function() require("neotest").summary.toggle() end, { buffer = buf, desc = "Test: summary" })
vim.keymap.set("n", "<localleader>tp", function() require("neotest").output_panel.toggle() end, { buffer = buf, desc = "Test: output" })
vim.keymap.set("n", "<localleader>R", function() vim.cmd("split | terminal python " .. vim.fn.expand("%")) end, { buffer = buf, desc = "Run file" })
