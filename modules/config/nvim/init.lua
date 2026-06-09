vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Update vim.pack plugins" })

vim.cmd([[
  cnoreabbrev <expr> packupdate ((getcmdtype() ==# ':' && getcmdline() ==# 'packupdate') ? 'PackUpdate' : 'packupdate')
]])

vim.pack.add({
  { src = "https://github.com/echasnovski/mini.nvim",                       version = "v0.17.0" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "851e865342e5a4cb1ae23d31caf6e991e1c99f1e" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-context",     version = "v1.0.0" },
  { src = "https://github.com/Saghen/blink.cmp",                            version = "v1.10.2" },
  { src = "https://github.com/neovim/nvim-lspconfig",                       version = "v2.9.0" },
  { src = "https://github.com/rafamadriz/friendly-snippets",                version = "6cd7280adead7f586db6fccbd15d2cac7e2188b9" },
  { src = "https://github.com/folke/snacks.nvim",                           version = "v2.31.0" },
  { src = "https://github.com/rachartier/tiny-cmdline.nvim",                version = "ad58747b955d0743ccfd56e97da1a4c1fac89f58" },
  { src = "https://github.com/nanozuki/tabby.nvim",                         version = "v2.8.1" },
  { src = "https://github.com/folke/edgy.nvim",                             version = "v1.10.2" },
  { src = "https://github.com/NeogitOrg/neogit",                            version = "v3.0.0" },
  { src = "https://github.com/sindrets/diffview.nvim",                      version = "4516612fe98ff56ae0415a259ff6361a89419b0a" },
  { src = "https://github.com/gbprod/yanky.nvim",                           version = "v2.0.0" },
  { src = "https://github.com/MagicDuck/grug-far.nvim",                     version = "1.6.69" },
  { src = "https://github.com/stevearc/resession.nvim",                     version = "v1.2.0" },
  { src = "https://github.com/tris203/precognition.nvim",                   version = "v1.3.0" },
  { src = "https://github.com/folke/todo-comments.nvim",                    version = "v1.5.0" },
  { src = "https://github.com/nvim-lua/plenary.nvim",                       version = "v0.1.4" },
  { src = "https://github.com/rebelot/kanagawa.nvim",                       version = "master" },
  { src = "https://github.com/Bullish-Design/wayfinder.nvim",               version = "v0.3.0" },
  { src = "https://github.com/TheNoeTrevino/haunt.nvim",                    version = "v1.2.0" },
  { src = "https://github.com/paradoxical-dev/zeal.nvim",                   version = "5b60a017ccc0bd9e0f4768367e425fdae6a6e500" },
  { src = "https://github.com/obsidian-nvim/obsidian.nvim",                 version = "v3.16.3" },
  { src = "https://github.com/delphinus/md-render.nvim",                    version = "v3.1.1" },
  { src = "https://github.com/edmundmiller/bases.nvim",                     version = "146c92bd8c1bb3c23b3ba01fca8f635b2cde2d82" },
  { src = "https://github.com/Bullish-Design/tasknotes.nvim",               version = "v0.2.0" },
  { src = "https://github.com/MunifTanjim/nui.nvim",                        version = "0.4.0" },
  { src = "https://github.com/dmtrKovalenko/fff",                           version = "0.8.2-nightly.cf3dcf6" },
  { src = "https://github.com/nvim-neotest/neotest",                        version = "v5.18.0" },
  { src = "https://github.com/L3MON4D3/LuaSnip",                            version = "v2.5.0" },
  { src = "https://github.com/piersolenski/wtf.nvim",                       version = "ef7c22daf5c99f4c96fc2d0719d6f1848802fc02" },
  { src = "https://github.com/m-demare/hlargs.nvim",                        version = "0b29317c944fb1f76503ce4540d6dceffbb5ccd2" },
  { src = "https://github.com/rachartier/tiny-code-action.nvim",            version = "0d040ed81f7953118b81cd12681fcdfcac069803" },
  { src = "https://github.com/oflisback/obsidian-bridge.nvim",              version = "28f076e861900902ee2e01c874a0195b64ca03b6" },
  { src = "https://github.com/WilliamHsieh/overlook.nvim",                  version = "6f74f20a61204275989050a2c1221bdc53b534c4" },
  { src = "https://github.com/BlinkResearchLabs/blink-edit.nvim",           version = "220f5777f5597f6d7868981d6ff9b6218247fec4" },
  -- { src = "https://github.com/stevearc/aerial.nvim", version = "43dd88ad4024b1945906887521057c73d3b0d84e" },
  { src = "https://github.com/cbochs/grapple.nvim",                         version = "v0.30.0" },
  { src = "https://github.com/nvim-neotest/nvim-nio",                       version = "v1.10.1" },
  { src = "https://github.com/nvim-neotest/neotest-python",                 version = "e6df4f1892f6137f58135917db24d1655937d831" },
  { src = "https://github.com/folke/which-key.nvim",                        version = "v3.17.0" },
  { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim",   version = "v8.12.0" },
  { src = "https://github.com/hedyhli/outline.nvim",                        version = "v1.2.0" },
  { src = "https://github.com/swaits/zellij-nav.nvim",                      version = "91cc2a642d8927ebde50ced5bf71ba470a0fc116" },
  { src = "https://github.com/aaronik/treewalker.nvim",                     version = "0b081bf6c6875cf3e478b633796a9e2b64b730e8" },
  { src = "https://github.com/serhez/bento.nvim",                           version = "feat/v2" },
  { src = "https://github.com/folke/neoconf.nvim",                          version = "v1.4.0" },
  { src = "https://github.com/Bullish-Design/input-form.nvim",              version = "v0.2.0" },
  { src = "https://github.com/Dzejkop/datepicker.nvim",                     version = "3e6b8f2b87cb694b2492ea3254cf7d871f6ca954" },
  { src = "https://github.com/juxt/nvim-allium",                            version = "ae0bade344973347f695991f15dfe76ea0299253" },
})

require("core.options")
require("core.autocmds")
require("config.neoconf")

require("ui.colorscheme")
require("ui.misc")
require("ui.ui2")
require("ui.tiny_cmdline")
require("ui.statusline")
require("ui.tabline")
require("ui.bento")

require("editing.pairs")
require("editing.surround")
require("editing.ai")
require("editing.move")
require("editing.splitjoin")
require("editing.bracketed")
require("editing.yanky")
require("editing.grug_far")

require("visual.hipatterns")
require("visual.icons")
require("visual.todo_comments")
require("visual.precognition")
require("visual.scope")
require("visual.hlargs")

require("intelligence.treesitter")
require("intelligence.completion")
require("intelligence.lsp")
require("intelligence.luasnip")
require("intelligence.wtf")
require("intelligence.tiny_code_action")
require("intelligence.overlook")
require("intelligence.allium")
-- require("intelligence.blink_edit")
require("intelligence.outline")

require("interaction.dashboard")
require("interaction.picker")
require("interaction.explorer")
require("interaction.scratch")
require("interaction.terminal")
require("interaction.zellij")
require("interaction.snacks")

require("git.signs")
require("git.commands")
require("git.neogit")
require("git.browse")

require("workspace.edgy")
require("workspace.sessions")
require("workspace.grapple")
require("workspace.submodes")
require("sidequest").setup({
  trees = {
    workspace = require("sidequest.pages.workspace"),
    sessions = require("sidequest.pages.sessions"),
    git = require("sidequest.pages.git"),
  },
})

-- Development tools
require("development.wayfinder")
require("development.haunt")
require("development.zeal")
require("development.fff")
require("development.neotest")

-- Productivity
require("productivity.notes")
require("productivity.obsidian")
require("productivity.md_render")
-- require("productivity.tasknotes")
require("productivity.obsidian_bridge")
require("loci").setup({})

require("keymaps.global")
require("keymaps.navigation")
require("keymaps.leader")
require("keymaps.lsp")

require("ui.which_key")
require("render-markdown").setup({
  latex = { enabled = false },
})

-- Use snacks notifier history as :messages
-- vim.cmd([[cnoreabbrev <expr> messages (getcmdtype() ==# ':' && getcmdline() ==# 'messages') ? 'lua Snacks.notifier.show_history()' : 'messages']])
