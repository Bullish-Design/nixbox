local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()

  -- Set up haunt stub
  package.loaded["haunt.api"] = {
    changed_to = nil,
    change_data_dir = function(path)
      package.loaded["haunt.api"].changed_to = path
      return true
    end,
  }

  -- Set up wayfinder command stub
  local called = {}
  vim.api.nvim_create_user_command("WayfinderTrailResume", function()
    table.insert(called, "resume")
  end, {})
  package._wayfinder_called = called
end

T["activation calls haunt.api.change_data_dir"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    local haunt = package.loaded["haunt.api"]
    expect.no_equality(haunt.changed_to, nil)
    helpers.expect_match(haunt.changed_to, "haunt/workspaces")
  end)

  test_fn()
  ctx.cleanup()
end

T["activation does not call WayfinderTrailResume after D2"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- Phase 6 fixture has wayfinder trail config; without direct API, activation should
    -- report a soft named-api-unavailable failure. Resume fallback must NOT be called.
    local called = package._wayfinder_called
    expect.equality(#called, 0)
    expect.equality(value.integrations.wayfinder.ok, false)
    expect.equality(value.integrations.wayfinder.code, "wayfinder_named_api_unavailable")
    expect.equality(value.integrations.wayfinder.err, "Wayfinder direct named API is unavailable")
  end)

  test_fn()
  ctx.cleanup()
end

T["missing wayfinder trail config is a no-op success"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local graph = require("loci.store.graph")

    local ws_r = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
    ws_r.wayfinder = {
      active = "main",
      trails = {
        main = {},
      },
    }
    helpers.expect_ok(graph.write_workspace(ws_r))

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- With no trails configured, Wayfinder activation is a no-op success.
    expect.equality(value.integrations.wayfinder.ok, true)
    expect.equality(value.integrations.wayfinder.action, "none")
    expect.equality(value.integrations.wayfinder.reason, "no_trail_config")
  end)

  test_fn()
  ctx.cleanup()
end

return T
