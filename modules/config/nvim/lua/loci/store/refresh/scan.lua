local result = require('loci.result')
local markdown = require('loci.store.markdown')
local graph = require('loci.store.graph')

local M = {}

function M.run(opts)
  opts = opts or {}
  local diagnostics = {}

  local content_r = markdown.scan_entries({ tolerant = true })
  if not content_r.ok then return content_r end

  local projects_r = graph.scan_projects_tolerant()
  if not projects_r.ok then return projects_r end

  local workspaces_r = graph.scan_workspaces_tolerant()
  if not workspaces_r.ok then return workspaces_r end

  local repo_r = graph.read_repository()
  local repository = nil
  if repo_r.ok then repository = repo_r.value elseif repo_r.code ~= 'not_found' then
    diagnostics[#diagnostics + 1] = { code = repo_r.code or 'repository_read_failed', message = repo_r.err, severity = 'error', details = repo_r.meta }
  end

  local current_r = graph.read_current()
  local current = nil
  if current_r.ok then current = current_r.value elseif current_r.code ~= 'not_found' then
    diagnostics[#diagnostics + 1] = { code = current_r.code or 'current_read_failed', message = current_r.err, severity = 'error', details = current_r.meta }
  end

  local entries = content_r.value.entries or {}
  local projects = projects_r.value.entries or projects_r.value or {}
  local workspaces = workspaces_r.value.entries or workspaces_r.value or {}

  return result.ok({
    content_entries = entries,
    projects = projects,
    workspaces = workspaces,
    repository = repository,
    current = current,
    diagnostics = diagnostics,
    stats = { content_entries = #entries, projects = #projects, workspaces = #workspaces },
  })
end

return M
