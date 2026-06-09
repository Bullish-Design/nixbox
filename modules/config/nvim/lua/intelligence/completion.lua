require("blink.cmp").setup({
  keymap = {
    preset = "default",
    ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "snippet_backward", "fallback" },
    ["<C-l>"] = { "select_and_accept", "fallback_to_mappings" },
    ["<C-j>"] = { "select_next", "fallback_to_mappings" },
    ["<C-k>"] = { "select_prev", "fallback_to_mappings" },
    ["<Down>"] = { "select_next", "fallback_to_mappings" },
    ["<Up>"] = { "select_prev", "fallback_to_mappings" },
    ["<CR>"] = { "fallback" },
  },

  snippets = { preset = "default" },

  completion = {
    list = {
      selection = {
        preselect = false,
        auto_insert = false,
      },
    },
    documentation = { auto_show = false, auto_show_delay_ms = 400 },
    ghost_text = { enabled = false },
    menu = {
      border = nil,
      max_height = 10,
      cmdline_position = function()
        if vim.g.ui_cmdline_pos ~= nil then
          local pos = vim.g.ui_cmdline_pos
          return { pos[1] - 1, pos[2] }
        end
        local height = (vim.o.cmdheight == 0) and 1 or vim.o.cmdheight
        return { vim.o.lines - height, 0 }
      end,
    },
  },

  sources = {
    default = { "lsp", "path", "snippets", "buffer", "loci_tags" },
    providers = {
      lsp = { fallbacks = { "buffer" } },
      loci_tags = {
        name = "Loci Tags",
        module = "intelligence.loci_tags_source",
        enabled = function() return vim.bo.filetype == "input-form" and vim.b.loci_tag_input == true end,
        score_offset = 12,
      },
    },
  },

  cmdline = {
    enabled = true,
    keymap = {
      preset = "inherit",
      ["<Tab>"] = { "show", "accept" },
    },
    sources = function()
      local t = vim.fn.getcmdtype()
      if t == "/" or t == "?" then return { "buffer" } end
      if t == ":" or t == "@" then return { "cmdline", "buffer" } end
      return {}
    end,
    completion = {
      menu = { auto_show = function() return vim.fn.getcmdtype() == ":" end },
      ghost_text = { enabled = false },
    },
  },

  signature = { enabled = true },

  fuzzy = { implementation = "prefer_rust_with_warning" },
})
