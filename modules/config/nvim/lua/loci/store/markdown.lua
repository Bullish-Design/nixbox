local result = require("loci.result")
local path = require("loci.store.path")
local fs = require("loci.store.fs")
local markdown_object = require("loci.domain.markdown_object")
local frontmatter = require("loci.store.frontmatter")
local id_module = require("loci.domain.id")

local M = {}

---@class loci.MarkdownDocument
---@field abs_path string
---@field content_path string|nil
---@field has_frontmatter boolean
---@field malformed_frontmatter boolean
---@field frontmatter table
---@field raw_frontmatter string
---@field body string
---@field diagnostics table[]
---@field object loci.MarkdownObject

-- ============================================================================
-- Path Helpers
-- ============================================================================

---@async
---@param abs_path string
---@return loci.Result<boolean>
function M.is_under_content(abs_path) return result.ok(path.is_under_content(abs_path)) end

---@async
---@param abs_path string
---@return loci.Result<string>
function M.content_path_for_abs(abs_path)
  local rel = path.content_relative(abs_path)
  if not rel then return result.err("path is not under .loci/content/", "outside_content") end
  return result.ok(rel)
end

---@async
---@param content_path string
---@return loci.Result<string>
function M.abs_path_for_content(content_path)
  if not content_path or content_path == "" then
    return result.err("content_path is required", "invalid_input")
  end

  if content_path:match("%.%.") then
    return result.err("path traversal not allowed", "invalid_input")
  end

  return result.ok(vim.fs.normalize(path.must_content_path(content_path)))
end

---@async
---@param abs_path string
---@param object table
---@param body string|nil
---@return loci.Result<string>
function M.write_canonical(abs_path, object, body)
  local is_under_res = M.is_under_content(abs_path)
  if not is_under_res.ok then
    return is_under_res
  end
  if not is_under_res.value then
    return result.err("file is outside .loci/content/", "outside_content")
  end

  local content_path_res = M.content_path_for_abs(abs_path)
  if not content_path_res.ok then
    return content_path_res
  end

  local normalized_res = markdown_object.normalize(vim.tbl_extend("force", object or {}, {
    content_path = content_path_res.value,
    abs_path = abs_path,
    has_frontmatter = true,
    malformed_frontmatter = false,
  }))
  if not normalized_res.ok then
    return normalized_res
  end

  local normalized = normalized_res.value
  local fm = {
    loci_id = normalized.loci_id,
    type = normalized.type,
    title = normalized.title,
    projects = normalized.projects,
    tags = normalized.tags,
    status = normalized.status,
  }
  if object and object.aliases then fm.aliases = object.aliases end
  if object and object.created then fm.created = object.created end
  if object and object.updated then fm.updated = object.updated end
  if object and object.loci_generated ~= nil then fm.loci_generated = object.loci_generated end

  local fm_str_res = M.serialize_frontmatter(fm, {})
  if not fm_str_res.ok then
    return fm_str_res
  end
  local file_content = "---\n" .. fm_str_res.value .. "---\n" .. (body or "")
  local write_res = fs.write_file(abs_path, file_content)
  if not write_res.ok then
    return write_res
  end
  return result.ok(abs_path)
end

-- ============================================================================
-- Frontmatter Parsing
-- ============================================================================

M.split_frontmatter = frontmatter.split
M.parse_frontmatter = frontmatter.parse
M.serialize_frontmatter = frontmatter.serialize

-- ============================================================================
-- File Reading and Normalization
-- ============================================================================

