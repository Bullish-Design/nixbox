require("fff").setup({
  frecency = {
    enabled = true,
    db_path = vim.fn.stdpath("cache") .. "/fff_nvim",
  },
  history = {
    enabled = true,
    db_path = vim.fn.stdpath("data") .. "/fff_queries",
  },
})
