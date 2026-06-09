local MiniTest = require('mini.test')
local helpers = require('tests.helpers')
local expect = MiniTest.expect

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

T['repair recreates missing fallback only'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.ensure({ now = '2026-05-23T10:00:00Z' }))
  local fallback_path = tmpdir .. '/.loci/graph/workspaces/' .. init_r.repository.default_workspace_id .. '.json'
  vim.uv.fs_unlink(fallback_path)

  local r = repository.repair({ now = '2026-05-23T10:00:01Z' })
  helpers.expect_ok(r)
  expect.equality(r.value.repaired, true)
  expect.equality(vim.uv.fs_stat(fallback_path) ~= nil, true)
end)

T['repair does not touch corrupt fallback'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  local init_r = helpers.expect_ok(repository.ensure({ now = '2026-05-23T10:00:00Z' }))
  local fallback_path = tmpdir .. '/.loci/graph/workspaces/' .. init_r.repository.default_workspace_id .. '.json'
  helpers.write_file(fallback_path, '{ invalid json')

  local r = repository.repair()
  expect.equality(r.ok, false)
  expect.equality(r.code, 'repair_blocked_corrupt_fallback')
  expect.equality(helpers.read_file(fallback_path), '{ invalid json')
end)

return T
