local augroup = vim.api.nvim_create_augroup

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("ResizeSplits", { clear = true }),
  command = "tabdo wincmd =",
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("RestoreCursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("IndentscopeDisable", { clear = true }),
  pattern = { "help", "neogit*", "DiffviewFiles", "snacks_*", "sidequest" },
  callback = function()
    vim.b.miniindentscope_disable = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("Ui2Styling", { clear = true }),
  pattern = { "cmd", "msg", "pager", "dialog" },
  callback = function()
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:NormalFloat,FloatBorder:FloatBorder,Search:Search",
      { scope = "local", win = win }
    )
    vim.api.nvim_set_option_value("wrap", true, { scope = "local", win = win })
  end,
})
