# SKILL: Neovim Plugin Development

Quick reference for Cairn Neovim plugin development.

## Plugin Structure

```
cairn/nvim/
├── plugin/cairn.lua       # Entry point
└── lua/cairn/
    ├── init.lua           # Main module
    ├── watcher.lua        # FS event watching
    ├── tmux.lua           # TMUX integration
    ├── ghost.lua          # Ghost text rendering
    └── preview.lua        # Preview management
```

## Main Plugin

```lua
-- plugin/cairn.lua
local M = {}

function M.setup(opts)
  require('cairn').setup(opts)
end

return M
```

## FS Watcher

```lua
-- lua/cairn/watcher.lua
local function watch_previews()
  local handle = vim.loop.new_fs_event()
  handle:start(
    vim.fn.expand('~/.cairn/previews'),
    {},
    vim.schedule_wrap(function(err, filename, events)
      if filename and filename:match('%.diff$') then
        local agent_id = filename:gsub('%.diff$', '')
        update_preview(agent_id)
      end
    end)
  )
end
```

## Commands

```lua
vim.api.nvim_create_user_command('CairnQueue', function(opts)
  queue_task(opts.args)
end, { nargs = '+' })

vim.api.nvim_create_user_command('CairnAccept', accept, {})
vim.api.nvim_create_user_command('CairnReject', reject, {})
```

## See Also
- [SKILL-TMUX.md](SKILL-TMUX.md) - TMUX integration
- [SPEC.md](../../SPEC.md) - UI layer
