local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

-- Graph is authoritative. Runtime activation is a projection.
-- When the Haunt runtime fails, the graph is already committed and the
-- failure is returned as a warning, not a hard error.

T["haunt_new switch=true commits graph and returns warning on Haunt failure"] = function()
  local ctx = helpers.create_phase7_fixture()
  local test_fn = helpers.async_test(function()
    local workspace_service = require("loci.service.workspace.haunt")
    local graph = require("loci.store.graph")
    local current = helpers.expect_ok(graph.read_current())

    helpers.stub_failing_haunt_api()
    current.workspace_id = ctx.workspace.workspace_id
    helpers.expect_ok(graph.write_current(current))

    local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })

    -- Graph commit succeeds; runtime failure is a projection warning.
    expect.equality(r.ok, true)
    expect.no_equality(r.value.warnings, nil)

    -- Graph IS committed with the new context active.
    local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
    expect.equality(reloaded.haunt.active, "debugging")
    expect.no_equality(reloaded.haunt.contexts.debugging, nil)
  end)
  test_fn()
  ctx.cleanup()
end

T["haunt_rename commits graph and returns warning on Haunt runtime failure"] = function()
  local ctx = helpers.create_phase7_fixture()
  local test_fn = helpers.async_test(function()
    local workspace_service = require("loci.service.workspace.haunt")
    local graph = require("loci.store.graph")
    local current = helpers.expect_ok(graph.read_current())

    helpers.stub_haunt_api()
    current.workspace_id = ctx.workspace.workspace_id
    helpers.expect_ok(graph.write_current(current))
    helpers.expect_ok(workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true }))

    helpers.stub_failing_haunt_api()
    local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")

    -- Graph commit succeeds; runtime failure is a projection warning.
    expect.equality(r.ok, true)
    expect.no_equality(r.value.warnings, nil)

    -- Graph IS updated with the new context name.
    local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
    expect.equality(reloaded.haunt.active, "review")
    expect.no_equality(reloaded.haunt.contexts.review, nil)
    expect.equality(reloaded.haunt.contexts.debugging, nil)
  end)
  test_fn()
  ctx.cleanup()
end

T["haunt_delete commits graph and returns warning on Haunt runtime failure"] = function()
  local ctx = helpers.create_phase7_fixture()
  local test_fn = helpers.async_test(function()
    local workspace_service = require("loci.service.workspace.haunt")
    local graph = require("loci.store.graph")
    local current = helpers.expect_ok(graph.read_current())

    helpers.stub_haunt_api()
    current.workspace_id = ctx.workspace.workspace_id
    helpers.expect_ok(graph.write_current(current))
    helpers.expect_ok(workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true }))

    helpers.stub_failing_haunt_api()
    local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging", {
      switch_to = "main",
    })

    -- Graph commit succeeds; runtime failure is a projection warning.
    expect.equality(r.ok, true)
    expect.no_equality(r.value.warnings, nil)

    -- Graph IS updated: debugging context deleted, active switched to main.
    local reloaded = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
    expect.equality(reloaded.haunt.active, "main")
    expect.equality(reloaded.haunt.contexts.debugging, nil)
  end)
  test_fn()
  ctx.cleanup()
end

return T
