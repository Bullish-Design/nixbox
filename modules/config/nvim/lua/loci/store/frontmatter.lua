local result = require("loci.result")
local markdown_object = require("loci.domain.markdown_object")

local M = {}

---Parse inline YAML list [item1, item2, ...].
---@param value string
---@return string[]|nil list or nil if not a valid inline list
local function parse_inline_list(value)
  local inside = value:match("^%s*%[(.*)%]%s*$")
  if not inside then
    return nil
  end
  local list = {}
  for raw_item in inside:gmatch("[^,]+") do
    local item = raw_item:gsub("^%s+", ""):gsub("%s+$", "")
    item = item:gsub('^"', ""):gsub('"$', "")
    item = item:gsub("^'", ""):gsub("'$", "")
    if item ~= "" then
      table.insert(list, item)
    end
  end
  return list
end

---Split frontmatter block from body.
---@param text string
---@return table
function M.split(text)
  if not text or text == "" then
    return {
      has_frontmatter = false,
      malformed_frontmatter = false,
      raw_frontmatter = "",
      body = text,
      diagnostics = {},
    }
  end
  if not text:match("^%-%-%-") then
    return {
      has_frontmatter = false,
      malformed_frontmatter = false,
      raw_frontmatter = "",
      body = text,
      diagnostics = {},
    }
  end
  local lines = vim.split(text, "\n", { plain = true })
  if #lines < 2 or lines[1] ~= "---" then
    return {
      has_frontmatter = false,
      malformed_frontmatter = true,
      raw_frontmatter = "",
      body = text,
      diagnostics = { { code = "malformed_frontmatter", message = "Frontmatter block is missing closing ---" } },
    }
  end
  local closing_idx = nil
  for i = 2, #lines do
    if lines[i] == "---" then
      closing_idx = i
      break
    end
  end
  if not closing_idx then
    return {
      has_frontmatter = false,
      malformed_frontmatter = true,
      raw_frontmatter = "",
      body = text,
      diagnostics = { { code = "malformed_frontmatter", message = "Frontmatter block is missing closing ---" } },
    }
  end
  local raw_lines = {}
  for i = 2, closing_idx - 1 do
    table.insert(raw_lines, lines[i])
  end
  local raw_frontmatter = table.concat(raw_lines, "\n")
  if raw_frontmatter ~= "" then
    raw_frontmatter = raw_frontmatter .. "\n"
  end
  local body_lines = {}
  for i = closing_idx + 1, #lines do
    table.insert(body_lines, lines[i])
  end
  return {
    has_frontmatter = true,
    malformed_frontmatter = false,
    raw_frontmatter = raw_frontmatter,
    body = table.concat(body_lines, "\n"),
    diagnostics = {},
  }
end

---@param raw string
---@param opts? table
---@return loci.Result
function M.parse(raw, opts)
  local frontmatter = {}
  local diagnostics = {}
  local seen_keys = {}

  if not raw or raw == "" then
    return result.ok({ frontmatter = frontmatter, diagnostics = diagnostics })
  end

  local lines = vim.split(raw, "\n", { plain = true })
  local i = 1

  while i <= #lines do
    local line = lines[i]

    -- Skip blank lines and comments
    if line:match("^%s*$") or line:match("^%s*#") then
      i = i + 1
    else
      local key, value = line:match("^([a-zA-Z_][a-zA-Z0-9_]*):%s*(.*)")
      if not key then
        i = i + 1
      else
        -- Track duplicates
        if seen_keys[key] then
          table.insert(diagnostics, { code = "unsupported_yaml", message = "Duplicate key: " .. key })
        end
        seen_keys[key] = true

        if value:match("^%[") then
          -- Inline list: [a, b, c]
          frontmatter[key] = parse_inline_list(value) or {}
          i = i + 1
        elseif value == "" then
          -- Possible block list: look ahead for "  - item" lines
          local list = {}
          local j = i + 1
          while j <= #lines do
            local next_line = lines[j]
            if next_line:match("^  %- ") then
              local item = next_line:match("^  %- (.*)"):match("^%s*(.-)%s*$")
              if item:sub(1, 1) == '"' and item:sub(-1) == '"' then
                item = item:sub(2, -2)
              elseif item:sub(1, 1) == "'" and item:sub(-1) == "'" then
                item = item:sub(2, -2)
              end
              table.insert(list, item)
              j = j + 1
            else
              break
            end
          end
          frontmatter[key] = list   -- empty table if no items found
          i = j
        else
          -- Scalar value
          local scalar = value
          if scalar:sub(1, 1) == '"' and scalar:sub(-1) == '"' then
            scalar = scalar:sub(2, -2)
          elseif scalar:sub(1, 1) == "'" and scalar:sub(-1) == "'" then
            scalar = scalar:sub(2, -2)
          end
          frontmatter[key] = scalar
          i = i + 1
        end
      end
    end
  end
  return result.ok({ frontmatter = frontmatter, diagnostics = diagnostics })
