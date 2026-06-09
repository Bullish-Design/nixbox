local M = {}
local result = require("loci.result")

local _nio = nil

--- Get the nio module, or nil if not available.
--- @return table|nil
local function get_nio()
  if _nio == nil then
    local ok, mod = pcall(require, "nio")
    _nio = ok and mod or false
  end
  return _nio or nil
end

--- Check if async runtime is available.
--- @return boolean
function M.available()
  return get_nio() ~= nil
end

--- Run a function in an async context.
--- The function receives no arguments and should return a loci.Result.
--- The callback receives exactly one loci.Result.
--- @param fn fun(): loci.Result
--- @param callback fun(r: loci.Result)
function M.run(fn, callback)
  local nio = get_nio()
  if not nio then
    error("loci.async.run requires nio")
    return
  end

  nio.run(fn, function(success, r)
    vim.schedule(function()
      if success then
        callback(r)
      else
        callback(result.err("async error: " .. tostring(r), "async_error"))
      end
    end)
  end)
end

--- Schedule a function to run on the main thread from within an async context.
--- Equivalent to nio.scheduler() -- use this instead of importing nio directly.
--- @async
function M.schedule()
  local nio = get_nio()
  if nio then
    nio.scheduler()
  end
end

--- Sleep for the given milliseconds.
--- @async
--- @param ms number
function M.sleep(ms)
  local nio = get_nio()
  if nio then
    nio.sleep(ms)
  end
end

return M
