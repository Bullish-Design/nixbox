-- Picker localleader — discoverable wrappers for picker toggle options.
-- Registered via FileType autocmd on snacks_picker_list and snacks_picker_input.

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("PickerLocalleader", { clear = true }),
  pattern = { "snacks_picker_list", "snacks_picker_input" },
  callback = function(event)
    local wk = require("which-key")
    local buf = event.buf
    local function picker_action(name)
      return function()
        local p = Snacks.picker.get()[1]
        if p then p:action(name) end
      end
    end

    wk.add({
      { "<localleader>",  group = "Picker",                buffer = buf },
      { "<localleader>h", picker_action("toggle_hidden"),  desc = "Toggle hidden",    buffer = buf },
      { "<localleader>i", picker_action("toggle_ignored"), desc = "Toggle ignored",   buffer = buf },
      { "<localleader>p", picker_action("toggle_preview"), desc = "Toggle preview",   buffer = buf },
      { "<localleader>l", picker_action("toggle_live"),    desc = "Toggle live grep", buffer = buf },
    })
  end,
})

return {
  enabled = true,
  -- limit = 0,           -- no cap on static finders (0 = unlimited)
  limit_live = 50000, -- higher cap for live grep (default 10000)
  -- ; and C-j/C-k toggle focus between list and input in all pickers.
  -- These are buffer-local so they override global C-j/C-k (zellij-nav / window nav).
  win = {
    list = {
      keys = {
        [";"]       = { "toggle_focus", mode = { "n", "i" } },
        ["<C-j>"]   = { "toggle_focus", mode = { "n", "i" } },
        ["<C-k>"]   = { "toggle_focus", mode = { "n", "i" } },
        ["<Space>"] = { "select_and_next", mode = { "n" } },
      },
    },
    input = {
      keys = {
        [";"]     = { "toggle_focus", mode = { "n", "i" } },
        ["<C-j>"] = { "toggle_focus", mode = { "n", "i" } },
        ["<C-k>"] = { "toggle_focus", mode = { "n", "i" } },
      },
    },
  },
  sources = {
    explorer = {
      hidden = true,
      ignored = true,
      focus = "list",
      auto_close = false,
      jump = { close = false },

      -- Custom action: open file in main window while staying in explorer.
      -- Uses nvim_win_call so commands run in the target window without
      -- changing the current window — focus stays on the explorer list.
      -- Also avoids calling M.update() (which clears the search filter).
      actions = {
        -- Move focus from explorer to the main editor window.
        focus_main = function(picker)
          if picker.main and vim.api.nvim_win_is_valid(picker.main) then
            vim.api.nvim_set_current_win(picker.main)
          end
        end,
        open_and_stay = function(picker)
          local item = picker:current()
          if not item then return end
          local list_win = picker.list.win.win

          if item.dir then
            -- Toggle directory expansion without clearing the filter
            require("snacks.explorer.tree"):toggle(item.file)
            picker.list:set_target()
            picker:find({
              on_done = function()
                require("snacks.explorer.actions").reveal(picker, item.file)
              end,
            })
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(list_win) then
                vim.api.nvim_set_current_win(list_win)
              end
            end)
          else
            -- Open file in main window without moving focus away from explorer
            local buf = item.buf
            if not buf then
              local path = Snacks.picker.util.path(item)
              if not path then return end
              buf = vim.fn.bufadd(path)
            end
            vim.bo[buf].buflisted = true
            vim.api.nvim_win_call(picker.main, function()
              vim.cmd(("buffer %d"):format(buf))
              if item.pos and item.pos[1] > 0 then
                vim.api.nvim_win_set_cursor(0, { item.pos[1], item.pos[2] })
              end
            end)
            -- nvim_win_call restores current win, so focus stays in list
          end
        end,
      },

      win = {
        list = {
          keys = {
            [";"]     = { "toggle_focus", mode = { "n", "i" } },
            ["<C-h>"] = { "close", mode = { "n", "i" } },
            ["<C-j>"] = { "toggle_focus", mode = { "n", "i" } },
            ["<C-k>"] = { "toggle_focus", mode = { "n", "i" } },
            ["<C-l>"] = { "focus_main", mode = { "n", "i" } },
            ["o"]     = { "explorer_add", mode = { "n", "i" } },
            ["l"]     = { "open_and_stay" },
            ["<CR>"]  = { "open_and_stay", mode = { "n", "i" } },
            ["O"]     = { "explorer_open", mode = { "n", "i" } },
          },
        },
        input = {
          keys = {
            [";"]     = { "toggle_focus", mode = { "n", "i" } },
            ["<C-h>"] = { "close", mode = { "n", "i" } },
            ["<C-j>"] = { "toggle_focus", mode = { "n", "i" } },
            ["<C-k>"] = { "toggle_focus", mode = { "n", "i" } },
            ["<C-l>"] = { "focus_main", mode = { "n", "i" } },
          },
        },
      },
    },
  },
}
