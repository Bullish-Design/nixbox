local result = require("loci.result")
local id = require("loci.domain.id")
local path_contracts = require("loci.domain.path_contracts")

local M = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.default_cache()
  return { task_loci_ids = {}, issue_loci_ids = {}, note_loci_ids = {} }
end

function M.default_provenance(now)
  return { created_at = now, last_refreshed_at = now }
end

function M.new(opts)
  opts = opts or {}
  if type(opts.title) ~= "string" or trim(opts.title) == "" then
    return result.err("project title is required", "invalid_input")
  end
  if type(opts.now) ~= "string" or opts.now == "" then
    return result.err("timestamp is required", "invalid_input")
  end

  local project_id = opts.project_id or id.new(opts.title)
  if not id.is_valid(project_id) then
    return result.err("invalid project_id: " .. tostring(project_id), "invalid_input")
  end

  local content_path = opts.content_path
  local path_r = path_contracts.validate_content_path(content_path)
  if not path_r.ok or not content_path:match("^projects/") or not content_path:match("%.md$") then
    return result.err("project content_path must be projects/<name>.md", "invalid_input")
  end

  return result.ok({
    schema_version = 1,
    project_id = project_id,
    content_path = content_path,
    title_cache = trim(opts.title),
    status_cache = opts.status or "active",
    workspace_ids = {},
    linked_files = {},
    cache = M.default_cache(),
    provenance = M.default_provenance(opts.now),
  })
end

function M.validate(value)
  if type(value) ~= "table" then
    return result.err("project must be a table", "invalid_input")
  end

  if value.schema_version ~= 1 then
    return result.err("invalid schema_version", "invalid_input")
  end

  if not id.is_valid(value.project_id) then
    return result.err("invalid project_id", "invalid_input")
  end

  local content_path_r = path_contracts.validate_content_path(value.content_path)
  if not content_path_r.ok or not value.content_path:match("^projects/") or not value.content_path:match("%.md$") then
    return result.err("invalid content_path", "invalid_input")
  end

  if type(value.title_cache) ~= "string" then
    return result.err("title_cache must be a string", "invalid_input")
  end

  if type(value.status_cache) ~= "string" then
    return result.err("status_cache must be a string", "invalid_input")
  end

  if type(value.workspace_ids) ~= "table" then
    return result.err("workspace_ids must be a table", "invalid_input")
  end

  if type(value.linked_files) ~= "table" then
    return result.err("linked_files must be a table", "invalid_input")
  end

  if type(value.cache) ~= "table"
      or type(value.cache.task_loci_ids) ~= "table"
      or type(value.cache.issue_loci_ids) ~= "table"
      or type(value.cache.note_loci_ids) ~= "table" then
    return result.err("cache must have task_loci_ids, issue_loci_ids, and note_loci_ids tables", "invalid_input")
  end

  if type(value.provenance) ~= "table"
      or type(value.provenance.created_at) ~= "string"
      or type(value.provenance.last_refreshed_at) ~= "string" then
    return result.err("provenance must have created_at and last_refreshed_at strings", "invalid_input")
  end

  return result.ok(value)
end

function M.index_entry(value)
  return {
    project_id = value.project_id,
    title = value.title_cache,
    status = value.status_cache,
    content_path = value.content_path,
    workspace_count = #value.workspace_ids,
    task_count = #value.cache.task_loci_ids,
    issue_count = #value.cache.issue_loci_ids,
    note_count = #value.cache.note_loci_ids,
  }
end

return M
