local M = {}
local state = require("sidequest.state")

function M.ensure_buf()
  local s = state.get()
  if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
    return s.buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "sidequest://main")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "sidequest"
  vim.bo[buf].modifiable = false
  vim.b[buf].sidequest = true

  s.buf = buf
  return buf
end

function M.open(opts)
  opts = opts or {}
  local s = state.get()
  local cur_win = vim.api.nvim_get_current_win()
  if not s.buf or not vim.fn.getwininfo(cur_win)[1] or vim.bo[vim.api.nvim_win_get_buf(cur_win)].filetype ~= "sidequest" then
    s.previous_win = cur_win
  end

  M.ensure_buf()
  vim.cmd("vertical botright sbuffer " .. s.buf)
  s.win = vim.api.nvim_get_current_win()

  if opts.focus == false and s.previous_win and vim.api.nvim_win_is_valid(s.previous_win) then
    vim.api.nvim_set_current_win(s.previous_win)
  end
end

function M.close()
  local s = state.get()
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_close(s.win, true)
  end
  s.win = nil
  if s.previous_win and vim.api.nvim_win_is_valid(s.previous_win) then
    vim.api.nvim_set_current_win(s.previous_win)
  end
end

function M.is_open()
  local s = state.get()
  return s.win and vim.api.nvim_win_is_valid(s.win)
end

function M.focus()
  local s = state.get()
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_set_current_win(s.win)
  end
end

return M
