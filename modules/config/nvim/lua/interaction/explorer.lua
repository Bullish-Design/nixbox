-- Explorer config for snacks.nvim.
-- localleader keys are registered via FileType autocmd below.

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("ExplorerLocalleader", { clear = true }),
  pattern = "snacks_explorer",
  callback = function(event)
    local wk = require("which-key")
    local buf = event.buf

    local function explorer_action(name)
      return function()
        local p = Snacks.picker.get({ source = "explorer" })[1]
        if p then p:action(name) end
      end
    end

    wk.add({
      { "<localleader>",  group = "Explorer",                          buffer = buf },
      { "<localleader>n", explorer_action("explorer_add"),    desc = "New file",       buffer = buf },
      { "<localleader>o", explorer_action("explorer_add"),    desc = "New file",       buffer = buf },
      { "<localleader>r", explorer_action("explorer_rename"), desc = "Rename",         buffer = buf },
      { "<localleader>d", explorer_action("explorer_del"),    desc = "Delete",         buffer = buf },
      { "<localleader>c", explorer_action("explorer_copy"),   desc = "Copy",           buffer = buf },
      { "<localleader>m", explorer_action("explorer_move"),   desc = "Move",           buffer = buf },
      { "<localleader>y", explorer_action("explorer_yank"),   desc = "Yank path",      buffer = buf },
      { "<localleader>h", explorer_action("toggle_hidden"),   desc = "Toggle hidden",  buffer = buf },
      { "<localleader>f", explorer_action("toggle_focus"),    desc = "Filter (focus input)", buffer = buf },
    })
  end,
})

return {
  replace_netrw = true,
}
