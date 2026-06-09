-- Lua localleader mappings.
local wk = require("which-key")
local buf = vim.api.nvim_get_current_buf()

wk.add({
  { "<localleader>", group = "Lua", buffer = buf },
})

vim.keymap.set("n", "<localleader>x", function() vim.cmd("source %") end, { buffer = buf, desc = "Run file" })
vim.keymap.set("n", "<localleader>l", function() vim.cmd("lua " .. vim.api.nvim_get_current_line()) end, { buffer = buf, desc = "Run line" })
vim.keymap.set("n", "<localleader>s", function() vim.notify(vim.inspect(vim.v.completed_item)) end, { buffer = buf, desc = "Inspect symbol" })
vim.keymap.set("n", "<localleader>p", function()
  local line = vim.api.nvim_get_current_line()
  local ok, val = pcall(load("return " .. line))
  if ok then vim.notify(vim.inspect(val)) else vim.notify(tostring(val), vim.log.levels.WARN) end
end, { buffer = buf, desc = "Print expression" })
