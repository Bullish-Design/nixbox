local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local tmpdir
local restore
local original_project_root

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      helpers.reset_modules()
      original_project_root = vim.env.LOCI_PROJECT_ROOT
      vim.env.LOCI_PROJECT_ROOT = nil
      tmpdir = helpers.create_tmpdir()
      restore = helpers.patch_project_root(tmpdir)
      require('loci.store.path').reset()
    end,
    post_case = function()
      restore()
      vim.env.LOCI_PROJECT_ROOT = original_project_root
      helpers.remove_tmpdir(tmpdir)
    end,
  },
})

T['repository_root() returns LOCI_PROJECT_ROOT when set'] = function()
  local path = require('loci.store.path')
  expect.equality(path.repository_root(), vim.fs.normalize(tmpdir))
end

T['repository_root() uses configured root when env is absent'] = function()
  restore()
  local configured = helpers.create_tmpdir()
  local config = require('loci.config')
  config.setup({ repository = { root = configured } })
  local path = require('loci.store.path')
  path.reset()
  expect.equality(path.repository_root(), vim.fs.normalize(configured))
  helpers.remove_tmpdir(configured)
  restore = helpers.patch_project_root(tmpdir)
  path.reset()
end

T['loci_root() appends .loci'] = function()
  local path = require('loci.store.path')
  local expected = vim.fs.normalize(tmpdir) .. '/.loci'
  expect.equality(path.loci_root(), expected)
end

T['content_path() without arg returns content dir'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_content_path(), path.loci_root() .. '/content')
end

T['content_path() with rel appends to content dir'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_content_path('projects/my-project.md'), path.loci_root() .. '/content/projects/my-project.md')
end

T['content_path() rejects traversal'] = function()
  local path = require('loci.store.path')
  local r = path.content_path('../graph/current.json')
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_input')
end

T['graph_path() without arg returns graph dir'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_graph_path(), path.loci_root() .. '/graph')
end

T['graph_path() with rel'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_graph_path('workspaces/ws-123.json'), path.loci_root() .. '/graph/workspaces/ws-123.json')
end

T['index_path() without arg returns indexes dir'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_index_path(), path.loci_root() .. '/indexes')
end

T['index_path() with filename'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_index_path('projects.json'), path.loci_root() .. '/indexes/projects.json')
end

T['integration_path() without arg returns integrations dir'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_integration_path(), path.loci_root() .. '/integrations')
end

T['integration_path() with rel'] = function()
  local path = require('loci.store.path')
  expect.equality(path.must_integration_path('haunt/workspaces/ws-1/main'), path.loci_root() .. '/integrations/haunt/workspaces/ws-1/main')
end

T['is_initialized() returns false when .loci/ does not exist'] = function()
  local path = require('loci.store.path')
  expect.equality(path.is_initialized(), false)
end

T['is_initialized() returns true after init_loci_dir'] = function()
  helpers.init_loci_dir(tmpdir)
  local path = require('loci.store.path')
  expect.equality(path.is_initialized(), true)
end

T['is_initialized() returns false when sentinel missing'] = function()
  vim.fn.mkdir(tmpdir .. '/.loci', 'p')
  local path = require('loci.store.path')
  expect.equality(path.is_initialized(), false)
end

T['abs() converts relative to absolute'] = function()
  local path = require('loci.store.path')
  local root = path.repository_root()
  expect.equality(path.must_abs('src/main.lua'), root .. '/src/main.lua')
end

T['abs() rejects absolute input'] = function()
  local path = require('loci.store.path')
  local r = path.abs('/etc/passwd')
  expect.equality(r.ok, false)
  expect.equality(r.code, 'invalid_input')
end

T['relative() converts absolute to relative'] = function()
  local path = require('loci.store.path')
  local root = path.repository_root()
  expect.equality(path.relative(root .. '/src/main.lua'), 'src/main.lua')
end

T['relative() returns nil for paths outside root'] = function()
  local path = require('loci.store.path')
  expect.equality(path.relative('/some/other/path'), nil)
end

T['relative() does not accept root prefix sibling'] = function()
  local path = require('loci.store.path')
  local root = path.repository_root()
  expect.equality(path.relative(root .. '-sibling/file.txt'), nil)
end

T['relative() returns dot for root itself'] = function()
  local path = require('loci.store.path')
  local root = path.repository_root()
  expect.equality(path.relative(root), '.')
end

return T
