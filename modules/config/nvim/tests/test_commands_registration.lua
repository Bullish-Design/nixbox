local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')
local registry = require('loci.ui.commands.registry')

local tmpdir
local restore

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      helpers.reset_modules()
      tmpdir = helpers.create_tmpdir()
      restore = helpers.patch_project_root(tmpdir)
      require('loci.store.path').reset()
      helpers.clear_loci_commands()
    end,
    post_case = function()
      restore()
      helpers.remove_tmpdir(tmpdir)
    end,
  },
})

T['setup() registers all canonical Loci commands'] = function()
  require('loci').setup({ refresh = { on_setup = false } })
  local registered = vim.api.nvim_get_commands({})

  for _, name in ipairs(registry.CANONICAL) do
    expect.equality(registered[name] ~= nil, true, name .. ' should be registered')
  end
end

T['setup() does not register forbidden commands'] = function()
  require('loci').setup({ refresh = { on_setup = false } })
  local registered = vim.api.nvim_get_commands({})

  for _, name in ipairs(registry.FORBIDDEN) do
    expect.equality(registered[name] == nil, true, name .. ' must not be registered')
  end
end

T['setup() can be called repeatedly'] = function()
  require('loci').setup({ refresh = { on_setup = false } })
  require('loci').setup({ refresh = { on_setup = false } })
  local registered = vim.api.nvim_get_commands({})
  expect.equality(registered['LociInit'] ~= nil, true)
end

return T
