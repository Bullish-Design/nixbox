local M = {}

function M.check()
  vim.health.start("sidequest")
  if pcall(require, "snacks") then vim.health.ok("snacks.nvim available") else vim.health.error("snacks.nvim not found") end
  if pcall(require, "edgy") then vim.health.ok("edgy.nvim available") else vim.health.warn("edgy.nvim not found (sidebar placement will be manual)") end
  local has_resession, resession = pcall(require, "resession")
  if has_resession then
    vim.health.ok("resession.nvim available")
    local current = resession.get_current()
    if current then vim.health.ok("Active session: " .. current) else vim.health.info("No active session") end
    vim.health.info("Saved sessions: " .. #resession.list())
  else
    vim.health.warn("resession.nvim not found (session features disabled)")
  end
  local state = require("sidequest.state").get()
  if state.initialized then vim.health.ok("Sidequest initialized") else vim.health.info("Sidequest not yet initialized (call setup() first)") end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then vim.health.ok("Buffer valid: " .. state.buf) else vim.health.info("No active buffer") end
end

return M
