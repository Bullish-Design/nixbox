-- BOUNDARY EXCEPTION: This module imports nio directly for async I/O primitives.
-- All other modules must use loci.async for nio access.
local nio = require("nio")
local result = require("loci.result")

local M = {}

local function uv_err_to_string(err)
  return tostring(err or "unknown error")
end

local function is_not_found_error(err)
  local s = uv_err_to_string(err):lower()
  return s:find("enoent", 1, true) ~= nil
    or s:find("no such file", 1, true) ~= nil
    or s:find("not found", 1, true) ~= nil
end

local function fs_error(message, err, default_code, meta)
  local merged_meta = meta or {}
  merged_meta.uv_error = uv_err_to_string(err)
  local code = is_not_found_error(err) and "not_found" or default_code
  return result.err(message .. ": " .. merged_meta.uv_error, code, merged_meta)
end

---@param filepath string
---@return string
local function parent_dir(filepath)
  return (filepath:match("^(.+)/[^/]*$")) or "."
end

---@async
---@param path string
---@return boolean
local function _exists_raw(path)
  local stat_err, stat = nio.uv.fs_stat(path)
  return stat_err == nil and stat ~= nil
end

---@async
---@param path string
---@return loci.Result value is the file content string
function M.read_file(path)
  local open_err, fd = nio.uv.fs_open(path, "r", 438)
  if open_err or not fd then
    return fs_error("open failed", open_err, "io_read_failed", { path = path })
  end

  local stat_err, stat = nio.uv.fs_fstat(fd)
  if stat_err or not stat then
    nio.uv.fs_close(fd)
    return result.err("stat failed: " .. tostring(stat_err), "io_read_failed", { path = path })
  end

  local read_err, data = nio.uv.fs_read(fd, stat.size, 0)
  nio.uv.fs_close(fd)
  if read_err then
    return result.err("read failed: " .. tostring(read_err), "io_read_failed", { path = path })
  end

  return result.ok(data or "")
end

---@async
---@param path string
---@return loci.Result<boolean>
function M.exists(path)
  if _exists_raw(path) then
    return result.ok(true)
  end
  return result.ok(false)
end

---@async
---@param path string
---@return table|nil stat
---@return string|nil error
function M.stat_raw(path)
  local stat_err, stat = nio.uv.fs_stat(path)
  if stat_err then
    return nil, tostring(stat_err)
  end
  return stat, nil
end

---@async
---@param path string
---@return loci.Result<table>
function M.stat(path)
  local stat_err, stat = nio.uv.fs_stat(path)
  if stat_err then
    return fs_error("stat failed", stat_err, "io_read_failed", { path = path })
  end
  return result.ok(stat)
end

---@async
---@param path string
---@return loci.Result<table>
function M.lstat(path)
  local stat_err, stat = nio.uv.fs_lstat(path)
  if stat_err then
    return fs_error("lstat failed", stat_err, "io_read_failed", { path = path })
  end
  return result.ok(stat)
end

---@async
---@param path string
---@return loci.Result
function M.mkdir_p(path)
  if not path or path == "" or path == "." then
    return result.ok(true)
  end

  if _exists_raw(path) then
    return result.ok(true)
  end

  local to_create = {}
  local cur = path
  while cur and cur ~= "" and cur ~= "." and not _exists_raw(cur) do
    table.insert(to_create, 1, cur)
    local next_cur = parent_dir(cur)
    if next_cur == cur then
      break
    end
    cur = next_cur
  end

  for _, dir in ipairs(to_create) do
    local mk_err = nio.uv.fs_mkdir(dir, 493)
    if mk_err and not tostring(mk_err):match("exist") then
      return result.err("mkdir failed for " .. dir .. ": " .. tostring(mk_err), "io_write_failed", { path = dir })
    end
  end

  return result.ok(true)
end

---@async
---@param path string
---@return loci.Result
function M.ensure_parent_dir(path)
  local dir = parent_dir(path)
  if dir ~= "" and dir ~= "." then
    return M.mkdir_p(dir)
  end
  return result.ok(true)
end

---@async
---@param path string
---@param content string
---@return loci.Result
function M.write_file(path, content)
  local parent_r = M.ensure_parent_dir(path)
  if not parent_r.ok then
    return parent_r
  end

  local open_err, fd = nio.uv.fs_open(path, "w", 420)
  if open_err or not fd then
    return result.err("open failed: " .. tostring(open_err), "io_write_failed", { path = path })
  end

  local write_err = nio.uv.fs_write(fd, content, 0)
  local close_err = nio.uv.fs_close(fd)
  if write_err then
    return result.err("write failed: " .. tostring(write_err), "io_write_failed", { path = path })
  end
  if close_err then
    return result.err("close failed: " .. tostring(close_err), "io_write_failed", { path = path })
  end
  return result.ok(true)
end

---@async
---@param path string
---@param content string
---@return loci.Result
function M.write_file_atomic(path, content)
  local parent_r = M.ensure_parent_dir(path)
  if not parent_r.ok then
    return parent_r
  end

  local tmp = path .. ".tmp." .. tostring(vim.uv.hrtime())
  local write_r = M.write_file(tmp, content)
  if not write_r.ok then
    return write_r
  end

  local rename_err = nio.uv.fs_rename(tmp, path)
  if rename_err then
    pcall(nio.uv.fs_unlink, tmp)
    return result.err("rename failed: " .. tostring(rename_err), "io_write_failed", { path = path })
  end

  return result.ok(true)
end

---@async
---@param old_path string
---@param new_path string
---@return loci.Result<boolean>
function M.rename(old_path, new_path)
  local rename_err = nio.uv.fs_rename(old_path, new_path)
  if rename_err then
    return fs_error("rename failed", rename_err, "io_write_failed", {
      old_path = old_path,
      new_path = new_path,
    })
  end
  return result.ok(true)
end

---@async
---@param path string
---@return string[]|nil entries
---@return string|nil error
function M.readdir_raw(path)
  local err, entries = nio.uv.fs_scandir(path)
  if err then
    return nil, tostring(err)
  end
  if not entries then
    return {}, nil
  end

  local out = {}
  while true do
    local name = vim.uv.fs_scandir_next(entries)
    if not name then
      break
    end
    table.insert(out, name)
  end
  return out, nil
end

---@async
---@param path string
---@return loci.Result<{name:string, type:string}[]>
function M.readdir(path)
  local err, entries = nio.uv.fs_scandir(path)
  if err then
    return fs_error("scandir failed", err, "io_read_failed", { path = path })
  end

  local out = {}
  if entries then
    while true do
      local name, file_type = vim.uv.fs_scandir_next(entries)
      if not name then
        break
      end
      table.insert(out, { name = name, type = file_type })
    end
  end

  return result.ok(out)
end

---@async
---@param path string
---@return loci.Result<table[]>
function M.scandir(path)
  return M.readdir(path)
end

---@async
---@param path string
---@return loci.Result
function M.unlink(path)
  local unlink_err = nio.uv.fs_unlink(path)
  if unlink_err then
    return fs_error("unlink failed", unlink_err, "io_write_failed", { path = path })
  end
  return result.ok(true)
end

---@async
---@param path string
---@return loci.Result<boolean>
function M.rmdir(path)
  local rmdir_err = nio.uv.fs_rmdir(path)
  if rmdir_err then
    return fs_error("rmdir failed", rmdir_err, "io_write_failed", { path = path })
  end
  return result.ok(true)
end

return M
