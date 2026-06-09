-- Global non-leader keymaps via wk.add().
local wk = require("which-key")

wk.add({
  -- Save
  { "<C-s>", "<cmd>update<cr>",        desc = "Save",               mode = "n" },
  { "<C-s>", "<Esc><cmd>update<cr>",   desc = "Save",               mode = "i" },

  -- Window navigation
  { "<C-h>", "<C-w>h", desc = "Window: focus left" },
  { "<C-j>", "<C-w>j", desc = "Window: focus down" },
  { "<C-k>", "<C-w>k", desc = "Window: focus up" },
  { "<C-l>", "<C-w>l", desc = "Window: focus right" },

  -- Window resize
  { "<C-S-h>", "<cmd>vertical resize -5<cr>", desc = "Window: shrink width" },
  { "<C-S-l>", "<cmd>vertical resize +5<cr>", desc = "Window: grow width" },
  { "<C-S-j>", "<cmd>resize -3<cr>",          desc = "Window: shrink height" },
  { "<C-S-k>", "<cmd>resize +3<cr>",          desc = "Window: grow height" },

  -- Buffer cycling
  { "<Tab>",   "<cmd>bnext<cr>",     desc = "Buffer: next" },
  { "<S-Tab>", "<cmd>bprevious<cr>", desc = "Buffer: prev" },

  -- Tab navigation
  { "]t", "<cmd>tabnext<cr>",     desc = "Tab: next" },
  { "[t", "<cmd>tabprevious<cr>", desc = "Tab: prev" },

  -- Treesitter navigation (g+hjkl)
  { "gh", "<cmd>Treewalker Left<cr>",  desc = "Tree: parent" },
  { "gj", "<cmd>Treewalker Down<cr>",  desc = "Tree: next sibling" },
  { "gk", "<cmd>Treewalker Up<cr>",    desc = "Tree: prev sibling" },
  { "gl", "<cmd>Treewalker Right<cr>", desc = "Tree: child" },

  -- Treesitter swap (Shift+g+hjkl)
  { "gH", "<cmd>Treewalker SwapLeft<cr>",  desc = "Tree: swap parent" },
  { "gJ", "<cmd>Treewalker SwapDown<cr>",  desc = "Tree: swap next" },
  { "gK", "<cmd>Treewalker SwapUp<cr>",    desc = "Tree: swap prev" },
  { "gL", "<cmd>Treewalker SwapRight<cr>", desc = "Tree: swap child" },

  -- Search / scroll
  { "<Esc>", "<cmd>nohlsearch<cr>", desc = "Clear search highlight" },

  -- Terminal
  { "<Esc><Esc>", "<C-\\><C-n>", desc = "Terminal: exit to normal", mode = "t" },
})
