local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

T['default_for_repository() creates repository fallback workspace'] = function()
  local workspace = require('loci.domain.workspace')
  local repository = {
    default_workspace_id = 'repo-default-def456',
  }
  local ws = workspace.default_for_repository(repository, {
    created_at = '2026-05-23T10:00:00-04:00',
  })

  expect.equality(ws.workspace_id, 'repo-default-def456')
  expect.equality(ws.project_id, vim.NIL)
  expect.equality(ws.name, 'Repository')
  expect.equality(ws.tabby.label, 'Repository')
  expect.equality(ws.resession.session_name, 'loci:workspace:repo-default-def456')
  expect.equality(ws.haunt.contexts.main.data_dir, '.loci/integrations/haunt/workspaces/repo-default-def456/main')
  expect.equality(ws.wayfinder.trails.main.trail_name, 'loci-repo-default-def456-main')
  expect.equality(#ws.knowledge.objects, 0)
  expect.equality(#ws.linked_files, 0)
end

T['validate() accepts fallback workspace'] = function()
  local domain = require('loci.domain.workspace')
  local workspace = domain.default_for_repository({
    default_workspace_id = 'repo-default-def456',
  }, {
    created_at = '2026-05-23T10:00:00-04:00',
  })
  local r = domain.validate(workspace)
  expect.equality(r.ok, true)
  expect.equality(r.value, workspace)
end

return T
