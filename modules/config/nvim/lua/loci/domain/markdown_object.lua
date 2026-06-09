local result = require("loci.result")
local id_module = require("loci.domain.id")

local M = {}

---@class loci.MarkdownObject
---@field loci_id string|nil
---@field title string|nil
---@field type string
---@field status string|nil
---@field projects string[]
---@field tags string[]
---@field content_path string relative path under .loci/content/, e.g. tasks/fix.md
---@field abs_path string absolute filesystem path
---@field has_frontmatter boolean
---@field malformed_frontmatter boolean
---@field diagnostics table[]

local TYPE_MAP = {
  ["projects"] = "project",
  ["tasks"] = "task",
  ["issues"] = "issue",
  ["architecture"] = "architecture",
  ["specs"] = "spec",
  ["concept"] = "concept",
  ["daily"] = "daily",
  ["notes"] = "note",
}

local DEFAULT_TYPE = "note"

---Infer object type from content path.
---@param content_path string relative path under .loci/content/
---@return string inferred type
function M.kind_from_content_path(content_path)
  if not content_path or content_path == "" then
    return DEFAULT_TYPE
  end
  for dir, type_name in pairs(TYPE_MAP) do
    if content_path:match("^" .. dir .. "/") then
      return type_name
    end
  end
  return DEFAULT_TYPE
end

---Validate loci_id format.
---@param loci_id string|nil
---@return boolean
function M.validate_loci_id(loci_id)
  if not loci_id then
    return false
  end
  return id_module.is_valid(loci_id)
end

---Ensure values are lists.
---@param value string|string[]|nil
---@return string[]
local function as_list(value)
  if value == nil then
    return {}
  end
  if type(value) == "string" then
    return { value }
  end
  if type(value) == "table" then
    return value
  end
  return {}
end

---Normalize a markdown object summary.
---@param opts table
---@return loci.Result
function M.normalize(opts)
  opts = opts or {}

  -- Validate content_path (relative to .loci/content/, no 'content/' prefix)
  local content_path = opts.content_path
  if not content_path or content_path == "" then
    return result.err("content_path is required", "invalid_input")
  end
  if not content_path:match("%.md$") then
    return result.err("content_path must end with '.md'", "invalid_input")
  end
  if content_path:match("^%.%.") or content_path:match("^/") then
    return result.err("content_path must be relative", "invalid_input")
  end

  -- Validate loci_id if present
  if opts.loci_id and not opts.skip_loci_id_validation and not M.validate_loci_id(opts.loci_id) then
    return result.err("invalid loci_id format", "invalid_input")
  end

  -- Infer type from content_path if not provided
  local type_val = opts.type
  if not type_val or type_val == "" then
    type_val = M.kind_from_content_path(content_path)
  end

  local obj = {
    loci_id = opts.loci_id,
    title = opts.title,
    type = type_val,
    status = opts.status,
    projects = as_list(opts.projects),
    tags = as_list(opts.tags),
    content_path = content_path,
    abs_path = opts.abs_path or "",
    has_frontmatter = opts.has_frontmatter or false,
    malformed_frontmatter = opts.malformed_frontmatter or false,
    diagnostics = opts.diagnostics or {},
  }

  return result.ok(obj)
end

---Create a markdown object from parsed frontmatter.
---@param frontmatter table
---@param paths table { content_path: string, abs_path: string }
---@param opts? table
---@return loci.Result
function M.from_frontmatter(frontmatter, paths, opts)
  opts = opts or {}
  frontmatter = frontmatter or {}
  paths = paths or {}

  -- Normalize tags: strip # prefix but don't rewrite
  local tags = as_list(frontmatter.tags)
  local normalized_tags = {}
  for _, tag in ipairs(tags) do
    if type(tag) == "string" then
      if tag:sub(1, 1) == "#" then
        table.insert(normalized_tags, tag:sub(2))
      else
        table.insert(normalized_tags, tag)
      end
    end
  end

  local diagnostics = opts.diagnostics or {}
  local strict = opts.strict ~= false
  local loci_id = frontmatter.loci_id

  if not loci_id or loci_id == "" then
    table.insert(diagnostics, { code = "missing_loci_id", message = "No loci_id in frontmatter" })
    if strict then
      return result.err("missing loci_id", "invalid_frontmatter")
    end
  elseif not M.validate_loci_id(loci_id) then
    table.insert(diagnostics, { code = "invalid_loci_id", message = "Invalid loci_id format", value = loci_id })
    if strict then
      return result.err("invalid loci_id: " .. tostring(loci_id), "invalid_frontmatter")
    end
  end

  if frontmatter.projects ~= nil then
    if type(frontmatter.projects) ~= "table" then
      table.insert(diagnostics, { code = "invalid_projects", message = "projects must be an array" })
      if strict then
        return result.err("projects must be an array", "invalid_frontmatter")
      end
    else
      for i, v in ipairs(frontmatter.projects) do
        if type(v) ~= "string" then
          table.insert(diagnostics, { code = "invalid_project_entry", message = "projects entry is not a string", index = i })
          if strict then
            return result.err("projects[" .. i .. "] must be a string", "invalid_frontmatter")
          end
        end
      end
    end
  end

  if frontmatter.tags ~= nil then
    if type(frontmatter.tags) ~= "table" then
      table.insert(diagnostics, { code = "invalid_tags", message = "tags must be an array" })
      if strict then
        return result.err("tags must be an array", "invalid_frontmatter")
      end
    else
      for i, v in ipairs(frontmatter.tags) do
        if type(v) ~= "string" then
          table.insert(diagnostics, { code = "invalid_tag_entry", message = "tags entry is not a string", index = i })
          if strict then
            return result.err("tags[" .. i .. "] must be a string", "invalid_frontmatter")
          end
        end
      end
    end
  end

  return M.normalize({
    loci_id = loci_id,
    title = frontmatter.title,
    type = frontmatter.type,
    status = frontmatter.status,
    projects = frontmatter.projects,
    tags = normalized_tags,
    content_path = paths.content_path,
    abs_path = paths.abs_path,
    has_frontmatter = true,
    malformed_frontmatter = opts.malformed_frontmatter or false,
    diagnostics = diagnostics,
    skip_loci_id_validation = not strict,
  })
end

---Generate frontmatter for a new markdown file.
---@param opts table
---@return loci.Result
function M.frontmatter_for_new(opts)
  opts = opts or {}

  local title = opts.title
  local loci_id = opts.loci_id
  if not loci_id then
    if not title or title == "" then
      loci_id = id_module.new("untitled")
    else
      loci_id = id_module.new(title)
    end
  end

  if not M.validate_loci_id(loci_id) then
    return result.err("invalid loci_id format", "invalid_input")
  end

  local type_val = opts.type or DEFAULT_TYPE
  local frontmatter = {
    loci_id = loci_id,
  }

  if title and title ~= "" then
    frontmatter.title = title
  end

  frontmatter.type = type_val

  if opts.status and opts.status ~= "" then
    frontmatter.status = opts.status
  end

  local projects = as_list(opts.projects)
  if #projects > 0 then
    frontmatter.projects = projects
  end

  local tags = as_list(opts.tags)
  if #tags > 0 then
    frontmatter.tags = tags
  end

  -- Add any extra fields supplied by caller
  if opts.extra and type(opts.extra) == "table" then
    for key, value in pairs(opts.extra) do
      if not frontmatter[key] then
        frontmatter[key] = value
      end
    end
  end

  return result.ok(frontmatter)
end

return M
