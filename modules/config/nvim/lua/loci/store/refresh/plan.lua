local result = require('loci.result')

local M = {}

function M.build(snapshot, opts)
  opts = opts or {}
  local graph_writes, index_writes, generated_writes = {}, {}, {}
  local now = opts.now or os.date('!%Y-%m-%dT%H:%M:%SZ')

  local projects_by_id = snapshot.projects_by_id or {}

  for project_id, project in pairs(projects_by_id) do
    local next_project = vim.deepcopy(project)
    next_project.cache = next_project.cache or {}
    next_project.cache.loci_ids = snapshot.project_memberships[project_id] or {}
    next_project.cache.updated_at = now
    graph_writes[#graph_writes + 1] = { kind = 'project', id = project_id, value = next_project, reason = 'refresh_project_membership_cache' }
  end

  for workspace_id, workspace in pairs(snapshot.workspaces_by_id or {}) do
    local next_workspace = vim.deepcopy(workspace)
    if next_workspace.knowledge and next_workspace.knowledge.objects then
      for _, knowledge in ipairs(next_workspace.knowledge.objects) do
        local content = snapshot.content_by_loci_id[knowledge.loci_id]
        if content then knowledge.content_path = content.content_path end
      end
    end
    graph_writes[#graph_writes + 1] = { kind = 'workspace_tx', id = workspace_id, value = next_workspace, reason = 'refresh_workspace_knowledge_paths' }
  end

  -- Build projects index
  local projects_list = {}
  for project_id, project in pairs(projects_by_id) do
    projects_list[#projects_list + 1] = {
      project_id = project_id,
      title_cache = project.title_cache,
      status_cache = project.status_cache,
      content_path = project.content_path,
    }
  end
  index_writes[#index_writes + 1] = {
    kind = "index_file",
    name = "projects.json",
    value = { kind = "projects_index", projects = projects_list },
  }

  return result.ok({ graph_writes = graph_writes, graph_deletes = {}, index_writes = index_writes, generated_writes = generated_writes, diagnostics = snapshot.diagnostics or {}, summary = { graph_writes = #graph_writes, index_writes = #index_writes, generated_writes = #generated_writes } })
end

return M
