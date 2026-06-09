local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

-- Helper to setup test
local function setup_test()
  helpers.reset_modules()
  local ctx = helpers.create_phase8_fixture()
  helpers.install_wayfinder_command_stubs()
  ctx.graph = require('loci.store.graph')
  ctx.workspace_service = require('loci.service.workspace')
  return ctx
end

local function teardown_test(ctx)
  helpers.clear_wayfinder_command_stubs()
  ctx.cleanup()
end

-- Test 1: Workspace starts with main Trail
T['Workspace starts with main Trail'] = helpers.async_test(function()
  local ctx = setup_test()

  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  expect.equality(list_r.ok, true)
  expect.equality(#list_r.value.trails, 1)
  expect.equality(list_r.value.trails[1].logical_name, 'main')
  expect.equality(list_r.value.trails[1].active, true)

  teardown_test(ctx)
end)

-- Test 2: new_trail creates a generated trail_name
T['new_trail creates a generated trail_name'] = helpers.async_test(function()
  local ctx = setup_test()

  local new_r = ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(new_r.ok, true)
  expect.equality(new_r.value.logical_name, 'repro')
  expect.equality(new_r.value.trail_name, 'loci-parser-fix-main-8x2kqz-repro')

  -- Verify it's persisted
  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  expect.equality(list_r.ok, true)
  expect.equality(#list_r.value.trails, 2)

  teardown_test(ctx)
end)

-- Test 3: new_trail rejects invalid logical names
T['new_trail rejects invalid logical names'] = helpers.async_test(function()
  local ctx = setup_test()

  local invalid_names = { '', 'Main', 'foo/bar', 'foo..bar', 'Foo Bar' }
  for _, name in ipairs(invalid_names) do
    local r = ctx.workspace_service.create_trail(ctx.workspace.workspace_id, name)
    expect.equality(r.ok, false, 'Should reject invalid name: ' .. name)
  end

  teardown_test(ctx)
end)

-- Test 4: new_trail rejects duplicate logical names
T['new_trail rejects duplicate logical names'] = helpers.async_test(function()
  local ctx = setup_test()

  local r1 = ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(r1.ok, true)

  local r2 = ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(r2.ok, false)
  expect.equality(r2.code, 'conflict')

  teardown_test(ctx)
end)

-- Test 5: list_trails sorts deterministically and marks active Trail
T['list_trails sorts deterministically and marks active'] = helpers.async_test(function()
  local ctx = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'zebra')
  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'apple')
  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'banana')
  ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'apple')

  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  expect.equality(list_r.ok, true)
  expect.equality(#list_r.value.trails, 4)
  -- main should be first, then alphabetical
  expect.equality(list_r.value.trails[1].logical_name, 'main')
  expect.equality(list_r.value.trails[2].logical_name, 'apple')
  expect.equality(list_r.value.trails[3].logical_name, 'banana')
  expect.equality(list_r.value.trails[4].logical_name, 'zebra')

  -- apple should be marked active
  expect.equality(list_r.value.trails[2].active, true)
  expect.equality(list_r.value.trails[1].active, false)

  teardown_test(ctx)
end)

-- Test 6: switch_trail updates workspace.wayfinder.active
T['switch_trail updates workspace.wayfinder.active'] = helpers.async_test(function()
  local ctx = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local switch_r = ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(switch_r.ok, true)
  expect.equality(switch_r.value.active, 'repro')

  -- Reload workspace to verify persistence
  local ws_r = ctx.graph.read_workspace(ctx.workspace.workspace_id)
  expect.equality(ws_r.value.wayfinder.active, 'repro')

  teardown_test(ctx)
end)

-- Test 7: switch_trail rejects missing Trail
T['switch_trail rejects missing Trail'] = helpers.async_test(function()
  local ctx = setup_test()

  local r = ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'nonexistent')
  expect.equality(r.ok, false)
  expect.equality(r.code, 'not_found')

  teardown_test(ctx)
end)

