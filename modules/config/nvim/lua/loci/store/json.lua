local M = {}
local result = require("loci.result")
local fs = require("loci.store.fs")

local function read_error_is_not_found(r)
  local err = tostring(r and r.err or "")
  return err:match("ENOENT") ~= nil
    or err:match("no such file") ~= nil
    or err:match("not found") ~= nil
end

local function read_error_code(r)
  if read_error_is_not_found(r) then
    return "not_found"
  end
  return r and r.code or "io_read_failed"
end

---@async
---@param filepath string
---@return loci.Result value is the decoded Lua table
function M.read(filepath)
  local r = fs.read_file(filepath)
  if not r.ok then
    local code = read_error_code(r)
    local message
    if code == "not_found" then
      message = "file not found: " .. filepath
    else
      message = "JSON read failed: " .. filepath .. ": " .. tostring(r.err)
    end
    return result.err(message, code, {
      path = filepath,
      source_code = r.code,
      source_err = r.err,
    })
  end

  local ok, decoded = pcall(vim.json.decode, r.value)
  if not ok then
    return result.err("invalid JSON: " .. filepath .. ": " .. tostring(decoded), "decode_failed", {
      path = filepath,
      source_err = tostring(decoded),
    })
  end
  return result.ok(decoded)
end

---@async
---@param filepath string
---@param data table
---@return loci.Result
function M.write(filepath, data)
  local ok, encoded = pcall(vim.json.encode, data, { indent = "  ", sort_keys = true })
  if not ok then
    return result.err("JSON encode failed", "encode_failed", { path = filepath })
  end

  return fs.write_file_atomic(filepath, encoded .. "\n")
end

---@async
---@param filepath string
---@param lines string[]
---@return loci.Result
function M.write_lines(filepath, lines)
  local content = table.concat(lines, "\n") .. "\n"
  return fs.write_file(filepath, content)
end

return M
