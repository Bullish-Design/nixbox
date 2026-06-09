-- Workspace submodes: temporary key-processing loops for repeated navigation.
-- Enter with a leader mapping, operate with h/l/j/k, exit with q/Esc/timeout.

local M = {}

local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)

local function echo(chunks)
  vim.api.nvim_echo(chunks, false, {})
end

local function clear_echo()
  vim.cmd.redraw()
  vim.api.nvim_echo({}, false, {})
end

local function feedkeys(keys)
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, false, true),
    "n",
    false
  )
end

local function run_submode(opts)
  local timeout_ms = opts.timeout_ms or 1500
  local last_input = vim.uv.now()

  if opts.message then
    echo(opts.message)
  end

  while true do
    local elapsed = vim.uv.now() - last_input
    if elapsed > timeout_ms then
      break
    end

    local key = vim.fn.getcharstr(0)

    if key == "" then
      vim.wait(20)
    else
      last_input = vim.uv.now()

      if key == "q" or key == esc then
        break
      end

      local action = opts.keys[key]
      if action then
        action()
        if opts.message then
          echo(opts.message)
        end
      else
        if opts.replay_unknown ~= false then
          feedkeys(key)
        end
        break
      end
    end
  end

  clear_echo()
end

function M.tab_nav()
  run_submode({
    timeout_ms = 1500,
    message = {
      { "Tab nav: ", "ModeMsg" },
      { "h/l", "MoreMsg" },
      { " prev/next  ", "Normal" },
      { "H/L", "MoreMsg" },
      { " first/last  ", "Normal" },
      { "q", "WarningMsg" },
      { " exit", "Normal" },
    },
    keys = {
      h = function() vim.cmd.tabprevious() end,
      l = function() vim.cmd.tabnext() end,
      H = function() vim.cmd.tabfirst() end,
      L = function() vim.cmd.tablast() end,
    },
  })
end

function M.tab_move()
  run_submode({
    timeout_ms = 1500,
    message = {
      { "Tab move: ", "ModeMsg" },
      { "h/l", "MoreMsg" },
      { " move left/right  ", "Normal" },
      { "q", "WarningMsg" },
      { " exit", "Normal" },
    },
    keys = {
      h = function() vim.cmd("-tabmove") end,
      l = function() vim.cmd("+tabmove") end,
    },
  })
end

function M.window_nav()
  run_submode({
    timeout_ms = 1500,
    message = {
      { "Window nav: ", "ModeMsg" },
      { "h/j/k/l", "MoreMsg" },
      { " focus  ", "Normal" },
      { "q", "WarningMsg" },
      { " exit", "Normal" },
    },
    keys = {
      h = function() vim.cmd.wincmd("h") end,
      j = function() vim.cmd.wincmd("j") end,
      k = function() vim.cmd.wincmd("k") end,
      l = function() vim.cmd.wincmd("l") end,
    },
  })
end

function M.window_resize()
  run_submode({
    timeout_ms = 1500,
    message = {
      { "Window resize: ", "ModeMsg" },
      { "h/l", "MoreMsg" },
      { " width  ", "Normal" },
      { "j/k", "MoreMsg" },
      { " height  ", "Normal" },
      { "=", "MoreMsg" },
      { " equalize  ", "Normal" },
      { "q", "WarningMsg" },
      { " exit", "Normal" },
    },
    keys = {
      h = function() vim.cmd("vertical resize -5") end,
      l = function() vim.cmd("vertical resize +5") end,
      j = function() vim.cmd("resize -3") end,
      k = function() vim.cmd("resize +3") end,
      ["="] = function() vim.cmd.wincmd("=") end,
    },
  })
end

return M
