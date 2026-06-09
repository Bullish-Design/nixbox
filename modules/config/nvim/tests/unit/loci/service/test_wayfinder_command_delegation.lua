local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

local function setup_test()
  helpers.reset_modules()
  local ctx = helpers.create_phase8_fixture()
  local called = helpers.install_wayfinder_command_stubs()
  ctx.workspace_service = require('loci.service.workspace')
  return ctx, called
end

local function teardown_test(ctx)
  helpers.clear_wayfinder_command_stubs()
  ctx.cleanup()
end

-- Test 1: save_active_trail fails softly without direct save_named API
T['save_active_trail fails softly without direct save_named API'] = helpers.async_test(function()
  local ctx, called = setup_test()

  local save_r = ctx.workspace_service.save_active_trail(ctx.workspace.workspace_id)
  expect.equality(save_r.ok, true)
  expect.equality(save_r.value.integration.ok, false)
  expect.equality(save_r.value.integration.code, 'wayfinder_named_api_unavailable')
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailSave'), false)

  teardown_test(ctx)
end)

-- Test 2 removed: canonical API does not support save_as delegation options

-- Test 3: load_trail returns integration failure without direct API
T['load_trail returns integration failure without direct API'] = helpers.async_test(function()
  local ctx, called = setup_test()

  -- Command stubs only; no direct API. Named load is strict and returns a soft failure.
  local load_r = ctx.workspace_service.load_trail(ctx.workspace.workspace_id, 'main')
  expect.equality(load_r.ok, true)
  expect.equality(load_r.value.integration.ok, false)
  expect.equality(load_r.value.integration.code, 'wayfinder_named_api_unavailable')
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailLoad'), false)

  teardown_test(ctx)
end)

-- Test 4 removed: canonical API does not expose resume_trail

-- Test 5: show_trail delegates to WayfinderTrailShow
T['show_trail delegates to WayfinderTrailShow'] = helpers.async_test(function()
  local ctx, called = setup_test()

  local show_r = ctx.workspace_service.show_trail(ctx.workspace.workspace_id)
  expect.equality(show_r.ok, true)
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailShow'), true)

  teardown_test(ctx)
end)

-- Test 6: export_trail_quickfix delegates to WayfinderExportTrailQuickfix
T['export_trail_quickfix delegates to WayfinderExportTrailQuickfix'] = helpers.async_test(function()
  local ctx, called = setup_test()

  local export_r = ctx.workspace_service.export_trail_quickfix(ctx.workspace.workspace_id)
  expect.equality(export_r.ok, true)
  expect.equality(vim.tbl_contains(called, 'WayfinderExportTrailQuickfix'), true)

  teardown_test(ctx)
end)

-- Test 7: delete_trail commits graph and returns stale artifact warning without direct API
T['delete_trail commits graph with warning without direct API'] = helpers.async_test(function()
  local ctx, called = setup_test()
  local graph = require('loci.store.graph')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local delete_r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'repro')

  -- Graph commit succeeds; Wayfinder projection failure is a stale artifact warning.
  expect.equality(delete_r.ok, true)
  expect.no_equality(delete_r.value.warnings, nil)
  expect.equality(delete_r.value.integration.ok, false)

  -- Graph IS updated: repro trail deleted.
  local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(reloaded.wayfinder.trails.repro, nil)

  -- Command fallback must not be called for managed delete operations.
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailDelete'), false)

  teardown_test(ctx)
end)

-- Test 8: rename_trail commits graph and returns warning without direct API
T['rename_trail commits graph with warning without direct API'] = helpers.async_test(function()
  local ctx, called = setup_test()
  local graph = require('loci.store.graph')

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local rename_r = ctx.workspace_service.rename_trail(ctx.workspace.workspace_id, 'repro', 'reproduction')

  -- Graph commit succeeds; Wayfinder projection failure is a warning.
  expect.equality(rename_r.ok, true)
  expect.no_equality(rename_r.value.warnings, nil)
  expect.equality(rename_r.value.integration.ok, false)

  -- Graph IS updated with the new logical name.
  local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(reloaded.wayfinder.trails.reproduction, nil)
  expect.equality(reloaded.wayfinder.trails.repro, nil)

  -- Command fallback must not be called for managed rename operations.
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailRename'), false)

  teardown_test(ctx)
end)

-- Test 9: Missing commands return integration_unavailable
T['Missing commands return integration_unavailable'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  helpers.clear_wayfinder_command_stubs()
  ctx.workspace_service = require('loci.service.workspace')

  local save_r = ctx.workspace_service.save_active_trail(ctx.workspace.workspace_id)
  expect.equality(save_r.ok, true)
  expect.equality(save_r.value.integration.ok, false)

  ctx.cleanup()
end)

return T
