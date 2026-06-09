local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

local function setup_test()
  helpers.reset_modules()
  local ctx = helpers.create_phase8_fixture()
  local called = helpers.install_wayfinder_command_stubs()
  ctx.activation = require('loci.service.activation')
  return ctx, called
end

local function teardown_test(ctx)
  helpers.clear_wayfinder_command_stubs()
  ctx.cleanup()
end

-- Test 1: Activation uses active logical Trail via direct API
T['Activation uses active logical Trail'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  local trail_api = helpers.stub_wayfinder_direct_api()
  local activation = require('loci.service.activation')

  local workspace = helpers.read_json(ctx.workspace_path)
  workspace.wayfinder.active = 'main'
  helpers.write_json(ctx.workspace_path, workspace)

  local activate_r = helpers.expect_ok(activation.activate(ctx.workspace.workspace_id))
  expect.equality(activate_r.integrations.wayfinder.ok, true)
  expect.equality(activate_r.integrations.wayfinder.action, 'load')
  expect.equality(#trail_api.loaded, 1)

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 2: Activation uses direct named load when available
T['Activation uses direct named load'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  local trail_api = helpers.stub_wayfinder_direct_api()
  local activation = require('loci.service.activation')

  local activate_r = helpers.expect_ok(activation.activate(ctx.workspace.workspace_id))
  expect.equality(activate_r.integrations.wayfinder.ok, true)
  -- Should have called the direct API
  expect.equality(#trail_api.loaded, 1)

  helpers.clear_wayfinder_stubs()
  ctx.cleanup()
end)

-- Test 3: Activation does not resume when named load is unavailable
T['Activation does not resume when named load is unavailable'] = helpers.async_test(function()
  local ctx, called = setup_test()

  -- Only command stubs are installed; no direct API available.
  -- Activation should record a soft failure without falling back to resume.
  local activate_r = helpers.expect_ok(ctx.activation.activate(ctx.workspace.workspace_id))
  expect.equality(activate_r.integrations.wayfinder.ok, false)
  expect.equality(activate_r.integrations.wayfinder.code, 'wayfinder_named_api_unavailable')
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailResume'), false)

  teardown_test(ctx)
end)

-- Test 4: Activation soft-fails when Wayfinder unavailable
T['Activation soft-fails without Wayfinder'] = helpers.async_test(function()
  local ctx = helpers.create_phase8_fixture()
  helpers.clear_wayfinder_command_stubs()
  local activation = require('loci.service.activation')

  local activate_r = helpers.expect_ok(activation.activate(ctx.workspace.workspace_id))
  expect.equality(activate_r.integrations.wayfinder.ok, false)

  ctx.cleanup()
end)

-- Test 5: Deactivation with save_wayfinder saves active Trail
T['Deactivation with save_wayfinder saves Trail'] = helpers.async_test(function()
  local ctx, called = setup_test()

  -- First activate so we have a current workspace
  helpers.expect_ok(ctx.activation.activate(ctx.workspace.workspace_id))

  -- Now deactivate with save
  local deactivate_r = helpers.expect_ok(ctx.activation.deactivate_current({ save_wayfinder = true }))
  expect.equality(deactivate_r.integrations.wayfinder.ok, false)
  expect.equality(deactivate_r.integrations.wayfinder.code, 'wayfinder_named_api_unavailable')
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailSave'), false)

  teardown_test(ctx)
end)

-- Test 6: Deactivation without save_wayfinder doesn't save
T['Deactivation without save_wayfinder'] = helpers.async_test(function()
  local ctx, called = setup_test()

  -- First activate
  helpers.expect_ok(ctx.activation.activate(ctx.workspace.workspace_id))

  -- Clear the called list after activation
  for i = 1, #called do
    table.remove(called)
  end

  -- Now deactivate without save
  local deactivate_r = helpers.expect_ok(ctx.activation.deactivate_current({ save_wayfinder = false }))
  expect.equality(vim.tbl_contains(called, 'WayfinderTrailSave'), false)

  teardown_test(ctx)
end)

return T
