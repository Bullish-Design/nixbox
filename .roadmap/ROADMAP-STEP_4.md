# Stage 4: UI Layer - Neovim & TMUX

**Goal**: Developer-friendly interface for reviewing and accepting agent work

**Status**: ⚪ Not Started
**Estimated Duration**: 2-3 weeks
**Dependencies**: Stage 3 (Orchestrator core working headlessly)

---

## Overview

This stage builds the user interface layer - the Neovim plugin and TMUX integration that developers interact with. The orchestrator from Stage 3 already works; now we add the ergonomic interface that makes it delightful to use.

The key insight: **The UI is just a view layer over the orchestrator. All logic lives in Stage 3.**

---

## Deliverables

### 1. Neovim Plugin Structure

**Directory**: `cairn/nvim/`

```
cairn/nvim/
├── plugin/
│   └── cairn.lua          # Plugin initialization
├── lua/
│   └── cairn/
│       ├── init.lua       # Main module
│       ├── commands.lua   # User commands
│       ├── tmux.lua       # TMUX integration
│       ├── ghost.lua      # Ghost text display
│       ├── watcher.lua    # File watchers for updates
│       └── config.lua     # Configuration
└── doc/
    └── cairn.txt          # Vim documentation
```

### 2. Plugin Initialization

**File**: `cairn/nvim/plugin/cairn.lua`

**Requirements**:
Bootstrap the plugin and set up commands.

```lua
-- cairn/nvim/plugin/cairn.lua

if vim.g.loaded_cairn then
  return
end
vim.g.loaded_cairn = 1

-- Setup plugin
require('cairn').setup()

-- Create commands
vim.api.nvim_create_user_command('CairnQueue', function(opts)
  require('cairn.commands').queue(opts.args, opts.bang)
end, { nargs = '+', bang = true })

vim.api.nvim_create_user_command('CairnAccept', function()
  require('cairn.commands').accept()
end, {})

vim.api.nvim_create_user_command('CairnReject', function()
  require('cairn.commands').reject()
end, {})

vim.api.nvim_create_user_command('CairnPreview', function()
  require('cairn.commands').preview()
end, {})

vim.api.nvim_create_user_command('CairnListTasks', function()
  require('cairn.commands').list_tasks()
end, {})

vim.api.nvim_create_user_command('CairnListAgents', function()
  require('cairn.commands').list_agents()
end, {})

vim.api.nvim_create_user_command('CairnSelectAgent', function(opts)
  require('cairn.commands').select_agent(opts.args)
end, { nargs = 1 })
```

**Contracts**:
```lua
-- Contract 1: Commands are registered
function test_commands_registered()
  local commands = vim.api.nvim_get_commands({})
  assert(commands.CairnQueue ~= nil)
  assert(commands.CairnAccept ~= nil)
  assert(commands.CairnReject ~= nil)
  assert(commands.CairnPreview ~= nil)
end
```

---

### 3. Main Module

**File**: `cairn/nvim/lua/cairn/init.lua`

**Requirements**:
Main module with setup function.

```lua
local M = {}

M.config = {
  cairn_home = vim.fn.expand('~/.cairn'),
  preview_same_location = true,  -- Open preview at same file:line
  auto_reload = false,            -- Conservative: don't auto-reload
  ghost_text = true,              -- Show ghost text suggestions
  keymaps = {
    accept = '<leader>a',
    reject = '<leader>r',
    preview = '<leader>p',
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Setup watchers
  require('cairn.watcher').setup(M.config)

  -- Setup keymaps
  if M.config.keymaps.accept then
    vim.keymap.set('n', M.config.keymaps.accept, function()
      require('cairn.commands').accept()
    end, { desc = 'Accept Cairn changes' })
  end

  if M.config.keymaps.reject then
    vim.keymap.set('n', M.config.keymaps.reject, function()
      require('cairn.commands').reject()
    end, { desc = 'Reject Cairn changes' })
  end

  if M.config.keymaps.preview then
    vim.keymap.set('n', M.config.keymaps.preview, function()
      require('cairn.commands').preview()
    end, { desc = 'Open Cairn preview' })
  end

  -- Start background watcher
  require('cairn.watcher').start()
end

return M
```