-- Test 8: rename_trail updates map key and generated trail_name
T['rename_trail updates map key and trail_name'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  local trail_api = helpers.stub_wayfinder_direct_api()
  ctx.workspace_service = require('loci.service.workspace')

  ctx.graph = require('loci.store.graph')
  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local rename_r = ctx.workspace_service.rename_trail(ctx.workspace.workspace_id, 'repro', 'reproduction')
  expect.equality(rename_r.ok, true)
  expect.equality(rename_r.value.new_logical_name, 'reproduction')
  expect.equality(rename_r.value.new_trail_name, 'loci-parser-fix-main-8x2kqz-reproduction')
  expect.equality(rename_r.value.integration.ok, true)
  expect.equality(#trail_api.renamed, 1)

  -- Verify persistence
  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  local found = false
  for _, trail in ipairs(list_r.value.trails) do
    if trail.logical_name == 'reproduction' then
      found = true
      expect.equality(trail.trail_name, 'loci-parser-fix-main-8x2kqz-reproduction')
    end
  end
  expect.equality(found, true)

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 9: rename_trail preserves active state when renaming active Trail
T['rename_trail preserves active state'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  helpers.stub_wayfinder_direct_api()
  ctx.workspace_service = require('loci.service.workspace')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro')
  local rename_r = ctx.workspace_service.rename_trail(ctx.workspace.workspace_id, 'repro', 'reproduction')
  expect.equality(rename_r.ok, true)

  -- Verify active was updated
  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  for _, trail in ipairs(list_r.value.trails) do
    if trail.logical_name == 'reproduction' then
      expect.equality(trail.active, true)
    elseif trail.logical_name == 'repro' then
      error('repro should not exist after rename')
    end
  end

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 10: rename_trail rejects collision before Wayfinder
T['rename_trail rejects collision'] = helpers.async_test(function()
  local ctx = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local r = ctx.workspace_service.rename_trail(ctx.workspace.workspace_id, 'repro', 'main')
  expect.equality(r.ok, false)
  expect.equality(r.code, 'conflict')

  teardown_test(ctx)
end)

-- Test 11: delete_trail removes inactive non-main Trail
T['delete_trail removes inactive non-main Trail'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  local trail_api = helpers.stub_wayfinder_direct_api()
  ctx.workspace_service = require('loci.service.workspace')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local delete_r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(delete_r.ok, true)
  expect.equality(delete_r.value.integration.ok, true)
  expect.equality(#trail_api.deleted, 1)

  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  for _, trail in ipairs(list_r.value.trails) do
    expect.no_equality(trail.logical_name, 'repro')
  end

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 12: delete_trail refuses deleting main by default
T['delete_trail refuses deleting main by default'] = helpers.async_test(function()
  local ctx = setup_test()

  local r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'main')
  expect.equality(r.ok, false)
  expect.equality(r.code, 'conflict')

  teardown_test(ctx)
end)

-- Test 13: delete_trail refuses deleting last remaining Trail
T['delete_trail refuses deleting last remaining Trail'] = helpers.async_test(function()
  local ctx = setup_test()

  local r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'main', { allow_delete_main = true })
  expect.equality(r.ok, false)
  expect.equality(r.code, 'conflict')

  teardown_test(ctx)
end)

-- Test 14: delete_trail refuses deleting active Trail without switch_to
T['delete_trail refuses deleting active without switch_to'] = helpers.async_test(function()
  local ctx = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro')
  local r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(r.ok, false)
  expect.equality(r.code, 'conflict')

  teardown_test(ctx)
end)

-- Test 15: delete_trail can delete active Trail when switch_to is provided
T['delete_trail deletes active with switch_to'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  helpers.stub_wayfinder_direct_api()
  ctx.workspace_service = require('loci.service.workspace')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro')
  local delete_r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'repro', { switch_to = 'main' })
  expect.equality(delete_r.ok, true)

  local list_r = ctx.workspace_service.list_trails(ctx.workspace.workspace_id)
  expect.equality(list_r.value.active, 'main')

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 16: rename_trail commits graph before Wayfinder; Wayfinder failure is soft warning
T['rename_trail Wayfinder failure after graph commit returns ok with warning'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  -- Stub wayfinder that fails on rename
  package.loaded["wayfinder"] = {
    trail = {
      loaded = {},
      saved = {},
      deleted = {},
      renamed = {},
      load_named = function() end,
      save_named = function() end,
      delete_named = function() end,
      rename = function()
        error("wayfinder unavailable")
      end,
    },
  }
  local ws_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")

  ws_service.create_trail(ctx.workspace.workspace_id, "repro")
  local rename_r = ws_service.rename_trail(ctx.workspace.workspace_id, "repro", "reproduction")

  -- Wayfinder failure must not prevent graph from being committed.
  expect.equality(rename_r.ok, true)
  expect.no_equality(rename_r.value.warnings, nil)
  expect.equality(rename_r.value.integration.ok, false)

  -- Graph IS updated with the new logical name.
  local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(reloaded.wayfinder.trails.reproduction, nil)
  expect.equality(reloaded.wayfinder.trails.repro, nil)

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 17: delete_trail commits graph before Wayfinder; Wayfinder failure is stale-artifact warning
T['delete_trail Wayfinder failure after graph commit returns ok with stale artifact warning'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  -- Stub wayfinder that fails on delete
  package.loaded["wayfinder"] = {
    trail = {
      loaded = {},
      saved = {},
      deleted = {},
      renamed = {},
      load_named = function() end,
      save_named = function() end,
      delete_named = function()
        error("wayfinder unavailable")
      end,
      rename = function() end,
    },
  }
  local ws_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")

  ws_service.create_trail(ctx.workspace.workspace_id, "repro")
  local delete_r = ws_service.delete_trail(ctx.workspace.workspace_id, "repro")

  -- Wayfinder failure must not prevent graph from being committed.
  expect.equality(delete_r.ok, true)
  expect.no_equality(delete_r.value.warnings, nil)
  expect.equality(delete_r.value.integration.ok, false)

  -- Graph IS updated: repro trail deleted.
  local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(reloaded.wayfinder.trails.repro, nil)

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

return T
