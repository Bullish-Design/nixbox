# SKILL: TMUX Integration

Quick reference for TMUX workspace management in Cairn.

## Layout

```yaml
# cairn/tmux/.tmuxp.yaml
session_name: cairn
windows:
  - window_name: dev
    layout: main-vertical
    panes:
      - shell_command:
        - nvim
        focus: true
      - shell_command:
        - cairn up
  - window_name: preview
    panes:
      - nvim
```

## Commands

```lua
-- cairn/nvim/lua/cairn/tmux.lua
function M.open_preview(agent_id, file, line)
  local workspace = string.format('~/.cairn/workspaces/%s', agent_id)
  local cmd = string.format('nvim +%d %s/%s', line, workspace, file)
  
  -- Check if preview pane exists
  local pane = vim.fn.system('tmux list-panes -F "#{pane_title}" | grep cairn-preview')
  
  if pane == '' then
    -- Create new pane
    vim.fn.system(string.format('tmux split-window -h "%s"', cmd))
  else
    -- Update existing
    vim.fn.system(string.format('tmux send-keys -t cairn-preview "%s" Enter', cmd))
  end
end
```

## See Also
- [SPEC.md](../../SPEC.md) - UI layer
- [SKILL-NEOVIM.md](SKILL-NEOVIM.md) - Neovim integration