**Contracts**:
```lua
-- Contract 1: Setup merges config
function test_setup_merges_config()
  local cairn = require('cairn')
  cairn.setup({
    cairn_home = '/custom/path',
    preview_same_location = false,
  })

  assert(cairn.config.cairn_home == '/custom/path')
  assert(cairn.config.preview_same_location == false)
  assert(cairn.config.ghost_text == true)  -- Default preserved
end

-- Contract 2: Keymaps are set
function test_keymaps_set()
  local cairn = require('cairn')
  cairn.setup()

  local keymaps = vim.api.nvim_get_keymap('n')
  local accept_map = vim.tbl_filter(function(m)
    return m.lhs == '<leader>a'
  end, keymaps)

  assert(#accept_map == 1)
end
```

---

### 4. Commands Implementation

**File**: `cairn/nvim/lua/cairn/commands.lua`

**Requirements**:
Implement all user-facing commands.

```lua
local M = {}

local function get_cairn_home()
  local config = require('cairn').config
  return config.cairn_home
end

local function get_latest_agent()
  local state_file = get_cairn_home() .. '/state/latest_agent'
  local f = io.open(state_file, 'r')
  if not f then return nil end
  local agent_id = f:read('*line')
  f:close()
  return agent_id
end

function M.queue(task, priority)
  -- Write task to queue file
  local queue_file = get_cairn_home() .. '/queue/tasks.json'
  local tasks = vim.fn.filereadable(queue_file) == 1
    and vim.fn.json_decode(vim.fn.readfile(queue_file))
    or {}

  table.insert(tasks, {
    task = task,
    priority = priority and 'HIGH' or 'NORMAL',
    created_at = os.time(),
  })

  vim.fn.writefile(vim.fn.json_encode(tasks), queue_file)

  vim.notify('Task queued: ' .. task, vim.log.levels.INFO)
end

function M.accept()
  local agent_id = get_latest_agent()
  if not agent_id then
    vim.notify('No agent to accept', vim.log.levels.WARN)
    return
  end

  -- Write accept signal
  local signal_file = get_cairn_home() .. '/signals/accept-' .. agent_id
  local f = io.open(signal_file, 'w')
  f:close()

  vim.notify('Accepting agent ' .. agent_id:sub(1, 8), vim.log.levels.INFO)
end

function M.reject()
  local agent_id = get_latest_agent()
  if not agent_id then
    vim.notify('No agent to reject', vim.log.levels.WARN)
    return
  end

  -- Write reject signal
  local signal_file = get_cairn_home() .. '/signals/reject-' .. agent_id
  local f = io.open(signal_file, 'w')
  f:close()

  vim.notify('Rejecting agent ' .. agent_id:sub(1, 8), vim.log.levels.INFO)
end

function M.preview()
  local agent_id = get_latest_agent()
  if not agent_id then
    vim.notify('No agent to preview', vim.log.levels.WARN)
    return
  end

  -- Get current file and line
  local current_file = vim.fn.expand('%:.')
  local current_line = vim.fn.line('.')

  -- Open preview in TMUX
  require('cairn.tmux').open_preview(agent_id, current_file, current_line)
end

function M.list_tasks()
  local queue_file = get_cairn_home() .. '/queue/tasks.json'
  if vim.fn.filereadable(queue_file) == 0 then
    vim.notify('No tasks in queue', vim.log.levels.INFO)
    return
  end

  local tasks = vim.fn.json_decode(vim.fn.readfile(queue_file))

  local lines = {'Queued Tasks:', ''}
  for i, task in ipairs(tasks) do
    table.insert(lines, string.format('%d. [%s] %s', i, task.priority, task.task))
  end

  vim.api.nvim_echo({lines}, false, {})
end

function M.list_agents()
  local state_file = get_cairn_home() .. '/state/active_agents.json'
  if vim.fn.filereadable(state_file) == 0 then
    vim.notify('No active agents', vim.log.levels.INFO)
    return
  end

  local agents = vim.fn.json_decode(vim.fn.readfile(state_file))

  local lines = {'Active Agents:', ''}
  for agent_id, info in pairs(agents) do
    table.insert(lines, string.format(
      '%s: [%s] %s',
      agent_id:sub(1, 8),
      info.state,
      info.task
    ))
  end

  vim.api.nvim_echo({lines}, false, {})
end

function M.select_agent(agent_id)
  local state_file = get_cairn_home() .. '/state/latest_agent'
  local f = io.open(state_file, 'w')
  f:write(agent_id)
  f:close()

  vim.notify('Selected agent ' .. agent_id:sub(1, 8), vim.log.levels.INFO)
end

return M
```

