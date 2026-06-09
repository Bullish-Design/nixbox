local result = require("loci.result")
local async = require("loci.async")

local M = {}

--- Filter values by prefix match
function M.starts_with(value, prefix)
  value = tostring(value or "")
  prefix = tostring(prefix or "")
  return prefix == "" or value:sub(1, #prefix) == prefix
end

--- Filter a table of values by prefix and sort
function M.filter_values(values, arglead)
  local out = {}
  for _, value in ipairs(values or {}) do
    if M.starts_with(value, arglead) then
      table.insert(out, value)
    end
  end
  table.sort(out)
  return out
end

--- Notify user of a Result
function M.notify_result(prefix, r)
  if r.ok then
    vim.notify(prefix, vim.log.levels.INFO)
  else
    -- Map result codes to notification levels
    local level_map = {
      invalid_input = vim.log.levels.WARN,
      not_found = vim.log.levels.WARN,
      conflict = vim.log.levels.WARN,
      integration_unavailable = vim.log.levels.WARN,
      integration_failed = vim.log.levels.WARN,
      not_initialized = vim.log.levels.ERROR,
      io_read_failed = vim.log.levels.ERROR,
      io_write_failed = vim.log.levels.ERROR,
      encode_failed = vim.log.levels.ERROR,
      decode_failed = vim.log.levels.ERROR,
      unknown = vim.log.levels.ERROR,
    }
    local level = level_map[r.code] or vim.log.levels.ERROR
    vim.notify(prefix .. ": " .. tostring(r.err), level)
  end
end

--- Run an async function with callback
function M.run_async(fn, on_done)
  async.run(fn, function(r)
    if not r.ok then
      vim.notify("LOCI: " .. tostring(r.err), vim.log.levels.ERROR)
      return
    end
    if on_done then
      on_done(r)
    end
  end)
end

--- Split argument string into tokens
function M.split_args(s)
  local out = {}
  for token in tostring(s or ""):gmatch("%S+") do
    table.insert(out, token)
  end
  return out
end

return M
