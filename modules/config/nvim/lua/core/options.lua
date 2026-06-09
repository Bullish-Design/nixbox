local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.breakindent = true

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.grepprg = "rg --vimgrep"
opt.grepformat = "%f:%l:%c:%m"

opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.colorcolumn = "120"
opt.cmdheight = 0
opt.showmode = false
opt.winborder = "rounded"
opt.showtabline = 2

opt.splitbelow = true
opt.splitright = true

-- Defer clipboard setup to avoid wl-paste crash on empty clipboard at startup
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

opt.foldlevel = 99
opt.foldlevelstart = 99

opt.swapfile = false
opt.backup = false
opt.undofile = true

opt.list = true
opt.listchars = { trail = "·", tab = "» " }

opt.sessionoptions = "curdir,folds,globals,help,tabpages,terminal,winsize"

opt.updatetime = 250
opt.timeoutlen = 300
opt.mouse = "a"
opt.completeopt = "menu,menuone,noselect"
opt.shortmess:append("I")
