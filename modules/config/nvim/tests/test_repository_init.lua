local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local tmpdir
local restore

local T = MiniTest.new_set({ hooks = {
  pre_case = function()
    helpers.reset_modules()
    tmpdir = helpers.create_tmpdir()
    restore = helpers.patch_project_root(tmpdir)
    require('loci.store.path').reset()
  end,
  post_case = function()
    restore()
    helpers.remove_tmpdir(tmpdir)
  end,
}})

T['new repository initialization creates canonical graph'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local r = repository.init_new({ now = '2026-05-23T10:00:00Z' })
  helpers.expect_ok(r)
  expect.equality(r.value.created, true)
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/repository.json') ~= nil, true)
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/graph/workspaces/' .. r.value.repository.default_workspace_id .. '.json') ~= nil, true)
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/graph/current.json') ~= nil, true)
end)

T['ensure on existing valid repository is non-destructive'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.init_new({ now = '2026-05-23T10:00:00Z' }))
  local fallback_path = tmpdir .. '/.loci/graph/workspaces/' .. init_r.repository.default_workspace_id .. '.json'

  local before_repo = helpers.read_file(tmpdir .. '/.loci/repository.json')
  local before_fallback = helpers.read_file(fallback_path)
  local before_current = helpers.read_file(tmpdir .. '/.loci/graph/current.json')

  local r = repository.ensure({ now = '2026-05-23T10:00:01Z' })
  helpers.expect_ok(r)
  expect.equality(r.value.created, false)
  expect.equality(helpers.read_file(tmpdir .. '/.loci/repository.json'), before_repo)
  expect.equality(helpers.read_file(fallback_path), before_fallback)
  expect.equality(helpers.read_file(tmpdir .. '/.loci/graph/current.json'), before_current)
end)

T['ensure is re-entrant safe after partial init'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.init_new({ now = '2026-05-23T10:00:00Z' }))
  vim.uv.fs_unlink(tmpdir .. '/.loci/graph/current.json')

  local r = repository.ensure({ now = '2026-05-23T10:00:01Z' })
  helpers.expect_ok(r)
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/graph/current.json') ~= nil, true)
end)

T['missing fallback workspace is recreated'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.init_new({ now = '2026-05-23T10:00:00Z' }))
  local fallback_path = tmpdir .. '/.loci/graph/workspaces/' .. init_r.repository.default_workspace_id .. '.json'
  vim.uv.fs_unlink(fallback_path)

  local r = repository.ensure()
  helpers.expect_ok(r)
  expect.equality(r.value.fallback_workspace ~= nil, true)
  expect.equality(vim.uv.fs_stat(fallback_path) ~= nil, true)
end)

T['invalid fallback JSON is not overwritten'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.init_new({ now = '2026-05-23T10:00:00Z' }))
  local fallback_path = tmpdir .. '/.loci/graph/workspaces/' .. init_r.repository.default_workspace_id .. '.json'
  helpers.write_file(fallback_path, '{ invalid json')

  local r = repository.ensure()
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_existing_fallback_workspace')
  expect.equality(helpers.read_file(fallback_path), '{ invalid json')
end)

T['invalid fallback graph shape is not overwritten'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.init_new({ now = '2026-05-23T10:00:00Z' }))
  local fallback_path = tmpdir .. '/.loci/graph/workspaces/' .. init_r.repository.default_workspace_id .. '.json'
  helpers.write_json(fallback_path, { id = 'not-a-valid-loci-id', name = 'Fallback' })

  local r = repository.ensure()
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_existing_fallback_workspace')
  expect.equality(helpers.read_json(fallback_path).name, 'Fallback')
end)

T['repository seed config uses canonical schema'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  helpers.expect_ok(repository.init_new({ now = '2026-05-23T10:00:00Z' }))
  local repo = helpers.read_json(tmpdir .. '/.loci/repository.json')
  expect.equality(repo.config.integrations.tasknotes.enabled, true)
  expect.equality(repo.config.tasknotes, nil)
end)

return T
