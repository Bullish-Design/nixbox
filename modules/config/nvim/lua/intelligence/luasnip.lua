local ls = require("luasnip")

ls.setup({})

-- Load VS Code style snippets (from friendly-snippets)
require("luasnip.loaders.from_vscode").lazy_load()
