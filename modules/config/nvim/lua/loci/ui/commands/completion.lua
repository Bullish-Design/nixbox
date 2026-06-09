local util = require("loci.ui.commands.util")
-- BOUNDARY EXCEPTION: Completion callbacks must remain synchronous.
-- Direct store reads are intentionally retained here to avoid async/yield paths.

local M = {}

function M.complete_project_id(arglead, cmdline, cursorpos)
  local path = require("loci.store.path")
  local json = require("loci.store.json")

  -- Try to read projects index
  local index_path = path.must_index_path("projects.json")
  local r = json.read(index_path)
  if r.ok and r.value and r.value.projects then
    local project_ids = {}
    for _, proj in ipairs(r.value.projects) do
      if proj.project_id then
        table.insert(project_ids, proj.project_id)
      end
    end
    return util.filter_values(project_ids, arglead)
  end

  -- Fallback to graph
  local graph = require("loci.store.graph")
  local projects_r = graph.list_projects()
  if projects_r.ok then
    local project_ids = {}
    for _, proj in ipairs(projects_r.value or {}) do
      if proj.project_id then
        table.insert(project_ids, proj.project_id)
      end
    end
    return util.filter_values(project_ids, arglead)
  end

  return {}
end

function M.complete_workspace_id(arglead, cmdline, cursorpos)
  local path = require("loci.store.path")
  local json = require("loci.store.json")

  -- Try to read workspaces index
  local index_path = path.must_index_path("workspaces.json")
  local r = json.read(index_path)
  if r.ok and r.value and r.value.workspaces then
    local workspace_ids = {}
    for _, ws in ipairs(r.value.workspaces) do
      if ws.workspace_id then
        table.insert(workspace_ids, ws.workspace_id)
      end
    end
    return util.filter_values(workspace_ids, arglead)
  end

  -- Fallback to graph
  local graph = require("loci.store.graph")
  local workspaces_r = graph.list_workspaces()
  if workspaces_r.ok then
    local workspace_ids = {}
    for _, ws in ipairs(workspaces_r.value or {}) do
      if ws.workspace_id then
        table.insert(workspace_ids, ws.workspace_id)
      end
    end
    return util.filter_values(workspace_ids, arglead)
  end

  return {}
end

function M.complete_markdown_id(arglead, cmdline, cursorpos)
  local path = require("loci.store.path")
  local json = require("loci.store.json")

  -- Read markdown index
  local index_path = path.must_index_path("markdown.json")
  local r = json.read(index_path)
  if r.ok and r.value and r.value.objects then
    local loci_ids = {}
    for _, obj in ipairs(r.value.objects) do
      if obj.loci_id then
        table.insert(loci_ids, obj.loci_id)
      end
    end
    return util.filter_values(loci_ids, arglead)
  end

  return {}
end

function M.complete_content_path(arglead, cmdline, cursorpos)
  local path = require("loci.store.path")
  local json = require("loci.store.json")

  -- Read markdown index
  local index_path = path.must_index_path("markdown.json")
  local r = json.read(index_path)
  if r.ok and r.value and r.value.objects then
    local paths = {}
    for _, obj in ipairs(r.value.objects) do
      if obj.content_path then
        table.insert(paths, obj.content_path)
      end
    end
    return util.filter_values(paths, arglead)
  end

  return {}
end

function M.complete_haunt_context(arglead, cmdline, cursorpos)
  local workspace_id = vim.t.loci_workspace_id
  if not workspace_id then
    return {}
  end

  local graph = require("loci.store.graph")
  local ws_r = graph.read_workspace(workspace_id)
  if ws_r.ok and ws_r.value and ws_r.value.haunt and ws_r.value.haunt.contexts then
    local context_names = {}
    for name, _ in pairs(ws_r.value.haunt.contexts) do
      table.insert(context_names, name)
    end
    return util.filter_values(context_names, arglead)
  end

  return {}
end

function M.complete_trail(arglead, cmdline, cursorpos)
  local workspace_id = vim.t.loci_workspace_id
  if not workspace_id then
    return {}
  end

  local graph = require("loci.store.graph")
  local ws_r = graph.read_workspace(workspace_id)
  if ws_r.ok and ws_r.value and ws_r.value.wayfinder and ws_r.value.wayfinder.trails then
    local trail_names = {}
    for name, _ in pairs(ws_r.value.wayfinder.trails) do
      table.insert(trail_names, name)
    end
    return util.filter_values(trail_names, arglead)
  end

  return {}
end

return M