end

---@param frontmatter table
---@param opts? table
---@return loci.Result<string>
function M.serialize(frontmatter, opts)
  opts = opts or {}
  frontmatter = frontmatter or {}
  local lines = {}
  local key_order = opts.field_order or {
    "loci_id",
    "type",
    "title",
    "projects",
    "tags",
    "aliases",
    "status",
    "created",
    "updated",
    "loci_generated",
  }
  for _, key in ipairs(key_order) do
    local value = frontmatter[key]
    if value ~= nil and value ~= "" then
      if type(value) == "table" then
        if #value == 0 then goto skip_key end
        table.insert(lines, key .. ":")
        for _, item in ipairs(value) do
          local escaped = tostring(item)
          if escaped:match("[%[%]]") then escaped = '"' .. escaped .. '"' end
          table.insert(lines, "  - " .. escaped)
        end
      else
        local scalar = tostring(value)
        if scalar:match("[:\"]") or scalar:match("[%[%]]") then
          scalar = '"' .. scalar:gsub('"', '\\"') .. '"'
        end
        table.insert(lines, key .. ": " .. scalar)
      end
      ::skip_key::
    end
  end
  for key, value in pairs(frontmatter) do
    if not vim.list_contains(key_order, key) then
      if value ~= nil and value ~= "" then
        if type(value) == "table" then
          if #value > 0 then
            table.insert(lines, key .. ":")
            for _, item in ipairs(value) do table.insert(lines, "  - " .. tostring(item)) end
          end
        else
          table.insert(lines, key .. ": " .. tostring(value))
        end
      end
    end
  end
  return result.ok(table.concat(lines, "\n") .. "\n")
end

function M.inspect(raw)
  local diagnostics = {}
  local split = M.split(raw or "")
  if not split.has_frontmatter then
    table.insert(diagnostics, { code = "no_frontmatter", message = "No YAML frontmatter found" })
    return { fields = {}, diagnostics = diagnostics }
  end
  if split.malformed_frontmatter then
    table.insert(diagnostics, { code = "malformed_frontmatter", message = "Malformed YAML frontmatter block" })
    return { fields = {}, diagnostics = diagnostics }
  end

  local parsed = M.parse(split.raw_frontmatter, { tolerant = true })
  if parsed.ok then
    local fields = parsed.value.frontmatter or {}
    for _, d in ipairs(parsed.value.diagnostics or {}) do
      table.insert(diagnostics, d)
    end
    if not fields.loci_id then
      table.insert(diagnostics, { code = "missing_loci_id", message = "No loci_id in frontmatter" })
    elseif not markdown_object.validate_loci_id(fields.loci_id) then
      table.insert(diagnostics, { code = "invalid_loci_id", message = "Invalid loci_id format", value = fields.loci_id })
    end
    if fields.projects ~= nil then
      if type(fields.projects) ~= "table" then
        table.insert(diagnostics, { code = "legacy_projects_format", message = "projects is not an array", value = fields.projects })
      else
        for i, v in ipairs(fields.projects) do
          if type(v) ~= "string" then
            table.insert(diagnostics, { code = "invalid_project_entry", message = "projects entry is not a string", index = i })
          end
        end
      end
    end
    return { fields = fields, diagnostics = diagnostics }
  end
  table.insert(diagnostics, { code = "malformed_frontmatter", message = parsed.err or "failed to parse frontmatter" })
  return { fields = {}, diagnostics = diagnostics }
end

return M
