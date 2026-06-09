require("todo-comments").setup({
  signs = false,
  highlight = {
    multiline = false,
  },
  keywords = {
    TODO = { icon = " " },
    FIX = { icon = " ", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
    NOTE = { icon = " ", alt = { "INFO" } },
    HACK = { icon = " " },
    WARN = { icon = " ", alt = { "WARNING", "XXX" } },
    PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
    TEST = { icon = "⏲ ", alt = { "TESTING", "PASSED", "FAILED" } },
  },
})