---@async
---@param abs_path string
---@return loci.Result<loci.MarkdownDocument>
function M.read_frontmatter(abs_path)
  -- Validate path is under content
  local is_under_res = M.is_under_content(abs_path)
  if not is_under_res.ok then
    return is_under_res
  end
  if not is_under_res.value then
    return result.err("file is outside .loci/content/", "outside_content")
  end

  -- Get content_path
  local content_path_res = M.content_path_for_abs(abs_path)
  if not content_path_res.ok then
    return content_path_res
  end
  local content_path = content_path_res.value

  -- Read file
  local read_res = fs.read_file(abs_path)
  if not read_res.ok then
    return read_res
  end
  local file_content = read_res.value

  -- Split frontmatter
  local split = M.split_frontmatter(file_content)

  -- Parse frontmatter
  local parse_res = M.parse_frontmatter(split.raw_frontmatter, {})
  if not parse_res.ok then
    return parse_res
  end

  local parsed = parse_res.value
  local frontmatter = parsed.frontmatter
  local diagnostics = parsed.diagnostics

  -- Normalize object
  local obj_res = markdown_object.from_frontmatter(frontmatter, {
    content_path = content_path,
    abs_path = abs_path,
  }, {
    strict = false,
    malformed_frontmatter = split.malformed_frontmatter,
    diagnostics = diagnostics,
  })

  if not obj_res.ok then
    return obj_res
  end

  local obj = obj_res.value

  if not obj.loci_id then
    local has_missing = false
    for _, diag in ipairs(obj.diagnostics) do
      if diag.code == "missing_loci_id" then
        has_missing = true
        break
      end
    end
    if not has_missing then
      table.insert(obj.diagnostics, {
        code = "missing_loci_id",
        message = "Markdown file is missing loci_id",
        path = abs_path,
      })
    end
  end

  return result.ok({
    abs_path = abs_path,
    content_path = content_path,
    has_frontmatter = split.has_frontmatter,
    malformed_frontmatter = split.malformed_frontmatter,
    frontmatter = frontmatter,
    raw_frontmatter = split.raw_frontmatter,
    body = split.body,
    diagnostics = obj.diagnostics,
    object = obj,
  })
end

-- ============================================================================
-- File Creation
-- ============================================================================

---@async
---@param opts table
---@return loci.Result<loci.MarkdownObject>
function M.write_new_object(opts)
  opts = opts or {}

  -- Validate inputs
  local dir = opts.dir or "notes"
  if dir:match("%.%.") then
    return result.err("path traversal in dir not allowed", "invalid_input")
  end

  local filename = opts.filename
  if not filename then
    if not opts.title or opts.title == "" then
      filename = "untitled.md"
    else
      filename = id_module.slugify(opts.title) .. ".md"
    end
  else
    -- Ensure .md extension
    if not filename:match("%.md$") then
      filename = filename .. ".md"
    end
    if filename:match("%.%.") then
      return result.err("path traversal in filename not allowed", "invalid_input")
    end
  end

  -- Build content path (relative to .loci/content/)
  local content_path = dir .. "/" .. filename
  local abs_path_res = M.abs_path_for_content(content_path)
  if not abs_path_res.ok then
    return abs_path_res
  end
  local abs_path = abs_path_res.value

  -- Check if file already exists
  local exists_r = fs.exists(abs_path)
  if exists_r.ok and exists_r.value then
    if not opts.overwrite then
      return result.err("File already exists", "conflict", { path = abs_path })
    end
  end

  -- Generate frontmatter
  local fm_res = markdown_object.frontmatter_for_new({
    title = opts.title,
    type = opts.type,
    status = opts.status,
    tags = opts.tags,
    projects = opts.projects,
    loci_id = opts.loci_id,
    extra = opts.extra,
  })
  if not fm_res.ok then
    return fm_res
  end
  local frontmatter = fm_res.value

  -- Create body
  local body = opts.body
  if not body then
    if opts.title then
      body = "# " .. opts.title .. "\n"
    else
      body = "# Note\n"
    end
  end

  local write_res = M.write_canonical(abs_path, frontmatter, body)
  if not write_res.ok then
    return write_res
  end

  -- Return normalized object
  local obj_res = markdown_object.normalize({
    loci_id = frontmatter.loci_id,
    title = frontmatter.title,
    type = frontmatter.type,
    status = frontmatter.status,
    projects = frontmatter.projects,
    tags = frontmatter.tags,
    content_path = content_path,
    abs_path = abs_path,
    has_frontmatter = true,
    malformed_frontmatter = false,
    diagnostics = {},
  })

  return obj_res
end

-- ============================================================================
-- Frontmatter Mutation
-- ============================================================================

local function escape_pattern(value)
  return (value:gsub("([^%w])", "%%%1"))
end

local function yaml_quote_string(value)
  local escaped = tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"')
  return '"' .. escaped .. '"'
end

