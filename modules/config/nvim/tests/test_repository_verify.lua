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

T['verify writes nothing'] = helpers.async_test(function()
  local repository = require('loci.service.repository')
  helpers.expect_ok(repository.ensure({ now = '2026-05-23T10:00:00Z' }))

  local graph = require('loci.store.graph')
  local old_wr = graph.write_repository
  local old_ww = graph.write_workspace
  local old_wc = graph.write_current
  graph.write_repository = function() error('verify must not write') end
  graph.write_workspace = function() error('verify must not write') end
  graph.write_current = function() error('verify must not write') end

  local ok, r = pcall(repository.verify_existing)
  graph.write_repository = old_wr
  graph.write_workspace = old_ww
  graph.write_current = old_wc

  expect.equality(ok, true)
  helpers.expect_ok(r)
end)

return T