**Contracts**:
```lua
-- Contract 1: Queue creates task file
function test_queue_creates_task()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir .. '/queue', 'p')

  require('cairn').setup({ cairn_home = tmpdir })
  require('cairn.commands').queue('Test task', false)

  local queue_file = tmpdir .. '/queue/tasks.json'
  assert(vim.fn.filereadable(queue_file) == 1)

  local tasks = vim.fn.json_decode(vim.fn.readfile(queue_file))
  assert(#tasks == 1)
  assert(tasks[1].task == 'Test task')
end

-- Contract 2: Accept creates signal file
function test_accept_creates_signal()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir .. '/signals', 'p')
  vim.fn.mkdir(tmpdir .. '/state', 'p')

  -- Set latest agent
  local state_file = tmpdir .. '/state/latest_agent'
  local f = io.open(state_file, 'w')
  f:write('agent-123')
  f:close()

  require('cairn').setup({ cairn_home = tmpdir })
  require('cairn.commands').accept()

  local signal_file = tmpdir .. '/signals/accept-agent-123'
  assert(vim.fn.filereadable(signal_file) == 1)
end

-- Contract 3: Preview opens TMUX pane
function test_preview_opens_tmux()
  -- Mock TMUX calls
  local tmux_called = false
  local orig_open = require('cairn.tmux').open_preview

  require('cairn.tmux').open_preview = function(...)
    tmux_called = true
  end

  require('cairn.commands').preview()

  assert(tmux_called == true)

  require('cairn.tmux').open_preview = orig_open
end
```

---

### 5. TMUX Integration

**File**: `cairn/nvim/lua/cairn/tmux.lua`

**Requirements**:
Open preview workspace in TMUX pane.

```lua
local M = {}

function M.open_preview(agent_id, file_path, line_num)
  local config = require('cairn').config
  local workspace = config.cairn_home .. '/workspaces/' .. agent_id

  if vim.fn.isdirectory(workspace) == 0 then
    vim.notify('Workspace not materialized yet', vim.log.levels.WARN)
    return
  end

  -- Build target file path
  local target_file = workspace .. '/' .. file_path
  if vim.fn.filereadable(target_file) == 0 then
    -- Fallback to opening workspace root
    target_file = workspace
  end

  -- Build nvim command
  local nvim_cmd
  if vim.fn.filereadable(target_file) == 1 then
    nvim_cmd = string.format('nvim +%d %s', line_num, vim.fn.shellescape(target_file))
  else
    nvim_cmd = string.format('nvim %s', vim.fn.shellescape(target_file))
  end

  -- Check if preview pane exists
  local preview_exists = vim.fn.system('tmux list-panes -F "#{pane_title}" | grep "cairn-preview"')

  if preview_exists ~= '' then
    -- Send command to existing pane
    vim.fn.system(string.format(
      'tmux send-keys -t cairn-preview C-z "%s" Enter',
      nvim_cmd
    ))
  else
    -- Create new preview pane
    vim.fn.system(string.format(
      'tmux split-window -h -c %s "tmux select-pane -T cairn-preview; %s"',
      vim.fn.shellescape(workspace),
      nvim_cmd
    ))
  end

  vim.notify('Preview opened in TMUX', vim.log.levels.INFO)
end

function M.close_preview()
  vim.fn.system('tmux kill-pane -t cairn-preview')
end

return M
```

