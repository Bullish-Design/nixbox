local result = require("loci.result")
local path = require("loci.store.path")
local fs = require("loci.store.fs")
local config = require("loci.config")
local async = require("loci.async")

local M = {}

-- ============================================================================
-- Configuration and Availability
-- ============================================================================

---Check if bases.nvim is available
function M.available()
  return pcall(require, "bases")
end

---Get health status of bases integration
function M.health()
  local cfg = config.get()
  local enabled = cfg.integrations and cfg.integrations.bases ~= false
  return {
    name = "bases",
    enabled = enabled,
    available = M.available(),
    detail = M.available() and "bases.nvim loaded" or "bases.nvim not loaded; generated .base files can still be written",
    output_dir = path.must_content_path("bases"),
  }
end

---Get output directory for generated base files
function M.output_dir()
  return path.must_content_path("bases")
end

-- ============================================================================
-- Default Base Specifications
-- ============================================================================

---Get default base file specifications
---@param opts? table
---@return table[]
function M.default_specs(opts)
  opts = opts or {}
  return {
    {
      filename = "loci-projects.base",
      description = "LOCI project notes",
      filters = { ["and"] = { "note.type == \"project\"" } },
      views = {
        {
          type = "table",
          name = "Projects",
          filters = { ["and"] = { "note.type == \"project\"" } },
          order = { "file.name", "title", "status", "tags" },
          sort = {
            { column = "status", direction = "ASC" },
            { column = "title", direction = "ASC" },
          },
        },
      },
    },
    {
      filename = "loci-tasks.base",
      description = "LOCI task Markdown objects",
      filters = { ["and"] = { "note.type == \"task\"" } },
      views = {
        {
          type = "table",
          name = "Tasks",
          filters = { ["and"] = { "note.type == \"task\"" } },
          order = { "file.name", "title", "status", "priority", "due", "projects", "tags" },
          sort = {
            { column = "status", direction = "ASC" },
            { column = "due", direction = "ASC" },
            { column = "file.name", direction = "ASC" },
          },
        },
        {
          type = "table",
          name = "Open Tasks",
          filters = { ["and"] = { "note.type == \"task\"", "status != \"done\"" } },
          order = { "file.name", "title", "status", "priority", "due", "projects" },
          sort = {
            { column = "due", direction = "ASC" },
            { column = "priority", direction = "DESC" },
          },
        },
      },
    },
    {
      filename = "loci-issues.base",
      description = "LOCI issue Markdown objects",
      filters = { ["and"] = { "note.type == \"issue\"" } },
      views = {
        {
          type = "table",
          name = "Issues",
          filters = { ["and"] = { "note.type == \"issue\"" } },
          order = { "file.name", "title", "status", "projects", "tags" },
          sort = {
            { column = "status", direction = "ASC" },
            { column = "title", direction = "ASC" },
          },
        },
      },
    },
    {
      filename = "loci-notes.base",
      description = "LOCI non-task knowledge notes",
      filters = {
        ["or"] = {
          "note.type == \"note\"",
          "note.type == \"architecture\"",
          "note.type == \"spec\"",
          "note.type == \"concept\"",
          "note.type == \"implementation\"",
          "note.type == \"review\"",
        },
      },
      views = {
        {
          type = "table",
          name = "Knowledge Notes",
          filters = {
            ["or"] = {
              "note.type == \"note\"",
              "note.type == \"architecture\"",
              "note.type == \"spec\"",
              "note.type == \"concept\"",
              "note.type == \"implementation\"",
              "note.type == \"review\"",
            },
          },
          order = { "file.name", "title", "type", "projects", "tags" },
          sort = {
            { column = "type", direction = "ASC" },
            { column = "title", direction = "ASC" },
          },
        },
      },
    },
    {
      filename = "loci-daily.base",
      description = "LOCI daily notes",
      filters = { ["and"] = { "note.type == \"daily\"" } },
      views = {
        {
          type = "table",
          name = "Daily Notes",
          filters = { ["and"] = { "note.type == \"daily\"" } },
          order = { "file.name", "title", "tags" },
          sort = {
            { column = "file.name", direction = "DESC" },
          },
        },
      },
    },
    {
      filename = "loci-open-work.base",
      description = "Open LOCI task and issue Markdown objects",
      filters = {
        ["and"] = {
          "status != \"done\"",
          "status != \"closed\"",
        },
      },
      views = {
        {
          type = "table",
          name = "Open Work",
          filters = {
            ["and"] = {
              "status != \"done\"",
              "status != \"closed\"",
            },
          },
          order = { "file.name", "title", "type", "status", "priority", "due", "projects" },
          sort = {
            { column = "due", direction = "ASC" },
            { column = "status", direction = "ASC" },
            { column = "title", direction = "ASC" },
          },
        },
      },
    },
  }
end

-- ============================================================================
-- YAML Serialization
-- ============================================================================

local function escape_string(s)
  if not s or s == "" then
    return '""'
  end
  -- Quote if contains special YAML chars
  if s:match('[:{}\\#\\[\\]]') or s:match('^-') or s:match(' $') or s:match('^ ') then
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
  end
  return s
end

local function serialize_filter_or(filters)
  local lines = {}
  table.insert(lines, "or:")
  for _, filter in ipairs(filters) do
    table.insert(lines, "  - " .. filter)
  end
  return table.concat(lines, "\n")
end

local function serialize_filter_and(filters)
  local lines = {}
  table.insert(lines, "and:")
  for _, filter in ipairs(filters) do
    table.insert(lines, "  - " .. filter)
  end
  return table.concat(lines, "\n")
end

local function serialize_filters(filters)
  if filters["or"] then
    return serialize_filter_or(filters["or"])
  elseif filters["and"] then
    return serialize_filter_and(filters["and"])
  end
  return "and:\n  - true"
