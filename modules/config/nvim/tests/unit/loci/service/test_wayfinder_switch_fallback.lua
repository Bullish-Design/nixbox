local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

local function setup_test()
  helpers.reset_modules()
  local ctx = helpers.create_phase8_fixture()
  local called = helpers.install_wayfinder_command_stubs()
  ctx.graph = require('loci.store.graph')
  ctx.workspace_service = require('loci.service.workspace')
  return ctx, called
end

local function teardown_test(ctx)
  helpers.clear_wayfinder_command_stubs()
  ctx.cleanup()
end

-- Test 1: switch_trail writes active Trail before Wayfinder fallback
T['switch_trail writes graph before Wayfinder'] = helpers.async_test(function()
  local ctx, called = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local switched = helpers.expect_ok(ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro'))
  expect.equality(switched.active, 'repro')

  -- Verify graph was written
  local reloaded = helpers.expect_ok(ctx.graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(reloaded.wayfinder.active, 'repro')

  teardown_test(ctx)
end)

-- Test 2: Missing Wayfinder records warning but returns ok
T['Missing Wayfinder is soft failure'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  helpers.clear_wayfinder_command_stubs()
  ctx.workspace_service = require('loci.service.workspace')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local switch_r = ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro')

  -- Should still return ok at top level
  expect.equality(switch_r.ok, true)
  -- But integration should show failure
  expect.equality(switch_r.value.integration.ok, false)

  ctx.cleanup()
end)

-- Test 3: load_trail marks Trail active before load
T['load_trail marks active before load'] = helpers.async_test(function()
  local ctx, called = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'review')
  ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'review')

  -- Load a different trail
  local load_r = helpers.expect_ok(ctx.workspace_service.load_trail(ctx.workspace.workspace_id, 'repro'))
  expect.equality(load_r.active, 'repro')

  -- Verify graph was updated before command was called
  local reloaded = helpers.expect_ok(ctx.graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(reloaded.wayfinder.active, 'repro')

  teardown_test(ctx)
end)

-- Test 4: load_trail returns named-api-unavailable without direct API
T['load_trail returns named-api-unavailable without direct API'] = helpers.async_test(function()
  local ctx, called = setup_test()

  -- Named load is now strict: command-only stubs are insufficient.
  local load_r = helpers.expect_ok(ctx.workspace_service.load_trail(ctx.workspace.workspace_id, 'main'))
  expect.equality(load_r.integration.ok, false)
  expect.equality(load_r.integration.code, 'wayfinder_named_api_unavailable')
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailLoad'), false)

  teardown_test(ctx)
end)

-- Test 5: switch_trail records integration failure without direct API
T['switch_trail records integration failure without direct API'] = helpers.async_test(function()
  local ctx, called = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local switched = helpers.expect_ok(ctx.workspace_service.switch_trail(ctx.workspace.workspace_id, 'repro'))
  expect.equality(switched.integration.ok, false)
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailLoad'), false)

  teardown_test(ctx)
end)

-- Test 6: Direct named load uses the API when available
T['Direct named load with direct API'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  local trail_api = helpers.stub_wayfinder_direct_api()
  ctx.workspace_service = require('loci.service.workspace')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local load_r = helpers.expect_ok(ctx.workspace_service.load_trail(ctx.workspace.workspace_id, 'repro'))

  -- Verify direct API was used
  expect.equality(#trail_api.loaded, 1)
  expect.equality(trail_api.loaded[1], 'loci-parser-fix-main-8x2kqz-repro')
  expect.equality(load_r.integration.mode, 'direct_api')

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

return T