**Contracts**:
```lua
-- Contract 1: Creates TMUX pane if none exists
function test_creates_tmux_pane()
  -- Mock tmux commands
  local commands = {}

  vim.fn.system = function(cmd)
    table.insert(commands, cmd)
    if cmd:match('list%-panes') then
      return ''  -- No panes exist
    end
    return ''
  end

  require('cairn.tmux').open_preview('agent-123', 'test.py', 10)

  -- Should have called split-window
  local split_cmd = vim.tbl_filter(function(cmd)
    return cmd:match('split%-window')
  end, commands)

  assert(#split_cmd > 0)
end

-- Contract 2: Uses existing pane if available
function test_uses_existing_pane()
  local commands = {}

  vim.fn.system = function(cmd)
    table.insert(commands, cmd)
    if cmd:match('list%-panes') then
      return 'cairn-preview'  -- Pane exists
    end
    return ''
  end

  require('cairn.tmux').open_preview('agent-123', 'test.py', 10)

  -- Should have called send-keys
  local send_cmd = vim.tbl_filter(function(cmd)
    return cmd:match('send%-keys')
  end, commands)

  assert(#send_cmd > 0)
end

-- Contract 3: Opens at correct file:line
function test_opens_at_correct_location()
  local commands = {}

  vim.fn.system = function(cmd)
    table.insert(commands, cmd)
    return ''
  end

  require('cairn.tmux').open_preview('agent-123', 'main.py', 42)

  -- Check that nvim +42 main.py is in command
  local nvim_cmd = table.concat(commands, ' ')
  assert(nvim_cmd:match('nvim %+42'))
end
```

---

### 6. Ghost Text Display

**File**: `cairn/nvim/lua/cairn/ghost.lua`

**Requirements**:
Show agent suggestions as ghost text (virtual lines).

```lua
local M = {}

local ns = vim.api.nvim_create_namespace('cairn_ghost')

function M.show(bufnr, agent_id, changes)
  -- Clear existing ghost text
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local rel_path = vim.fn.fnamemodify(buf_name, ':.')

  local file_changes = changes[rel_path]
  if not file_changes then
    return
  end

  -- Show virtual lines for additions
  for _, change in ipairs(file_changes) do
    if change.type == 'add' then
      vim.api.nvim_buf_set_extmark(bufnr, ns, change.line - 1, 0, {
        virt_lines = {{
          {string.format(' + %s', change.text), 'Comment'}
        }},
        virt_lines_above = false,
      })
    end
  end

  -- Show notification
  vim.notify(
    string.format('Agent %s has suggestions (press %s to preview)',
      agent_id:sub(1, 8),
      require('cairn').config.keymaps.preview or '<leader>p'
    ),
    vim.log.levels.INFO
  )
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return M
```

**Contracts**:
```lua
-- Contract 1: Shows virtual lines for additions
function test_shows_virtual_lines()
  local bufnr = vim.api.nvim_create_buf(false, true)

  local changes = {
    ['test.py'] = {
      { type = 'add', line = 5, text = 'print("hello")' }
    }
  }

  require('cairn.ghost').show(bufnr, 'agent-123', changes)

  local extmarks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    require('cairn.ghost').ns,
    0,
    -1,
    { details = true }
  )

  assert(#extmarks > 0)
end

-- Contract 2: Clear removes ghost text
function test_clear_removes_ghost_text()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Add ghost text
  local changes = {
    ['test.py'] = {
      { type = 'add', line = 5, text = 'print("hello")' }
    }
  }
  require('cairn.ghost').show(bufnr, 'agent-123', changes)

  -- Clear
  require('cairn.ghost').clear(bufnr)

  local extmarks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    require('cairn.ghost').ns,
    0,
    -1,
    {}
  )

  assert(#extmarks == 0)
end
```

---

### 7. File Watcher

**File**: `cairn/nvim/lua/cairn/watcher.lua`

