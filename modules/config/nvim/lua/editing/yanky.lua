require("yanky").setup({
  ring = { history_length = 50 },
  highlight = { timer = 200 },
})

-- Yanky remaps core put grammar (p/P), so these bypass the keymap registry
-- conflict warnings on built-in overrides by design.
vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { desc = "Put after (yanky)" })
vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { desc = "Put before (yanky)" })
vim.keymap.set("n", "<C-p>", "<Plug>(YankyPreviousEntry)", { desc = "Yanky: prev entry" })
vim.keymap.set("n", "<C-n>", "<Plug>(YankyNextEntry)", { desc = "Yanky: next entry" })
