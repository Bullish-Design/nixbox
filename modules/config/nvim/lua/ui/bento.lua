require("bento").setup({
  max_open_buffers = 20,
  ordering_metric = "access",
  buffer_deletion_metric = "frecency_access",
  buffer_notify_on_delete = false,
  lock_char = "",
  locked_first = true,

  ui = {
    mode = "floating",
    floating = {
      position = "top-right",
      offset_x = 1,
      offset_y = 1,
      border = "rounded",
      label_padding = 1,
      minimal_menu = "filename",
      max_rendered_buffers = 10,
    },
  },

  highlights = {
    current = "TabLineSel",
    active = "Normal",
    inactive = "Comment",
    modified = "DiagnosticWarn",
    inactive_dash = "Comment",
    previous = "Search",
    label = "DiagnosticVirtualTextHint",
    label_minimal = "Visual",
    window_bg = "NormalFloat",
    page_indicator = "Comment",
    separator = "Comment",
  },
})

local api = require("bento.api")

-- Menu controls
api.register_expand_key("<leader>wbb")
api.register_collapse_key("<Esc>")
api.register_last_buffer_key("<leader>wbl")
api.register_next_page_key("<C-n>")
api.register_prev_page_key("<C-p>")

-- Actions
api.register_action("open", { key = "<CR>", action = api.actions.open })
api.register_action("delete", { key = "d", action = api.actions.delete })
api.register_action("vsplit", { key = "v", action = api.actions.vsplit })
api.register_action("split", { key = "s", action = api.actions.split })
api.register_action("lock", { key = "l", action = api.actions.lock })
api.register_action("tab", { key = "t", action = function(buf_id, buf_name)
  local bufnr = vim.fn.bufnr(buf_name)
  if bufnr ~= -1 then
    vim.cmd("tabnew | buffer " .. bufnr)
  else
    vim.cmd("tabnew " .. buf_name)
  end
  require("bento.ui").collapse_menu()
end })
api.set_default_action("open")
