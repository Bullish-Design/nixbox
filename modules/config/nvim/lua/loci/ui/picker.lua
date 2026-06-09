local result = require("loci.result")
local config = require("loci.config")
local project_service = require("loci.service.project")
local workspace_service = require("loci.service.workspace")
local notes_service = require("loci.service.notes")
local async = require("loci.async")

local M = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function maybe_refresh(opts)
  opts = opts or {}
  local cfg = config.get()
  local should_refresh = opts.refresh
  if should_refresh == nil then
    should_refresh = cfg.refresh and cfg.refresh.before_picker
  end
  if not should_refresh then
    return result.ok({ refreshed = false })
  end
  return workspace_service.refresh_all({ quiet = true })
end

local function run_picker(entries, opts, callback)
  vim.ui.select(entries, {
    prompt = opts.prompt or "Select:",
    format_item = opts.format_item or function(item)
      return item.label or tostring(item)
    end,
  }, function(choice)
    if choice then
      callback(result.ok(choice))
    else
      callback(result.err("Selection cancelled", "cancelled"))
    end
  end)
end

local function select_entries(entries, opts, callback)
  if not entries or #entries == 0 then
    callback(result.err(opts.empty_message or "nothing to select", "not_found"))
    return
  end

  run_picker(entries, opts, callback)
end

-- ============================================================================
-- Index Readers
-- ============================================================================

local function read_projects_index()
  return project_service.picker_entries()
end

local function read_workspaces_index()
  return workspace_service.picker_entries()
end

local function read_markdown_index()
  return notes_service.markdown_index_entries()
end

-- ============================================================================
-- Public entry generators
-- ============================================================================

---Get project picker entries from index.
---@param opts? table
---@return loci.Result<table[]>
function M.project_entries(opts)
  opts = opts or {}
  return read_projects_index()
end

---Get workspace picker entries from index.
---@param opts? table
---@return loci.Result<table[]>
function M.workspace_entries(opts)
  opts = opts or {}
  local entries_r = read_workspaces_index()
  if not entries_r.ok then
    return entries_r
  end

  local entries = entries_r.value
  if not opts.include_archived then
    local filtered = {}
    for _, ws in ipairs(entries) do
      if not ws.archived then
        table.insert(filtered, ws)
      end
    end
    return result.ok(filtered)
  end

  return result.ok(entries)
end

---Get markdown picker entries from index.
---@param opts? table {kind=nil, project_link=nil}
---@return loci.Result<table[]>
function M.markdown_entries(opts)
  opts = opts or {}
  local entries_r = read_markdown_index()
  if not entries_r.ok then
    return entries_r
  end

  local entries = entries_r.value
  if opts.kind then
    local filtered = {}
    for _, obj in ipairs(entries) do
      if obj.type == opts.kind then
        table.insert(filtered, obj)
      end
    end
    entries = filtered
  end

  if opts.project_link then
    local filtered = {}
    for _, obj in ipairs(entries) do
      if obj.projects then
        for _, proj_link in ipairs(obj.projects) do
          if proj_link == opts.project_link then
            table.insert(filtered, obj)
            break
          end
        end
      end
    end
    entries = filtered
  end

  return result.ok(entries)
end

-- ============================================================================
-- Public Pickers
-- ============================================================================

---Project picker.
---@param callback function(result)
---@param opts? table
function M.project(callback, opts)
  opts = opts or {}

  local refresh_r = maybe_refresh(opts)
  if refresh_r and not refresh_r.ok then
    callback(refresh_r)
    return
  end

  local entries_r = M.project_entries(opts)
  if not entries_r.ok then
    callback(entries_r)
    return
  end

  local entries = entries_r.value
  if not entries or #entries == 0 then
    callback(result.err("no projects found", "not_found"))
    return
  end

  run_picker(entries, {
    source = "loci_projects",
    prompt = opts.prompt or "Select project:",
    empty_message = "no projects found",
    format_item = function(item)
      return string.format(
        "%s [%s] · %d workspaces · %d tasks",
        item.title or item.project_id,
        item.status or "active",
        item.workspace_count or 0,
        item.task_count or 0
      )
    end,
  }, callback)
end

---Workspace picker.
---@param callback function(result)
---@param opts? table
function M.workspace(callback, opts)
  opts = opts or {}

  local refresh_r = maybe_refresh(opts)
  if refresh_r and not refresh_r.ok then
    callback(refresh_r)
    return
  end

  local entries_r = M.workspace_entries(opts)
  if not entries_r.ok then
    callback(entries_r)
    return
  end

  local entries = entries_r.value
  if not entries or #entries == 0 then
    callback(result.err("no workspaces found", "not_found"))
    return
  end

  local current_id = vim.t.loci_workspace_id

  run_picker(entries, {
    source = "loci_workspaces",
    prompt = opts.prompt or "Select workspace:",
    empty_message = "no workspaces found",
    format_item = function(item)
      local current_marker = (item.workspace_id == current_id) and "*" or " "
      return string.format(
        "%s %s · %s · %d knowledge · %d files",
        current_marker,
        item.label or item.name or item.workspace_id,
        item.project_title or item.project_id or "",
        item.knowledge_count or 0,
        item.linked_file_count or 0
      )
    end,
  }, callback)
