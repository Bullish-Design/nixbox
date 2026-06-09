local M = {}
local result = require("loci.result")
local env = require("loci.store.env")

local cached_root = nil
local cached_env_value = nil
local cached_config_root = nil

---@param name string
---@return string|nil
---@param path string
---@return string
local function normalize_path(path)
  if path:sub(1, 2) == "~/" then
    local home = env.getenv("HOME")
    if home and home ~= "" then
      path = home .. path:sub(2)
    end
  end
  return vim.fs.normalize(path)
end

---@param start string
---@return string|nil
local function find_git_root(start)
  local dir = normalize_path(start)
  while dir and dir ~= "" do
    local stat = vim.uv.fs_stat(dir .. "/.git")
    if stat then
      return dir
    end
    local parent = dir:match("^(.+)/[^/]+$")
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
  return nil
end

---@param rel string|nil
---@return string|nil
---@return string|nil
local function validate_relative(rel)
  if rel == nil or rel == "" then
    return nil, nil
  end
  if type(rel) ~= "string" then
    return nil, "relative path must be a string"
  end
  if rel:match("%z") then
    return nil, "relative path contains null byte"
  end
  if rel:match("^/") or rel:match("^%a:[/\\]") then
    return nil, "absolute paths are not allowed"
  end
  if rel:match("\\") then
    return nil, "backslashes are not allowed in stored paths"
  end
  for part in rel:gmatch("[^/]+") do
    if part == ".." then
      return nil, "path traversal is not allowed"
    end
  end
  return rel, nil
end

---@param base string
---@param rel? string
---@return loci.Result<string>
local function safe_join(base, rel)
  local safe_rel, err = validate_relative(rel)
  if err then
    return result.err(err, "invalid_input", {
      base = base,
      rel = rel,
    })
  end
  if not safe_rel then
    return result.ok(base)
  end
  return result.ok(base .. "/" .. safe_rel)
end

---@param base string
---@param rel? string
---@return string
local function must_unwrap(joined_r)
  if not joined_r.ok then
    error(joined_r.err)
  end
  return joined_r.value
end

---@return string absolute path to repository root
function M.repository_root()
  local env_root = env.getenv("LOCI_PROJECT_ROOT")
  local cfg = require("loci.config").get()
  local configured = type(cfg.repository) == "table" and cfg.repository.root or nil

  if cached_root and cached_env_value == env_root and cached_config_root == configured then
    return cached_root
  end

  if env_root and env_root ~= "" then
    cached_root = normalize_path(env_root)
    cached_env_value = env_root
    cached_config_root = configured
    return cached_root
  end

  -- Handle vim.NIL or other non-string values
  if configured and type(configured) == "string" and configured ~= "" then
    cached_root = normalize_path(configured)
    cached_env_value = env_root
    cached_config_root = configured
    return cached_root
  end

  local cwd = vim.uv.cwd()
  local git_root = find_git_root(cwd)
  if git_root then
    cached_root = git_root
    cached_env_value = env_root
    cached_config_root = configured
    return cached_root
  end

  cached_root = normalize_path(cwd)
  cached_env_value = env_root
  cached_config_root = configured
  return cached_root
end

---@return string
function M.loci_root()
  return M.repository_root() .. "/.loci"
end

---@param rel? string relative path within content/
---@return string
function M.content_path(rel)
  local joined = safe_join(M.loci_root() .. "/content", rel)
  if not joined.ok then
    return joined
  end
  return result.ok(joined.value)
end

function M.must_content_path(rel)
  return must_unwrap(M.content_path(rel))
end

---@param abs_path string
---@return string|nil
function M.content_relative(abs_path)
  local content_root = normalize_path(M.must_content_path())
  local normalized = normalize_path(abs_path)
  if normalized == content_root then
    return ""
  end
  local prefix = content_root .. "/"
  if normalized:sub(1, #prefix) == prefix then
    return normalized:sub(#prefix + 1)
  end
  return nil
end

---@param abs_path string
---@return boolean
function M.is_under_content(abs_path)
  return M.content_relative(abs_path) ~= nil
end

---@param rel? string relative path within graph/
---@return string
function M.graph_path(rel)
  return safe_join(M.loci_root() .. "/graph", rel)
end

function M.must_graph_path(rel)
  return must_unwrap(M.graph_path(rel))
end

---@param filename? string index filename (e.g., "projects.json")
---@return string
function M.index_path(filename)
  return safe_join(M.loci_root() .. "/indexes", filename)
end

function M.must_index_path(filename)
  return must_unwrap(M.index_path(filename))
end

---@param rel? string relative path within integrations/
---@return string
function M.integration_path(rel)
  return safe_join(M.loci_root() .. "/integrations", rel)
end

function M.must_integration_path(rel)
  return must_unwrap(M.integration_path(rel))
end

---@return boolean
function M.is_initialized()
  local file_stat = vim.uv.fs_stat(M.loci_root() .. "/repository.json")
  return file_stat ~= nil and file_stat.type == "file"
end

---@param rel string
---@return string
function M.abs(rel)
  return safe_join(M.repository_root(), rel)
end

function M.must_abs(rel)
  return must_unwrap(M.abs(rel))
end

---@param abs_path string
---@return string|nil
function M.relative(abs_path)
  local root = M.repository_root()
  local normalized = normalize_path(abs_path)
  if normalized == root then
    return "."
  end
  local prefix = root .. "/"
  if normalized:sub(1, #prefix) == prefix then
    return normalized:sub(#prefix + 1)
  end
  return nil
end

function M.reset()
  cached_root = nil
  cached_env_value = nil
  cached_config_root = nil
end

return M
