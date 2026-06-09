local ok, treesitter = pcall(require, "nvim-treesitter")
if ok then
  treesitter.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
  })
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
  callback = function(args)
    local started = pcall(vim.treesitter.start, args.buf)
    if started then
      vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.wo[0][0].foldmethod = "expr"
    end
  end,
})

local textobjects_ok, textobjects = pcall(require, "nvim-treesitter-textobjects")
if textobjects_ok then
  textobjects.setup({
    move = {
      set_jumps = true,
    },
  })

  local move = require("nvim-treesitter-textobjects.move")
  vim.keymap.set({ "n", "x", "o" }, "]m", function()
    move.goto_next_start("@function.outer", "textobjects")
  end, { desc = "Next function start" })
  vim.keymap.set({ "n", "x", "o" }, "[m", function()
    move.goto_previous_start("@function.outer", "textobjects")
  end, { desc = "Previous function start" })
  vim.keymap.set({ "n", "x", "o" }, "]]", function()
    move.goto_next_start("@class.outer", "textobjects")
  end, { desc = "Next class start" })
  vim.keymap.set({ "n", "x", "o" }, "[[", function()
    move.goto_previous_start("@class.outer", "textobjects")
  end, { desc = "Previous class start" })
end

local ctx_ok, ts_context = pcall(require, "treesitter-context")
if ctx_ok then
  ts_context.setup({
    max_lines = 3,
  })
end
