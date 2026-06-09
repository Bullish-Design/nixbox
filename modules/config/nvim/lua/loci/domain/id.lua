local M = {}

local DEFAULT_SHORT_ID_LEN = 6
local CHARSET = "abcdefghijklmnopqrstuvwxyz0123456789"

local random_seeded = false

local function seed_random_once()
  if random_seeded then
    return
  end
  random_seeded = true
  math.randomseed(os.time() + tonumber(vim.uv.hrtime() % 2147483647))
end

--- Convert a human title to a URL-safe slug.
--- Lowercase, hyphens for separators, no special characters.
---@param title string|nil
---@return string
function M.slugify(title)
  if type(title) ~= "string" or title == "" then
    return ""
  end
  return title
    :lower()
    :gsub("%s+", "-")
    :gsub("[^%w%-]", "")
    :gsub("%-+", "-")
    :gsub("^%-+", "")
    :gsub("%-+$", "")
end

--- Generate a random short ID of lowercase alphanumeric characters.
---@param len? number length of the short ID (default 6)
---@return string
function M.short_id(len)
  len = tonumber(len) or DEFAULT_SHORT_ID_LEN
  if len < 1 then
    len = DEFAULT_SHORT_ID_LEN
  end
  if vim.uv and vim.uv.random then
    local ok, bytes = pcall(vim.uv.random, len)
    if ok and type(bytes) == "string" then
      local chars = {}
      for i = 1, len do
        local byte = bytes:byte(i)
        local idx = (byte % #CHARSET) + 1
        chars[#chars + 1] = CHARSET:sub(idx, idx)
      end
      return table.concat(chars)
    end
  end

  seed_random_once()
  local chars = {}
  for _ = 1, len do
    local idx = math.random(1, #CHARSET)
    chars[#chars + 1] = CHARSET:sub(idx, idx)
  end
  return table.concat(chars)
end

--- Generate a composite LOCI ID from a title.
--- Format: <slug>-<short-id>
---@param title string human-readable title
---@return string the generated ID
function M.new(title)
  local slug = M.slugify(title)
  if slug == "" then
    slug = "untitled"
  end
  return slug .. "-" .. M.short_id()
end

--- Check whether a string is a canonical LOCI ID.
--- Format: <slug>-<short-id>
--- Must contain at least one slug segment plus a final lowercase
--- alphanumeric short-id segment. Generated IDs use a 6-character suffix.
---@param id string
---@return boolean
local ID_PATTERN = "^[a-z0-9][a-z0-9%-]*%-[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]$"

function M.is_valid(id)
  if type(id) ~= "string" then
    return false
  end
  if not id:match(ID_PATTERN) then
    return false
  end

  local slug = id:sub(1, #id - 7)
  if slug:match("%-%-") or slug:match("%-$") then
    return false
  end

  return true
end


--- Generate an ISO 8601 timestamp with timezone offset.
---@return string
function M.now_iso()
  return os.date("%Y-%m-%dT%H:%M:%S%z"):gsub("(%d%d)$", ":%1")
end

return M
