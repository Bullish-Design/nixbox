local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
end

T["missing Resession does not fail activation"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    -- Make resession unavailable
    package.loaded["resession"] = nil

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- Should succeed with soft failure recorded
    expect.equality(value.integrations.resession.ok, false)
    expect.equality(value.integrations.resession.code, "integration_unavailable")
  end)

  test_fn()
  ctx.cleanup()
end

T["missing Haunt does not fail activation"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    -- Make haunt unavailable
    package.loaded["haunt.api"] = nil

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- Should succeed with soft failure recorded
    expect.equality(value.integrations.haunt.ok, false)
  end)

  test_fn()
  ctx.cleanup()
end

T["missing Wayfinder does not fail activation"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    -- Make WayfinderTrailResume unavailable by removing it
    -- This is done via command not existing, which is handled by wayfinder integration

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- Should succeed - wayfinder unavailability is soft failure
    expect.equality(value.integrations.wayfinder.ok, false)
  end)

  test_fn()
  ctx.cleanup()
end

T["missing Tabby does not fail activation"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    -- Tabby integration should work even without tabby plugin
    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- Should succeed - tabby falls back to native tabs
    expect.equality(value.integrations.tabby.ok, true)
    expect.equality(value.integrations.tabby.tab_id ~= nil, true)
  end)

  test_fn()
  ctx.cleanup()
end

return T
