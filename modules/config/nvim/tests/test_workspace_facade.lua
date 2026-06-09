local MiniTest = require('mini.test')
local expect = MiniTest.expect
local T = MiniTest.new_set()

T['workspace facade exports expected public functions'] = function()
  package.loaded['loci.service.workspace'] = nil
  local workspace = require('loci.service.workspace')

  for _, name in ipairs({
    'create',
    'open',
    'info',
    'list',
    'exists',
    'refresh',
    'refresh_all',
    'archive',
    'clone',
    'add_knowledge',
    'remove_knowledge',
    'set_primary',
    'link_current_file',
    'unlink_current_file',
    'haunt_new',
    'haunt_switch',
    'haunt_rename',
    'haunt_delete',
    'create_trail',
    'switch_trail',
    'save_active_trail',
    'load_trail',
    'rename_trail',
    'delete_trail',
    'list_trails',
  }) do
    expect.equality(type(workspace[name]), 'function', name)
  end
end

T['workspace facade does not export compatibility aliases'] = function()
  package.loaded['loci.service.workspace'] = nil
  local workspace = require('loci.service.workspace')
  expect.equality(workspace.new, nil)
  expect.equality(workspace.new_trail, nil)
  expect.equality(workspace.save_trail, nil)
end

return T