end

---Markdown picker.
---@param callback function(result)
---@param opts? table
function M.markdown(callback, opts)
  opts = opts or {}

  local refresh_r = maybe_refresh(opts)
  if refresh_r and not refresh_r.ok then
    callback(refresh_r)
    return
  end

  local entries_r = M.markdown_entries(opts)
  if not entries_r.ok then
    callback(entries_r)
    return
  end

  local entries = entries_r.value
  if not entries or #entries == 0 then
    callback(result.err("no markdown found", "not_found"))
    return
  end

  run_picker(entries, {
    source = "loci_markdown",
    prompt = opts.prompt or "Select markdown:",
    empty_message = "no markdown found",
    format_item = function(item)
      return string.format(
        "%s [%s/%s] · %s",
        item.title or item.loci_id,
        item.type or "note",
        item.status or "open",
        item.content_path or ""
      )
    end,
  }, callback)
end

---Knowledge picker (select from workspace knowledge objects).
---@param workspace_id? string
---@param callback function(result)
---@param opts? table
function M.knowledge(workspace_id, callback, opts)
  opts = opts or {}

  if not workspace_id then
    workspace_id = vim.t.loci_workspace_id
  end

  if not workspace_id then
    callback(result.err("no active workspace", "not_found"))
    return
  end

  local ws_r = workspace_service.get(workspace_id)
  if not ws_r.ok then
    callback(ws_r)
    return
  end

  local workspace = ws_r.value
  local knowledge = workspace.knowledge and workspace.knowledge.objects or {}

  if not knowledge or #knowledge == 0 then
    callback(result.err("no knowledge found", "not_found"))
    return
  end

  select_entries(knowledge, {
    prompt = opts.prompt or "Select knowledge:",
    empty_message = "no knowledge found",
    format_item = function(item)
      local primary_marker = item.primary and " · primary" or ""
      return string.format("%s [%s]%s", item.title or item.loci_id, item.type or "note", primary_marker)
    end,
  }, callback)
end

---Linked file picker (select from workspace linked files).
---@param workspace_id? string
---@param callback function(result)
---@param opts? table
function M.linked_file(workspace_id, callback, opts)
  opts = opts or {}

  if not workspace_id then
    workspace_id = vim.t.loci_workspace_id
  end

  if not workspace_id then
    callback(result.err("no active workspace", "not_found"))
    return
  end

  local ws_r = workspace_service.get(workspace_id)
  if not ws_r.ok then
    callback(ws_r)
    return
  end

  local workspace = ws_r.value
  local files = workspace.linked_files or {}

  if not files or #files == 0 then
    callback(result.err("no linked files found", "not_found"))
    return
  end

  select_entries(files, {
    prompt = opts.prompt or "Select linked file:",
    empty_message = "no linked files found",
    format_item = function(item)
      return string.format("%s · %s", item.path or item, item.role or "")
    end,
  }, callback)
end

---Haunt context picker.
---@param workspace_id? string
---@param callback function(result)
---@param opts? table
function M.haunt_context(workspace_id, callback, opts)
  opts = opts or {}

  if not workspace_id then
    workspace_id = vim.t.loci_workspace_id
  end

  if not workspace_id then
    callback(result.err("no active workspace", "not_found"))
    return
  end

  if type(workspace_service.haunt_list) ~= "function" then
    callback(result.err("Haunt service not available", "not_found"))
    return
  end

  async.run(function()
    return workspace_service.haunt_list(workspace_id)
  end, function(list_res)
    if not list_res.ok then
      callback(result.err("failed to list Haunt contexts", "integration_failed"))
      return
    end

    local contexts = list_res.value.contexts or {}
    if #contexts == 0 then
      callback(result.err("no Haunt contexts found", "not_found"))
      return
    end

    select_entries(contexts, {
      prompt = opts.prompt or "Select Haunt context:",
      empty_message = "no Haunt contexts found",
      format_item = function(item)
        local marker = item.active and "*" or " "
        return string.format("%s %s", marker, item.name or "")
      end,
    }, callback)
  end)
end

---Trail picker.
---@param workspace_id? string
---@param callback function(result)
---@param opts? table
function M.trail(workspace_id, callback, opts)
  opts = opts or {}

  if not workspace_id then
    workspace_id = vim.t.loci_workspace_id
  end

  async.run(function()
    return workspace_service.list_trails(workspace_id)
  end, function(list_res)
    if not list_res.ok then
      callback(result.err("failed to list trails", "integration_failed"))
      return
    end

    local trails = list_res.value.trails or {}
    if #trails == 0 then
      callback(result.err("no trails found", "not_found"))
      return
    end

    select_entries(trails, {
      prompt = opts.prompt or "Select Trail:",
      empty_message = "no trails found",
      format_item = function(item)
        local marker = item.active and "*" or " "
        return string.format("%s %s (%s)", marker, item.logical_name or "", item.trail_name or "")
      end,
    }, callback)
  end)
end

-- ============================================================================
-- Test seams
-- ============================================================================

function M._select(entries, opts, callback)
  select_entries(entries, opts, callback)
end

---Return the canonical picker backend name.
function M._backend_name()
  return "vim_ui_select"
end

return M
