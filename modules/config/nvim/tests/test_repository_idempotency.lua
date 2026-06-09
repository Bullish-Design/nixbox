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
      require('loci.store.path').reset()
    end,
    post_case = function()
      restore()
      helpers.remove_tmpdir(tmpdir)
    end,
  },
})

local opts = {
  now = '2026-05-23T10:00:00-04:00',
  repository_id = 'test-repo-abc123',
  default_workspace_id = 'repo-default-def456',
  name = 'test-repo',
}

T['init() second run reports existing repository'] = helpers.async_test(function()
  local service = require('loci.service.repository')
  helpers.expect_ok(service.init(opts))
  local second = helpers.expect_ok(service.init(opts))
  expect.equality(second.created, false)
  expect.equality(second.repository.repository_id, 'test-repo-abc123')
end)

T['init() does not overwrite content index'] = helpers.async_test(function()
  local service = require('loci.service.repository')
  helpers.expect_ok(service.init(opts))
  helpers.write_file(tmpdir .. '/.loci/content/index.md', '# User Edited Index\n')
  helpers.expect_ok(service.init(vim.tbl_extend('force', opts, {
    now = '2026-05-23T11:00:00-04:00',
  })))
  expect.equality(helpers.read_file(tmpdir .. '/.loci/content/index.md'), '# User Edited Index\n')
end)

T['init() recreates missing directories'] = helpers.async_test(function()
  local service = require('loci.service.repository')
  helpers.expect_ok(service.init(opts))
  helpers.ensure_main()
  vim.fn.delete(tmpdir .. '/.loci/content/notes', 'rf')
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/content/notes'), nil)
  helpers.expect_ok(service.init(opts))
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/content/notes') ~= nil, true)
end)

T['init() recreates missing fallback workspace safely'] = helpers.async_test(function()
  local service = require('loci.service.repository')
  helpers.expect_ok(service.init(opts))
  helpers.ensure_main()
  vim.fn.delete(tmpdir .. '/.loci/graph/workspaces/repo-default-def456.json')
  local second = helpers.expect_ok(service.init(opts))
  expect.equality(second.repaired_fallback_workspace, true)
  expect.equality(vim.uv.fs_stat(tmpdir .. '/.loci/graph/workspaces/repo-default-def456.json') ~= nil, true)
end)

return T
