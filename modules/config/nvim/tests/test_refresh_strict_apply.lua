local MiniTest = require('mini.test')
local expect = MiniTest.expect
local refresh = require('loci.store.refresh')
local graph = require('loci.store.graph')
local result = require('loci.result')

local T = MiniTest.new_set()

T['strict apply returns err on authoritative graph write failure'] = function()
  local orig = graph.write_project
  graph.write_project = function(_) return result.err('boom', 'write_failed') end
  local r = refresh.apply({ graph_writes = { { kind = 'project', id = 'project-1', value = { project_id = 'project-1' } } }, generated_writes = {}, diagnostics = {} }, { mode = 'strict' })
  graph.write_project = orig
  expect.equality(r.ok, false)
end

return T
