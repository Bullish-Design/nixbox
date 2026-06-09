local id = require("loci.domain.id")
local path_contracts = require("loci.domain.path_contracts")
local result = require("loci.result")

local M = {}
local SCHEMA_VERSION = 1

local function null_if_nil(value)
  if value == nil then return vim.NIL end
  return value
end

local function is_null(value)
  return value == nil or value == vim.NIL
end

local function is_nonempty_string(value)
  return type(value) == "string" and value ~= ""
end

local function haunt_data_dir(workspace_id, logical_name)
  return ".loci/integrations/haunt/workspaces/" .. workspace_id .. "/" .. logical_name
end

local function trail_name(workspace_id, logical_name)
  return "loci-" .. workspace_id .. "-" .. logical_name
end

function M.new(opts)
  opts = opts or {}
  local name = opts.name or "Workspace"
  local workspace_id = opts.workspace_id or id.new(name)
  local label = opts.label or name
  local created_at = opts.created_at or opts.now

  return {
    schema_version = SCHEMA_VERSION,
    workspace_id = workspace_id,
    project_id = null_if_nil(opts.project_id),
    name = name,
    git = { branch = null_if_nil(opts.branch), worktree_path = null_if_nil(opts.worktree_path) },
    tabby = { label = label, tab_id_cache = vim.NIL },
    resession = { session_name = opts.session_name or ("loci:workspace:" .. workspace_id), scope = opts.resession_scope or "tab" },
    knowledge = { primary_loci_id = null_if_nil(opts.primary_loci_id), objects = opts.knowledge_objects or {} },
    haunt = { active = opts.haunt_active or "main", contexts = opts.haunt_contexts or { main = { data_dir = haunt_data_dir(workspace_id, "main") } } },
    wayfinder = { active = opts.trail_active or "main", trails = opts.trails or { main = { trail_name = trail_name(workspace_id, "main") } } },
    linked_files = opts.linked_files or {},
    provenance = { created_at = created_at, last_activated_at = null_if_nil(opts.last_activated_at), last_refreshed_at = opts.last_refreshed_at or created_at },
  }
end

function M.default_for_repository(repository, opts)
  opts = opts or {}
  return M.new({
    workspace_id = opts.workspace_id or repository.default_workspace_id,
    project_id = vim.NIL,
    name = "Repository",
    label = "Repository",
    created_at = opts.created_at,
    last_refreshed_at = opts.last_refreshed_at,
  })
end

function M.knowledge_entry(markdown_object, role)
  return {
    type = markdown_object.type or "note",
    loci_id = markdown_object.loci_id,
    content_path = markdown_object.content_path,
    title_cache = markdown_object.title or markdown_object.loci_id,
    role = role or "supporting",
  }
end

function M.validate(workspace)
  if type(workspace) ~= "table" then return result.err("workspace must be a table", "validation_failed") end
  if workspace.schema_version ~= SCHEMA_VERSION then return result.err("unsupported workspace schema_version", "validation_failed") end
  if not id.is_valid(workspace.workspace_id) then return result.err("invalid workspace_id", "validation_failed") end
  if not is_null(workspace.project_id) and not id.is_valid(workspace.project_id) then return result.err("invalid project_id", "validation_failed") end
  if not is_nonempty_string(workspace.name) then return result.err("workspace name is required", "validation_failed") end

  if type(workspace.knowledge) ~= "table" or type(workspace.knowledge.objects) ~= "table" then return result.err("workspace knowledge objects table is required", "validation_failed") end
  local seen_knowledge_ids, seen_knowledge_paths = {}, {}
  for _, obj in ipairs(workspace.knowledge.objects) do
    if type(obj) ~= "table" or not id.is_valid(obj.loci_id) then return result.err("invalid knowledge loci_id", "validation_failed") end
    local cp = path_contracts.validate_content_path(obj.content_path)
    if not cp.ok then return result.err("invalid knowledge content_path", "validation_failed") end
    if seen_knowledge_ids[obj.loci_id] or seen_knowledge_paths[obj.content_path] then return result.err("duplicate knowledge entry", "validation_failed") end
    seen_knowledge_ids[obj.loci_id], seen_knowledge_paths[obj.content_path] = true, true
  end
  if not is_null(workspace.knowledge.primary_loci_id) then
    if not id.is_valid(workspace.knowledge.primary_loci_id) or not seen_knowledge_ids[workspace.knowledge.primary_loci_id] then
      return result.err("primary_loci_id must reference knowledge object", "validation_failed")
    end
  end

  if type(workspace.linked_files) ~= "table" then return result.err("workspace linked_files table is required", "validation_failed") end
  local seen_links = {}
  for _, linked in ipairs(workspace.linked_files) do
    if type(linked) ~= "table" then return result.err("invalid linked file entry", "validation_failed") end
    local lr = path_contracts.validate_linked_file_path(linked.path)
    if not lr.ok then return result.err("invalid linked file path", "validation_failed") end
    if seen_links[linked.path] then return result.err("duplicate linked file path", "validation_failed") end
    seen_links[linked.path] = true
  end

  if type(workspace.haunt) ~= "table" or not is_nonempty_string(workspace.haunt.active) or type(workspace.haunt.contexts) ~= "table" then
    return result.err("workspace haunt config is required", "validation_failed")
  end
  local active_ctx = workspace.haunt.contexts[workspace.haunt.active]
  if type(active_ctx) ~= "table" then return result.err("workspace active haunt context must exist", "validation_failed") end

  if type(workspace.wayfinder) ~= "table" or not is_nonempty_string(workspace.wayfinder.active) or type(workspace.wayfinder.trails) ~= "table" then
    return result.err("workspace wayfinder config is required", "validation_failed")
  end
  local active_trail = workspace.wayfinder.trails[workspace.wayfinder.active]
  if type(active_trail) ~= "table" then return result.err("workspace active wayfinder trail must exist", "validation_failed") end

  if type(workspace.provenance) ~= "table" or not is_nonempty_string(workspace.provenance.created_at) then
    return result.err("workspace provenance.created_at is required", "validation_failed")
  end
  return result.ok(workspace)
end

return M
