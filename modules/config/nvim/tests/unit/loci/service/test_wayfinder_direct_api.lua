local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

local function setup_test()
  helpers.reset_modules()
  local ctx = helpers.create_phase8_fixture()
  local trail_api = helpers.stub_wayfinder_direct_api()
  ctx.workspace_service = require('loci.service.workspace')
  return ctx, trail_api
end

local function teardown_test(ctx)
  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end

-- Test 1: capabilities() detects direct named load
T['capabilities detects direct named load'] = helpers.async_test(function()
  local ctx, trail_api = setup_test()

  local wayfinder = require('loci.integrations.wayfinder')
  local caps = wayfinder.capabilities()
  expect.equality(caps.named_load, true)
  expect.equality(caps.named_save, true)
  expect.equality(caps.named_delete, true)
  expect.equality(caps.named_rename, true)

  teardown_test(ctx)
end)

-- Test 2: load_trail uses direct load_named
T['load_trail uses direct load_named'] = helpers.async_test(function()
  local ctx, trail_api = setup_test()

  local load_r = ctx.workspace_service.load_trail(ctx.workspace.workspace_id, 'main')
  expect.equality(load_r.ok, true)
  expect.equality(#trail_api.loaded, 1)
  expect.equality(trail_api.loaded[1], 'loci-parser-fix-main-8x2kqz-main')

  teardown_test(ctx)
end)

-- Test 3: save_active_trail uses direct save_named
T['save_active_trail uses direct save_named'] = helpers.async_test(function()
  local ctx, trail_api = setup_test()

  local save_r = ctx.workspace_service.save_active_trail(ctx.workspace.workspace_id)
  expect.equality(save_r.ok, true)
  expect.equality(#trail_api.saved, 1)
  expect.equality(trail_api.saved[1], 'loci-parser-fix-main-8x2kqz-main')

  teardown_test(ctx)
end)

-- Test 4: rename_trail uses direct rename
T['rename_trail uses direct rename'] = helpers.async_test(function()
  local ctx, trail_api = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local rename_r = ctx.workspace_service.rename_trail(ctx.workspace.workspace_id, 'repro', 'reproduction')
  expect.equality(rename_r.ok, true)
  expect.equality(#trail_api.renamed, 1)
  expect.equality(trail_api.renamed[1][1], 'loci-parser-fix-main-8x2kqz-repro')
  expect.equality(trail_api.renamed[1][2], 'loci-parser-fix-main-8x2kqz-reproduction')

  teardown_test(ctx)
end)

-- Test 5: delete_trail uses direct delete_named
T['delete_trail uses direct delete_named'] = helpers.async_test(function()
  local ctx, trail_api = setup_test()

  ctx.workspace_service.create_trail(ctx.workspace.workspace_id, 'repro')
  local delete_r = ctx.workspace_service.delete_trail(ctx.workspace.workspace_id, 'repro')
  expect.equality(delete_r.ok, true)
  expect.equality(#trail_api.deleted, 1)
  expect.equality(trail_api.deleted[1], 'loci-parser-fix-main-8x2kqz-repro')

  teardown_test(ctx)
end)

-- Test 6: Direct API thrown errors become integration_failed
T['Direct API errors become integration_failed'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  ctx.workspace_service = require('loci.service.workspace')

  -- Create a failing API
  package.loaded['wayfinder'] = {
    trail = {
      load_named = function()
        error('boom')
      end,
    },
  }

  local load_r = ctx.workspace_service.load_trail(ctx.workspace.workspace_id, 'main')
  expect.equality(load_r.ok, true)
  expect.equality(load_r.value.integration.ok, false)

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

return T
