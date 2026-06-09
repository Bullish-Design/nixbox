local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["haunt_switch switches to existing context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.active, "debugging")
end)

T["haunt_switch returns not_found for missing context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "nonexistent")
  helpers.expect_err(r, "not_found")
end)

T["haunt_switch ensures data directory exists"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.async_rm_rf(ctx.haunt_root .. "/debugging")

  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  expect.equality(vim.fn.isdirectory(ctx.haunt_root .. "/debugging"), 1)
end)

T["haunt_switch calls haunt api when switching active workspace"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local calls = helpers.stub_haunt_api()
  local current = helpers.expect_ok(graph.read_current())

  current.workspace_id = ctx.workspace.workspace_id
  helpers.expect_ok(graph.write_current(current))
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  expect.equality(#calls, 1)
end)

T["haunt_switch does not call haunt api for inactive workspace"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local calls = helpers.stub_haunt_api()

  vim.t.loci_workspace_id = "other-workspace"
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  expect.equality(#calls, 0)
end)

T["haunt_switch handles missing haunt as soft failure"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local current = helpers.expect_ok(graph.read_current())

  current.workspace_id = ctx.workspace.workspace_id
  helpers.expect_ok(graph.write_current(current))
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.active, "debugging")
end)

T["haunt_switch commits graph and returns warning on Haunt failure"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.stub_failing_haunt_api()
  local current = helpers.expect_ok(graph.read_current())

  current.workspace_id = ctx.workspace.workspace_id
  helpers.expect_ok(graph.write_current(current))
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")

  -- Graph commit succeeds; runtime failure is a projection warning.
  expect.equality(r.ok, true)
  expect.no_equality(r.value.warnings, nil)

  -- Graph IS committed with the new active context.
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.active, "debugging")
end)

T["haunt_switch can repair runtime drift"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local calls = helpers.stub_haunt_api()
  local current = helpers.expect_ok(graph.read_current())

  current.workspace_id = ctx.workspace.workspace_id
  helpers.expect_ok(graph.write_current(current))
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "main")
  helpers.expect_ok(r)
  expect.equality(#calls, 1)
end)

T["haunt_switch commits graph before activating runtime"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")

  -- Switch without active workspace so runtime is skipped.
  local r = workspace_service.haunt_switch(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)

  -- Graph must be committed immediately after switch.
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.active, "debugging")
end)

return T