**Requirements**:
Watch for agent state changes and update UI.

```lua
local M = {}

local timer = nil

function M.setup(config)
  -- Store config
  M.config = config
end

function M.start()
  if timer then
    return  -- Already running
  end

  timer = vim.loop.new_timer()
  timer:start(500, 500, vim.schedule_wrap(function()
    M.check_for_updates()
  end))
end

function M.stop()
  if timer then
    timer:stop()
    timer = nil
  end
end

function M.check_for_updates()
  local state_file = M.config.cairn_home .. '/state/active_agents.json'

  if vim.fn.filereadable(state_file) == 0 then
    return
  end

  local agents = vim.fn.json_decode(vim.fn.readfile(state_file))

  for agent_id, info in pairs(agents) do
    if info.state == 'REVIEWING' then
      -- Load changes and show ghost text
      local preview_file = M.config.cairn_home .. '/previews/' .. agent_id .. '.diff'
      if vim.fn.filereadable(preview_file) == 1 then
        local diff_content = vim.fn.readfile(preview_file)
        local changes = M.parse_diff(diff_content)

        -- Show ghost text in current buffer
        local bufnr = vim.api.nvim_get_current_buf()
        require('cairn.ghost').show(bufnr, agent_id, changes)
      end
    end
  end
end

function M.parse_diff(diff_lines)
  -- Parse unified diff format
  local changes = {}
  local current_file = nil

  for _, line in ipairs(diff_lines) do
    local file_match = line:match('^%+%+%+ b/(.+)$')
    if file_match then
      current_file = file_match
      changes[current_file] = {}
    elseif line:match('^%+') and not line:match('^%+%+%+') then
      if current_file then
        table.insert(changes[current_file], {
          type = 'add',
          text = line:sub(2),  -- Remove leading +
        })
      end
    end
  end

  return changes
end

return M
```

---

## Test Suite Requirements

### Unit Tests (60% of tests)
**Tool**: [Plenary.nvim](https://github.com/nvim-lua/plenary.nvim) test harness

- Test each command function
- Test TMUX integration (mocked)
- Test ghost text rendering
- Test diff parsing
- Test configuration merging

### Integration Tests (30% of tests)
- Test commands create correct files
- Test watcher detects changes
- Test ghost text appears when agent finishes
- Test preview opens in TMUX (requires TMUX)

### Manual Tests (10% of tests)
- User acceptance testing
- Visual inspection of ghost text
- TMUX layout testing
- Keybinding ergonomics

---

## Exit Criteria

### Functionality
- [ ] :CairnQueue works, creates task file
- [ ] :CairnAccept works, creates signal file
- [ ] :CairnReject works, creates signal file
- [ ] :CairnPreview opens TMUX pane with workspace
- [ ] Ghost text appears when agent reaches REVIEWING state
- [ ] Keybindings work (<leader>a, <leader>r, <leader>p)

### User Experience
- [ ] Preview opens at same file:line as current buffer
- [ ] Ghost text is visually distinct but not distracting
- [ ] Notifications are informative but not spammy
- [ ] TMUX pane is reused if already open

### Performance
- [ ] Preview opens in < 100ms
- [ ] Ghost text updates in < 50ms
- [ ] No UI lag or blocking

### Testing
- [ ] 80%+ test coverage (Lua code)
- [ ] All unit tests pass
- [ ] Integration tests pass

### Documentation
- [ ] :help cairn works
- [ ] All commands documented
- [ ] Keybindings documented
- [ ] Configuration options documented

---

## Success Metrics

At the end of Stage 4, a developer should be able to:

1. **Queue a task**: `:CairnQueue "Add docstrings"`
2. **See ghost text**: Virtual lines appear when agent finishes
3. **Preview changes**: `<leader>p` opens TMUX with agent workspace
4. **Test changes**: Switch to preview pane, run tests, check builds
5. **Accept or reject**: `<leader>a` or `<leader>r`

**The full developer workflow should be smooth and ergonomic.**

**If all exit criteria are met, proceed to Stage 5.**
