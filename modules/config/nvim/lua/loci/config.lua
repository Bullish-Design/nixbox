local config_domain = require("loci.domain.config")

local M = {}

function M.defaults()
  local r = config_domain.canonical_defaults()
  if not r.ok then
    error("loci config defaults unavailable: " .. tostring(r.err))
  end
  return r.value
end

function M.setup(user_config)
  local merged = vim.tbl_deep_extend("force", M.defaults(), user_config or {})
  local valid_r = config_domain.validate(merged)
  if not valid_r.ok then
    error("loci.setup() received invalid config: " .. table.concat(valid_r.meta and valid_r.meta.errors or { valid_r.err }, ", "))
  end
  M._active = merged
  return M
end

function M.get()
  return M._active or M.defaults()
end

function M.repository_config_status()
  return nil
end

function M.reload()
  M._active = nil
  return M.get()
end

function M.reset()
  M._active = nil
end

return M
