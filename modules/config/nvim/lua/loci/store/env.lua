local M = {}

---@param name string
---@return string|nil
function M.getenv(name)
  if vim.in_fast_event and vim.in_fast_event() then
    return vim.uv.os_getenv(name)
  end
  return vim.env[name]
end

return M