local function split_lines_preserve_empty(raw)
  local lines = vim.split(raw or "", "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines, #lines)
  end
  return lines
end

local function is_top_level_key(line)
  return line:match("^[a-zA-Z_][a-zA-Z0-9_]*:%s*") ~= nil
end

local function normalize_yaml_scalar_for_compare(value)
  local s = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  local unq = s:match("^\"(.*)\"$") or s:match("^'(.*)'$")
  return unq or s
end

local function find_block_list_range(lines, key)
  local key_pat = "^" .. escape_pattern(key) .. ":%s*(.*)$"
  for i = 1, #lines do
    local rhs = lines[i]:match(key_pat)
    if rhs ~= nil then
      local j = i + 1
      while j <= #lines and not is_top_level_key(lines[j]) do
        j = j + 1
      end
      return i, j - 1, rhs
    end
  end
  return nil
end

local function raw_block_list_contains(lines, start_idx, end_idx, value)
  local want = normalize_yaml_scalar_for_compare(value)
  for i = start_idx + 1, end_idx do
    local item = lines[i]:match("^%s*%-%s*(.-)%s*$")
    if item and normalize_yaml_scalar_for_compare(item) == want then
      return true
    end
  end
  return false
end


---@async
---@param abs_path string
---@param key string
---@param value string
---@param opts? table
---@return loci.Result<loci.MarkdownDocument>
function M.add_frontmatter_list_value(abs_path, key, value, opts)
  opts = opts or {}

  if not key or key == "" or not key:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
    return result.err("invalid frontmatter key", "invalid_input")
  end

  local raw_r = fs.read_file(abs_path)
  if not raw_r.ok then return raw_r end

  local split = M.split_frontmatter(raw_r.value)
  local inspection = frontmatter.inspect(raw_r.value)
  if split.malformed_frontmatter then
    return result.err("Cannot safely mutate malformed frontmatter", "decode_failed")
  end
  local existing = inspection.fields[key]
  if existing ~= nil and type(existing) ~= "table" then
    return result.err("Cannot add value to non-list field", "invalid_input")
  end

  local updated_fm = {}
  for k, v in pairs(inspection.fields or {}) do
    updated_fm[k] = v
  end
  local list = updated_fm[key] or {}
  local exists = false
  for _, item in ipairs(list) do
    if item == value then
      exists = true
      break
    end
  end
  if not exists then
    table.insert(list, value)
  end
  updated_fm[key] = list

  local write_r = M.write_canonical(abs_path, updated_fm, split.body)
  if not write_r.ok then
    return write_r
  end
  return M.read_frontmatter(abs_path)
end

-- ============================================================================
-- ID Management
-- ============================================================================

---@async
---@param abs_path string
---@param opts? table
---@return loci.Result<loci.MarkdownObject>
function M.ensure_loci_id(abs_path, opts)
  opts = opts or {}

  -- Repair operations must read raw and inspect tolerantly.
  -- Never use read_frontmatter here: it validates strictly and would reject
  -- the very files this function exists to fix.
  local raw_r = fs.read_file(abs_path)
  if not raw_r.ok then
    return raw_r
  end

  local split = M.split_frontmatter(raw_r.value)
  local inspection = frontmatter.inspect(raw_r.value)

  -- If ID already exists, return the object (via tolerant read_frontmatter which now uses inspect)
  if inspection.fields.loci_id then
    -- Re-read with strict validation now that ID is confirmed present
    local read_res = M.read_frontmatter(abs_path)
    if read_res.ok then
      return result.ok(read_res.value.object)
    end
    -- Fallback: return minimal object with what we have
    return result.ok({
      loci_id = inspection.fields.loci_id,
    })
  end

  -- If malformed and not forced, fail
  if split.malformed_frontmatter and not opts.force then
    return result.err("Cannot ensure ID in malformed frontmatter without force=true", "decode_failed")
  end

  -- Determine loci_id
  local loci_id = opts.loci_id
  if loci_id ~= nil and not id_module.is_valid(loci_id) then
    return result.err("Invalid loci_id", "invalid_loci_id", { loci_id = loci_id })
  end
  if not loci_id then
    local title = opts.title
    if not title then
      title = inspection.fields.title
    end
    if not title then
      -- Try to extract first H1 from body
      local h1_match = split.body:match("^%s*#%s+(.+)")
      if h1_match then
        title = h1_match
      end
    end
    if not title then
      -- Use filename without extension
      local filename = abs_path:match("([^/]+)%.md$")
      if filename then
        title = filename
      else
        title = "note"
      end
    end
    loci_id = id_module.new(title)
  end

  -- Determine type for new frontmatter
  local content_path_res = M.content_path_for_abs(abs_path)
  if not content_path_res.ok then
    return content_path_res
  end
  local inferred_type = markdown_object.kind_from_content_path(content_path_res.value)
  local type_val = opts.type or inspection.fields.type or inferred_type or "note"

  if split.has_frontmatter then
    -- Insert loci_id as first line of frontmatter
    local raw_lines = {}
    for line in split.raw_frontmatter:gmatch("[^\n]+") do
      table.insert(raw_lines, line)
    end

    table.insert(raw_lines, 1, "loci_id: " .. loci_id)
    local new_raw = table.concat(raw_lines, "\n")

    -- Rebuild file
    local file_content = "---\n" .. new_raw .. "\n---\n" .. split.body
    local write_res = fs.write_file(abs_path, file_content)
    if not write_res.ok then
      return write_res
    end
  else
    -- Create minimal frontmatter
    local fm = {
      loci_id = loci_id,
    }

    if opts.title then
      fm.title = opts.title
    elseif inspection.fields.title then
      fm.title = inspection.fields.title
    end

    fm.type = type_val

    local fm_str_res = M.serialize_frontmatter(fm)
    if not fm_str_res.ok then
      return fm_str_res
    end

    local file_content = "---\n" .. fm_str_res.value .. "---\n" .. split.body
    local write_res = fs.write_file(abs_path, file_content)
    if not write_res.ok then
      return write_res
    end
  end

  -- After writing loci_id, re-read the file to get the complete MarkdownObject
  -- Now that loci_id is present, strict read_frontmatter will succeed
  local read_res = M.read_frontmatter(abs_path)
  if read_res.ok then
    return result.ok(read_res.value.object)
  end

  -- Fallback if re-read fails (shouldn't happen)
  return result.err("Failed to read written frontmatter", "io_error")
end

-- ============================================================================
-- Scanning and Lookup
-- ============================================================================

---@async
---@param start_path string
---@param visited table
---@return table[] list of markdown files
local function recursive_scan(start_path, visited)
  visited = visited or {}
  local result_files = {}

  local entries_r = fs.scandir(start_path)
  if not entries_r.ok then
    return result_files
  end

  for _, entry in ipairs(entries_r.value) do
    local name = entry.name

    -- Skip hidden files
    if name:sub(1, 1) == "." then
      goto skip
    end

    local full_path = start_path .. "/" .. name
    local stat_r = fs.lstat(full_path)
    if not stat_r.ok then
      goto skip
    end
    local stat = stat_r.value

    -- Skip symlinks to prevent loops
    if stat.type == "link" then
      goto skip
    end

    if stat.type == "directory" then
      if not visited[full_path] then
        visited[full_path] = true
        local subfiles = recursive_scan(full_path, visited)
        for _, f in ipairs(subfiles) do
          table.insert(result_files, f)
        end
      end
    elseif stat.type == "file" and name:match("%.md$") then
      table.insert(result_files, full_path)
    end

    ::skip::
  end

  return result_files
end

---@async
---@param opts? table
---@return loci.Result<table>
function M.scan_content(opts)
  opts = opts or {}
  local include_noncannonical = opts.include_noncannonical == true
  local entries_r = M.scan_entries(opts)
  if not entries_r.ok then
    return entries_r
  end
  local entries = entries_r.value.entries

  local objects = {}
  local by_loci_id = {}
  local seen_ids = {}
  local all_diagnostics = {}

  for _, entry in ipairs(entries) do
    for _, diag in ipairs(entry.diagnostics or {}) do
      table.insert(all_diagnostics, diag)
    end

    if entry.state ~= "canonical" and not include_noncannonical then
      goto continue_file
    end
    local obj = entry.object
    if not obj then
      goto continue_file
    end
    if obj.loci_id then
      if seen_ids[obj.loci_id] then
        table.insert(all_diagnostics, {
          code = "duplicate_loci_id",
          message = "Duplicate loci_id: " .. obj.loci_id,
          path = entry.abs_path,
          existing_path = seen_ids[obj.loci_id],
        })
      else
        seen_ids[obj.loci_id] = entry.abs_path
        by_loci_id[obj.loci_id] = obj.content_path
      end
    end
    table.insert(objects, obj)
    ::continue_file::
  end

  -- Sort objects by content_path for determinism
  table.sort(objects, function(a, b)
    return a.content_path < b.content_path
  end)

  return result.ok({
    objects = objects,
    by_loci_id = by_loci_id,
    diagnostics = all_diagnostics,
  })
end

---@async
---@param opts? table
---@return loci.Result<table>
function M.scan_entries(opts)
  opts = opts or {}
  local content_root = path.must_content_path()
  local files = recursive_scan(content_root, {})
  local entries = {}

  for _, abs_path in ipairs(files) do
    local content_path_r = M.content_path_for_abs(abs_path)
    if not content_path_r.ok then
      table.insert(entries, {
        abs_path = abs_path,
        content_path = nil,
        state = "invalid",
        object = nil,
        diagnostics = { { code = content_path_r.code or "outside_content", message = content_path_r.err, path = abs_path } },
      })
      goto continue_entry
    end

    local read_res = M.read_frontmatter(abs_path)
    if not read_res.ok then
      table.insert(entries, {
        abs_path = abs_path,
        content_path = content_path_r.value,
        state = "invalid",
        object = nil,
        diagnostics = { { code = read_res.code or "io_read_failed", message = read_res.err, path = abs_path } },
      })
      goto continue_entry
    end

    local doc = read_res.value
    local obj = doc.object
    local state = "canonical"
    if obj.type == "repository-index" or (doc.frontmatter and doc.frontmatter.loci_generated == true) then
      state = "generated"
    elseif not obj.loci_id then
      state = "noncanonical"
    elseif doc.malformed_frontmatter or #(obj.diagnostics or {}) > 0 then
      state = "noncanonical"
    end
    table.insert(entries, {
      abs_path = abs_path,
      content_path = content_path_r.value,
      state = state,
      object = obj,
      diagnostics = obj.diagnostics or {},
    })
    ::continue_entry::
  end

  table.sort(entries, function(a, b)
    return (a.content_path or a.abs_path) < (b.content_path or b.abs_path)
  end)
  return result.ok({ entries = entries })
end

---@async
---@param loci_id string
---@param opts? table
---@return loci.Result<loci.MarkdownObject>
function M.find_by_loci_id(loci_id, opts)
  opts = opts or {}

  -- Validate ID
  if not id_module.is_valid(loci_id) then
    return result.err("Invalid loci_id format", "invalid_input")
  end

  -- Check index if supplied
  if opts.index and type(opts.index) == "table" then
    if opts.index[loci_id] then
      local content_path = opts.index[loci_id]
      local abs_path_res = M.abs_path_for_content(content_path)
      if abs_path_res.ok then
        local read_res = M.read_frontmatter(abs_path_res.value)
        if read_res.ok then
          return result.ok(read_res.value.object)
        end
      end
    end
  end

  -- Fallback to scan
  local scan_res = M.scan_content()
  if not scan_res.ok then
    return scan_res
  end

  local scan = scan_res.value
  if scan.by_loci_id[loci_id] then
    local content_path = scan.by_loci_id[loci_id]
    local abs_path_res = M.abs_path_for_content(content_path)
    if abs_path_res.ok then
      local read_res = M.read_frontmatter(abs_path_res.value)
      if read_res.ok then
        return result.ok(read_res.value.object)
      end
    end
  end

  return result.err("Markdown object not found: " .. loci_id, "not_found", {
    loci_id = loci_id,
  })
end

-- ============================================================================
-- Wikilink Generation
-- ============================================================================

---@async
---@param content_path string
---@param opts? table
---@return loci.Result<string>
function M.wikilink_for_content_path(content_path, opts)
  opts = opts or {}

  if not content_path or content_path == "" then
    return result.err("content_path is required", "invalid_input")
  end

  -- Validate path
  if content_path:match("%.%.") then
    return result.err("path traversal not allowed", "invalid_input")
  end

  if not content_path:match("%.md$") then
    return result.err("must end with .md", "invalid_input")
  end

  -- Strip content/ prefix and .md suffix
  local link_target = content_path:sub(1, -4)

  -- Build wikilink
  local wikilink = "[[" .. link_target
  if opts.alias then
    wikilink = wikilink .. "|" .. opts.alias
  end
  wikilink = wikilink .. "]]"

  return result.ok(wikilink)
end

return M
