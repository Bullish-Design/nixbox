-- plugin/chimera.lua
-- Minimal Chimera ghost text plugin

local M = {}

-- Configuration
local config = {
  previews_dir = vim.fn.expand('~/.chimera/previews'),
  signals_dir = vim.fn.expand('~/.chimera/signals'),
  poll_interval = 500, -- milliseconds
  namespace = vim.api.nvim_create_namespace('chimera_ghost'),
}

-- State
local active_previews = {}
local timer = nil

-- Read a preview diff file
local function read_preview(agent_id)
  local preview_path = config.previews_dir .. '/' .. agent_id .. '.diff'
  local f = io.open(preview_path, 'r')
  if not f then
    return nil
  end
  local content = f:read('*all')
  f:close()
  return content
end

-- Parse a simple diff and extract additions
local function parse_diff(diff_content)
  local changes = {}
  local current_file = nil
  local line_num = nil

  for line in diff_content:gmatch('[^\r\n]+') do
    -- File header: +++ b/path/to/file
    if line:match('^%+%+%+ b/') then
      current_file = line:gsub('^%+%+%+ b/', '')
    -- Hunk header: @@ -1,3 +1,4 @@
    elseif line:match('^@@') then
      local new_start = line:match('@@ %-%d+,%d+ %+(%d+)')
      line_num = tonumber(new_start)
    -- Addition line: +content
    elseif line:match('^%+') and not line:match('^%+%+%+') then
      if current_file and line_num then
        if not changes[current_file] then
          changes[current_file] = {}
        end
        table.insert(changes[current_file], {
          line = line_num,
          text = line:gsub('^%+', ''),
        })
        line_num = line_num + 1
      end
    -- Context line (no change)
    elseif not line:match('^%-') and not line:match('^@@') then
      if line_num then
        line_num = line_num + 1
      end
    end
  end

  return changes
end

-- Show ghost text for current buffer
local function show_ghost_text(bufnr, changes)
  -- Clear existing ghost text
  vim.api.nvim_buf_clear_namespace(bufnr, config.namespace, 0, -1)

  if not changes then
    return
  end

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local rel_path = vim.fn.fnamemodify(buf_name, ':.')

  -- Get changes for this file
  local file_changes = changes[rel_path]
  if not file_changes then
    return
  end

  -- Add virtual text for each addition
  for _, change in ipairs(file_changes) do
    local line_idx = change.line - 1 -- 0-indexed
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    if line_idx >= 0 and line_idx < line_count then
      vim.api.nvim_buf_set_extmark(bufnr, config.namespace, line_idx, 0, {
        virt_lines = {{
          {change.text, 'Comment'}
        }},
        virt_lines_above = false,
      })
    end
  end
end

-- Poll for preview updates
local function poll_previews()
  -- Get all preview files
  local handle = vim.loop.fs_scandir(config.previews_dir)
  if not handle then
    return
  end

  local current_previews = {}

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == 'file' and name:match('%.diff$') then
      local agent_id = name:gsub('%.diff$', '')
      local content = read_preview(agent_id)
      if content then
        current_previews[agent_id] = parse_diff(content)
      end
    end
  end

  active_previews = current_previews

  -- Update current buffer
  local bufnr = vim.api.nvim_get_current_buf()
  for _, changes in pairs(active_previews) do
    show_ghost_text(bufnr, changes)
  end
end

-- Accept current preview
function M.accept()
  -- Find active previews for current buffer
  local buf_name = vim.api.nvim_buf_get_name(0)
  local rel_path = vim.fn.fnamemodify(buf_name, ':.')

  for agent_id, changes in pairs(active_previews) do
    if changes[rel_path] then
      -- Write accept signal
      local signal_path = config.signals_dir .. '/accept-' .. agent_id
      local f = io.open(signal_path, 'w')
      if f then
        f:write('')
        f:close()
        print('✅ Accepted changes from ' .. agent_id)
      end
      break
    end
  end
end

-- Reject current preview
function M.reject()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local rel_path = vim.fn.fnamemodify(buf_name, ':.')

  for agent_id, changes in pairs(active_previews) do
    if changes[rel_path] then
      -- Write reject signal
      local signal_path = config.signals_dir .. '/reject-' .. agent_id
      local f = io.open(signal_path, 'w')
      if f then
        f:write('')
        f:close()
        print('❌ Rejected changes from ' .. agent_id)
      end
      break
    end
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Override config
  for k, v in pairs(opts) do
    config[k] = v
  end

  -- Ensure directories exist
  vim.fn.mkdir(config.previews_dir, 'p')
  vim.fn.mkdir(config.signals_dir, 'p')

  -- Start polling timer
  timer = vim.loop.new_timer()
  timer:start(0, config.poll_interval, vim.schedule_wrap(poll_previews))

  -- Setup keymaps
  vim.keymap.set('n', '<leader>a', M.accept, { desc = 'Accept Chimera changes' })
  vim.keymap.set('n', '<leader>r', M.reject, { desc = 'Reject Chimera changes' })

  -- Autocommands to update on buffer changes
  vim.api.nvim_create_autocmd({'BufEnter', 'BufWritePost'}, {
    callback = function()
      vim.schedule(poll_previews)
    end,
  })
end

return M
