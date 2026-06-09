-- Markdown localleader — non-vault .md files only.
-- Vault files (~Documents/Notes/) are handled by productivity/obsidian.lua.
local vault_path = vim.fn.expand("~/Documents/Notes")
local bufpath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
if bufpath:sub(1, #vault_path) == vault_path then return end

local ok_wk, wk = pcall(require, "which-key")
local buf = vim.api.nvim_get_current_buf()      -- TODO: 84736 Test comment index

if ok_wk then
  wk.add({
    { "<localleader>", group = "Markdown", buffer = buf },
  })
end

vim.keymap.set("n", "<localleader>p", function() require("md-render").toggle() end, { buffer = buf, desc = "Preview toggle" })
vim.keymap.set("n", "<localleader>f", function() vim.lsp.buf.format({ async = true }) end, { buffer = buf, desc = "Format buffer" })