end

local function serialize_view(view, indent)
  indent = indent or "  "
  local lines = {}

  table.insert(lines, indent .. "- type: " .. (view.type or "table"))
  table.insert(lines, indent .. "  name: " .. escape_string(view.name or "View"))

  if view.filters then
    table.insert(lines, indent .. "  filters:")
    local filter_lines = serialize_filters(view.filters):split("\n")
    for _, line in ipairs(filter_lines) do
      table.insert(lines, indent .. "    " .. line)
    end
  end

  if view.order and #view.order > 0 then
    table.insert(lines, indent .. "  order:")
    for _, col in ipairs(view.order) do
      table.insert(lines, indent .. "    - " .. col)
    end
  end

  if view.sort and #view.sort > 0 then
    table.insert(lines, indent .. "  sort:")
    for _, sort_item in ipairs(view.sort) do
      table.insert(lines, indent .. "    - column: " .. sort_item.column)
      table.insert(lines, indent .. "      direction: " .. sort_item.direction)
    end
  end

  return table.concat(lines, "\n")
end

---Serialize a base spec to YAML
---@param spec table
---@return loci.Result
function M.serialize(spec)
  if not spec or not spec.filename or not spec.filters or not spec.views then
    return result.err("Base spec must have filename, filters, and views", "invalid_input")
  end

  local lines = {}

  -- Generated file header
  table.insert(lines, "# Generated by LOCI. Safe to delete; regenerated by :LociRefresh.")
  table.insert(lines, "# Source of truth: Markdown files under .loci/content/.")

  -- Filters section
  table.insert(lines, "filters:")
  local filter_lines = serialize_filters(spec.filters):split("\n")
  for _, line in ipairs(filter_lines) do
    table.insert(lines, "  " .. line)
  end

  -- Views section
  table.insert(lines, "views:")
  for _, view in ipairs(spec.views) do
    table.insert(lines, serialize_view(view))
  end

  -- Add final newline
  table.insert(lines, "")

  return result.ok(table.concat(lines, "\n"))
end

-- Helper to split strings
function string.split(s, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  s:gsub(pattern, function(c) fields[#fields + 1] = c end)
  return fields
end

-- ============================================================================
-- File Generation and Writing
-- ============================================================================

local function is_safe_base_filename(name)
  return type(name) == "string"
    and name:match("^[a-z0-9][a-z0-9%-_]*%.base$") ~= nil
    and not name:match("%.%.")
end

---Write a single base spec to a file
---@param spec table
---@param opts? table
---@return loci.Result
function M.write_spec(spec, opts)
  opts = opts or {}

  -- Validate filename
  if not is_safe_base_filename(spec.filename) then
    return result.err("Invalid base filename: " .. tostring(spec.filename), "invalid_input", {
      filename = spec.filename,
    })
  end

  -- Ensure bases directory exists
  local bases_dir = M.output_dir()
  local mkdir_r = fs.mkdir_p(bases_dir)
  if not mkdir_r.ok then
    return mkdir_r
  end

  -- Serialize the base spec
  local serialize_r = M.serialize(spec)
  if not serialize_r.ok then
    return serialize_r
  end

  -- Write the file
  local file_path = bases_dir .. "/" .. spec.filename
  local write_r = fs.write_file(file_path, serialize_r.value)
  if not write_r.ok then
    return write_r
  end

  -- Return metadata
  return result.ok({
    name = spec.filename,
    path = file_path,
    content_path = "content/bases/" .. spec.filename,
    bytes = #serialize_r.value,
  })
end

-- ============================================================================
-- Validation
-- ============================================================================

---Validate generated base files using bases.nvim if available
---@param files table
---@return loci.Result
function M.validate_generated(files)
  local ok, bases_mod = pcall(require, "bases")
  if not ok or type(bases_mod) ~= "table" or type(bases_mod.parse_file) ~= "function" then
    return result.ok({
      available = false,
      ok = true,
      diagnostics = {},
    })
  end

  local diagnostics = {}
  for _, file in ipairs(files or {}) do
    async.schedule()
    local parsed, err = bases_mod.parse_file(file.path)
    if not parsed then
      table.insert(diagnostics, {
        code = "bases_parse_failed",
        path = file.path,
        message = tostring(err),
      })
    end
  end

  return result.ok({
    available = true,
    ok = #diagnostics == 0,
    diagnostics = diagnostics,
  })
end

-- ============================================================================
-- Public Regeneration API
-- ============================================================================

---Regenerate all base files
---@param opts? table
---@return loci.Result
function M.regenerate(opts)
  opts = opts or {}

  local cfg = config.get()
  local enabled = cfg.integrations and cfg.integrations.bases ~= false

  if not enabled then
    return result.ok({
      enabled = false,
      generated = false,
      status = "disabled",
    })
  end

  local generated_at = opts.now or os.date("%Y-%m-%dT%H:%M:%S%z"):gsub("(%d%d)$", ":%1")
  local specs = opts.specs or M.default_specs()
  local generated_files = {}
  local diagnostics = {}

  -- Generate each base file
  for _, spec in ipairs(specs) do
    local write_r = M.write_spec(spec, opts)
    if write_r.ok then
      table.insert(generated_files, write_r.value)
    else
      table.insert(diagnostics, {
        code = "base_write_failed",
        filename = spec.filename,
        message = write_r.err,
      })
    end
  end

  -- Optionally validate generated files
  local validation = { available = false, ok = true, diagnostics = {} }
  if opts.validate ~= false then
    validation = M.validate_generated(generated_files).value
  end

  return result.ok({
    enabled = true,
    generated_at = generated_at,
    output_dir = M.output_dir(),
    files = generated_files,
    validation = validation,
  })
end

return M
