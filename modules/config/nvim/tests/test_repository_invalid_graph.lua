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

T['invalid repository graph blocks ensure'] = helpers.async_test(function()
  vim.fn.mkdir(tmpdir .. '/.loci', 'p')
  helpers.write_file(tmpdir .. '/.loci/repository.json', '{ invalid json')
  local r = require('loci.service.repository').ensure()
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_existing_repository')
end)

return T
