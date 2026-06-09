---@class loci.Result
---@field ok boolean
---@field value? any
---@field err? string
---@field code? string
---@field meta? table

local M = {}

---@param value? any
---@param meta? table
---@return loci.Result
function M.ok(value, meta)
  return { ok = true, value = value, meta = meta }
end

---@param err string
---@param code? string
---@param meta? table
---@return loci.Result
function M.err(err, code, meta)
  return { ok = false, err = err, code = code, meta = meta }
end

---@param r any
---@return boolean
function M.is_ok(r)
  return type(r) == "table" and r.ok == true
end

---@param r any
---@return any|nil value
---@return string|nil error message
function M.unwrap(r)
  if M.is_ok(r) then
    return r.value, nil
  end
  return nil, (type(r) == "table" and r.err) or "unknown error"
end

return M
