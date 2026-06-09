local result = require("loci.result")
local id = require("loci.domain.id")

local M = {}

-- ============================================================================
-- Haunt Validation Helpers
-- ============================================================================

---Check if a string is a valid Haunt context name.
---@param name string
---@return boolean
local function is_valid_context_name(name)
  if type(name) ~= "string" or name == "" or #name > 64 then
    return false
  end
  if name:match("[^a-z0-9%-]") then
    return false
  end
  if name:match("^%-") or name:match("%-$") then
    return false
  end
  return true
end

---Normalize and validate a Haunt context name (slugify + validate).
---@param name string
---@return loci.Result<string>
function M.normalize_context_name(name)
  local slug = id.slugify(name)
  if slug == "" then
    return result.err("Haunt context name is required", "invalid_input")
  end
  if not is_valid_context_name(slug) then
    return result.err("invalid Haunt context name: " .. tostring(name), "invalid_input")
  end
  return result.ok(slug)
end

function M.validate_context_name(name)
  if not is_valid_context_name(name) then
    return result.err("invalid Haunt context name: " .. tostring(name), "invalid_input", {
      name = name,
    })
  end
  return result.ok(name)
end

---Check whether a workspace matches the current active workspace ID.
---@param workspace_id string
---@param current_workspace_id string|nil
---@return boolean
function M.is_active_workspace(workspace_id, current_workspace_id)
  return current_workspace_id == workspace_id
end

---Get all Haunt context names from a workspace, sorted alphabetically.
---@param workspace table
---@return string[]
function M.sorted_context_names(workspace)
  local names = {}
  for name, _ in pairs(workspace.haunt.contexts or {}) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

---Validate the haunt section of a workspace.
---@param workspace table
---@return loci.Result<boolean>
function M.validate_haunt_state(workspace)
  if type(workspace.haunt) ~= "table" then
    return result.err("workspace haunt table is required", "invalid_input")
  end
  if not is_valid_context_name(workspace.haunt.active) then
    return result.err("workspace haunt active context is invalid", "invalid_input")
  end
  if type(workspace.haunt.contexts) ~= "table" then
    return result.err("workspace haunt contexts table is required", "invalid_input")
  end
  if not workspace.haunt.contexts[workspace.haunt.active] then
    return result.err("workspace active haunt context must exist", "invalid_input")
  end

  local seen_dirs = {}
  local count = 0
  for name, context in pairs(workspace.haunt.contexts) do
    count = count + 1
    if not is_valid_context_name(name) then
      return result.err("invalid haunt context name: " .. tostring(name), "invalid_input")
    end
    if type(context) ~= "table" or type(context.data_dir) ~= "string" then
      return result.err("haunt context missing data_dir: " .. name, "invalid_input")
    end
    if seen_dirs[context.data_dir] then
      return result.err("duplicate haunt data_dir: " .. context.data_dir, "conflict")
    end
    seen_dirs[context.data_dir] = true
  end

  if count == 0 then
    return result.err("workspace must have at least one haunt context", "invalid_input")
  end

  return result.ok(true)
end

-- ============================================================================
-- Trail Validation Helpers
-- ============================================================================

---Validate a Trail logical name (lowercase alphanumeric, hyphen, underscore).
---@param value string
---@return loci.Result<string>
function M.validate_logical_name(value)
  if type(value) ~= "string" or value == "" then
    return result.err("Trail name is required", "invalid_input")
  end
  if not value:match("^[a-z0-9_-]+$") then
    return result.err(
      "Trail name must contain only lowercase letters, numbers, hyphens, and underscores",
      "invalid_input"
    )
  end
  return result.ok(value)
end

return M
