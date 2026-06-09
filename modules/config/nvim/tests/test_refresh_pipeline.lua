local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

T['refresh.scan does not write graph or markdown'] = helpers.async_with_initialized_repo(function()
  local refresh = require('loci.store.refresh')
  local graph = require('loci.store.graph')
  local orig = graph.write_workspace
  local write_calls = 0
  graph.write_workspace = function(...)
    write_calls = write_calls + 1
    return orig(...)
  end
  local r = refresh.scan({ mode = 'tolerant' })
  graph.write_workspace = orig
  expect.equality(r.ok, true)
  expect.equality(write_calls, 0)
end)

return T
