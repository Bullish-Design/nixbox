local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local tmpdir
local restore

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      helpers.reset_modules()
      tmpdir = helpers.create_tmpdir()
      restore = helpers.patch_project_root(tmpdir)
      helpers.init_loci_dir(tmpdir)
      require('loci.store.path').reset()
    end,
    post_case = function()
      restore()
      helpers.remove_tmpdir(tmpdir)
    end,
  },
})

T['repository roundtrip'] = helpers.async_test(function()
  local graph = require('loci.store.graph')
  local repo = {
    schema_version = 1,
    repository_id = 'test-repo-abc123',
    name = 'test-repo',
    root = tmpdir,
    default_workspace_id = 'repo-default-def456',
    default_content_path = 'index.md',
    provenance = {
      created_at = '2026-05-23T10:00:00-04:00',
      last_refreshed_at = '2026-05-23T10:00:00-04:00',
    },
  }

  helpers.expect_ok(graph.write_repository(repo))
  local read_r = helpers.expect_ok(graph.read_repository())
  expect.equality(read_r.repository_id, 'test-repo-abc123')
  expect.equality(read_r.name, 'test-repo')
end)

T['workspace roundtrip'] = helpers.async_test(function()
  local graph = require('loci.store.graph')
  local workspace = {
    schema_version = 1,
    workspace_id = 'test-ws-def456',
    project_id = vim.NIL,
    name = 'Test Workspace',
    git = {
      branch = vim.NIL,
      worktree_path = vim.NIL,
    },
    tabby = {
      label = 'Test',
      tab_id_cache = vim.NIL,
    },
    resession = {
      session_name = 'loci:workspace:test-ws-def456',
      scope = 'tab',
    },
    knowledge = {
      primary_loci_id = vim.NIL,
      objects = {},
    },
    haunt = {
      active = 'main',
      contexts = {
        main = {
          data_dir = '.loci/integrations/haunt/workspaces/test-ws-def456/main',
        },
      },
    },
    wayfinder = {
      active = 'main',
      trails = {
        main = {
          trail_name = 'loci-test-ws-def456-main',
        },
      },
    },
    linked_files = {},
    provenance = {
      created_at = '2026-05-23T10:00:00-04:00',
      last_activated_at = vim.NIL,
      last_refreshed_at = '2026-05-23T10:00:00-04:00',
    },
  }

  helpers.expect_ok(graph.write_workspace(workspace))
  local read_r = helpers.expect_ok(graph.read_workspace('test-ws-def456'))
  expect.equality(read_r.workspace_id, 'test-ws-def456')
  expect.equality(read_r.name, 'Test Workspace')
end)

T['current roundtrip'] = helpers.async_test(function()
  local graph = require('loci.store.graph')
  local current = {
    current_project_id = vim.NIL,
    current_workspace_id = 'repo-default-def456',
    updated_at = '2026-05-23T10:00:00-04:00',
  }

  helpers.expect_ok(graph.write_current(current))
  local read_r = helpers.expect_ok(graph.read_current())
  expect.equality(read_r.current_workspace_id, 'repo-default-def456')
end)

T['invalid project_id type returns invalid_input'] = helpers.async_test(function()
  local graph = require('loci.store.graph')
  local r = graph.read_project({ bad = true })
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_input')
end)

T['invalid workspace_id type returns invalid_input'] = helpers.async_test(function()
  local graph = require('loci.store.graph')
  local r = graph.read_workspace({ bad = true })
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_input')
end)

T['missing graph file returns not_found'] = helpers.async_test(function()
  local graph = require('loci.store.graph')
  local id = require('loci.domain.id')
  local valid_id = id.new('test')
  local r = graph.read_project(valid_id)
  expect.equality(r.ok, false)
  expect.equality(r.code, 'not_found')
end)

return T
