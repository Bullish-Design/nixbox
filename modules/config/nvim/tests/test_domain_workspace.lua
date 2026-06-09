local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

T['new() creates basic workspace'] = function()
  local workspace = require('loci.domain.workspace')
  local ws = workspace.new({
    name = 'my-workspace',
    created_at = '2026-05-23T10:00:00-04:00',
  })
  expect.equality(ws.schema_version, 1)
  expect.equality(ws.name, 'my-workspace')
  expect.equality(type(ws.knowledge.objects), 'table')
  expect.equality(#ws.knowledge.objects, 0)
end

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

T['validate() accepts valid workspace'] = function()
  local workspace = require('loci.domain.workspace')
  local ws = workspace.new({
    name = 'test-workspace',
    created_at = '2026-05-23T10:00:00-04:00',
  })
  local r = workspace.validate(ws)
  expect.equality(r.ok, true)
  expect.equality(r.value, ws)
end

T['validate() accepts fallback workspace'] = function()
  local workspace = require('loci.domain.workspace')
  local ws = workspace.default_for_repository({
    default_workspace_id = 'repo-default-def456',
  }, {
    created_at = '2026-05-23T10:00:00-04:00',
  })
  local r = workspace.validate(ws)
  expect.equality(r.ok, true)
  expect.equality(r.value, ws)
end

T['validate() rejects missing workspace_id'] = function()
  local workspace = require('loci.domain.workspace')
  local ws = workspace.new({
    name = 'test-workspace',
    created_at = '2026-05-23T10:00:00-04:00',
  })
  ws.workspace_id = nil
  local r = workspace.validate(ws)
  expect.equality(r.ok, false)
  expect.equality(r.code, 'validation_failed')
end

T['validate() rejects missing haunt context'] = function()
  local workspace = require('loci.domain.workspace')
  local ws = workspace.new({
    name = 'test-workspace',
    created_at = '2026-05-23T10:00:00-04:00',
  })
  ws.haunt.contexts = {}
  local r = workspace.validate(ws)
  expect.equality(r.ok, false)
  expect.equality(r.code, 'validation_failed')
end

T['validate() rejects missing wayfinder trail'] = function()
  local workspace = require('loci.domain.workspace')
  local ws = workspace.new({
    name = 'test-workspace',
    created_at = '2026-05-23T10:00:00-04:00',
  })
  ws.wayfinder.trails = {}
  local r = workspace.validate(ws)
  expect.equality(r.ok, false)
  expect.equality(r.code, 'validation_failed')
end

T['knowledge_entry() creates entry from markdown object'] = function()
  local workspace = require('loci.domain.workspace')
  local entry = workspace.knowledge_entry({
    loci_id = 'doc-123',
    content_path = 'notes/idea.md',
    title = 'My Idea',
  })
  expect.equality(entry.loci_id, 'doc-123')
  expect.equality(entry.content_path, 'notes/idea.md')
  expect.equality(entry.title_cache, 'My Idea')
  expect.equality(entry.role, 'supporting')
end

return T
