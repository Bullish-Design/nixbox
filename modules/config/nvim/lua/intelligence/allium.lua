require("allium").setup({
  lsp = {
    cmd = { "allium-lsp", "--stdio" },
    filetypes = { "allium" },
    root_markers = { "allium.config.json", ".git" },
    settings = {},
  },
})
