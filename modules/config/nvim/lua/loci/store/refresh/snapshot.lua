local result = require('loci.result')

local M = {}

local function add_unique(list, value)
  for _, existing in ipairs(list) do if existing == value then return end end
  list[#list + 1] = value
end

function M.build(scan_result, opts)
  opts = opts or {}
  local diagnostics = vim.deepcopy(scan_result.diagnostics or {})
  local content_by_loci_id, content_by_path, generated_entries = {}, {}, {}

  for _, entry in ipairs(scan_result.content_entries or {}) do
    if entry.state == 'generated' then
      generated_entries[#generated_entries + 1] = entry
    elseif entry.state == 'canonical' and entry.object then
      local object = entry.object
      if content_by_loci_id[object.loci_id] then
        diagnostics[#diagnostics + 1] = { code = 'duplicate_loci_id', message = 'Duplicate loci_id found during refresh snapshot', severity = 'error', id = object.loci_id, path = entry.content_path }
      else content_by_loci_id[object.loci_id] = entry end
      if content_by_path[entry.content_path] then
        diagnostics[#diagnostics + 1] = { code = 'duplicate_content_path', message = 'Duplicate content_path found during refresh snapshot', severity = 'error', path = entry.content_path }
      else content_by_path[entry.content_path] = entry end
    else
      for _, d in ipairs(entry.diagnostics or {}) do diagnostics[#diagnostics + 1] = d end
    end
  end

  local projects_by_id, workspaces_by_id = {}, {}
  for _, project in ipairs(scan_result.projects or {}) do if project.id or project.project_id then projects_by_id[project.id or project.project_id] = project end end
  for _, workspace in ipairs(scan_result.workspaces or {}) do if workspace.id or workspace.workspace_id then workspaces_by_id[workspace.id or workspace.workspace_id] = workspace end end

  local project_memberships = {}
  for loci_id, entry in pairs(content_by_loci_id) do
    for _, project_id in ipairs(entry.object.projects or {}) do
      project_memberships[project_id] = project_memberships[project_id] or {}
      add_unique(project_memberships[project_id], loci_id)
    end
  end

  return result.ok({
    repository = scan_result.repository,
    current = scan_result.current,
    content_by_loci_id = content_by_loci_id,
    content_by_path = content_by_path,
    projects_by_id = projects_by_id,
    workspaces_by_id = workspaces_by_id,
    project_memberships = project_memberships,
    workspace_knowledge = {},
    generated_entries = generated_entries,
    diagnostics = diagnostics,
    stats = { canonical_content = vim.tbl_count(content_by_loci_id), generated_entries = #generated_entries, projects = vim.tbl_count(projects_by_id), workspaces = vim.tbl_count(workspaces_by_id) },
  })
end

return M
