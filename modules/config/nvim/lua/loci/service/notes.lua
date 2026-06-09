local result = require("loci.result")
local id_module = require("loci.domain.id")
local markdown = require("loci.store.markdown")
local workspace_service = require("loci.service.workspace")

local M = {}

---@async
---@param opts { title: string, dir?: string, type?: string, projects?: string[], tags?: string[] }
---@return loci.Result
function M.create(opts)
  opts = opts or {}

  local title = opts.title
  if not title or title == "" then
    return result.err("title is required", "invalid_input")
  end

  local r = markdown.write_new_object({
    dir = opts.dir or "notes",
    title = title,
    type = opts.type or "note",
    projects = opts.projects,
    tags = opts.tags,
  })

  if not r.ok then
    return r
  end

  return result.ok(r.value)
end

---@async
---@param opts { date_string?: string }
---@return loci.Result
function M.daily(opts)
  opts = opts or {}
  local date_string = opts.date_string or os.date("%Y-%m-%d")

  if not date_string:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return result.err("invalid date format (expected YYYY-MM-DD)", "invalid_input")
  end

  local content_path = "daily/" .. date_string .. ".md"
  local abs_path_res = markdown.abs_path_for_content(content_path)
  if not abs_path_res.ok then
    return abs_path_res
  end

  local fs = require("loci.store.fs")
  local exists_res = fs.exists(abs_path_res.value)
  if exists_res.ok and exists_res.value then
    return result.ok({ abs_path = abs_path_res.value })
  end

  local r = markdown.write_new_object({
    dir = "daily",
    filename = date_string .. ".md",
    title = date_string,
    type = "daily",
    tags = { "daily" },
  })

  if not r.ok then
    return r
  end

  return result.ok(r.value)
end

---@async
---@param opts { title?: string, workspace_id?: string }
---@return loci.Result
function M.scratch(opts)
  opts = opts or {}

  local title = opts.title
  if not title or title == "" then
    title = "Scratch " .. id_module.now_iso():gsub("T", " "):sub(1, 16)
  end

  local r = markdown.write_new_object({
    dir = "notes",
    title = title,
    type = "scratch",
  })

  if not r.ok then
    return r
  end

  if opts.workspace_id then
    local content_path_r = markdown.content_path_for_abs(r.value.abs_path)
    if content_path_r.ok then
      local assoc_r = workspace_service.add_knowledge(opts.workspace_id, content_path_r.value, { role = "scratch" })
      if not assoc_r.ok then
        return result.ok({ abs_path = r.value.abs_path, workspace_association_error = assoc_r.err })
      end
    end
  end

  return result.ok(r.value)
end

---@async
---@param abs_path string
---@param opts? { loci_id?: string, title?: string, type?: string }
---@return loci.Result
function M.ensure_id(abs_path, opts)
  opts = opts or {}

  local is_under_r = markdown.is_under_content(abs_path)
  if not is_under_r.ok then
    return is_under_r
  end
  if not is_under_r.value then
    return result.err("file is not under .loci/content/", "invalid_input")
  end

  return markdown.ensure_loci_id(abs_path, opts)
end

---@async
---@return loci.Result<table[]>
function M.markdown_index_entries(opts)
  local json_store = require("loci.store.json")
  local p = require("loci.store.path")
  local index_path = p.must_index_path("markdown.json")
  local r = json_store.read(index_path)
  if not r.ok then
    return r
  end
  return result.ok((r.value and r.value.objects) or {})
end

return M
