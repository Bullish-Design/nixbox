local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["haunt_delete returns not_found for missing context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "nonexistent")
  helpers.expect_err(r, "not_found")
end)

T["haunt_delete removes graph entry for empty context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.contexts.debugging, nil)
end)

T["haunt_delete removes directory for empty context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  expect.equality(vim.fn.isdirectory(ctx.haunt_root .. "/debugging"), 0)
end)

T["haunt_delete returns conflict for non-empty without confirmation"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.write_file(ctx.haunt_root .. "/debugging/bookmarks.json", "{}\n")

  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging")
  helpers.expect_err(r, "conflict")
  expect.equality(r.meta.requires_confirmation, true)
end)

T["haunt_delete removes non-empty directory with confirmation"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.write_file(ctx.haunt_root .. "/debugging/bookmarks.json", "{}\n")

  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging", { confirm = true })
  helpers.expect_ok(r)
  expect.equality(vim.fn.isdirectory(ctx.haunt_root .. "/debugging"), 0)
end)

T["haunt_delete removes graph entry but preserves data with keep_data"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.write_file(ctx.haunt_root .. "/debugging/bookmarks.json", "{}\n")

  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging", { keep_data = true })
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.contexts.debugging, nil)
  expect.equality(vim.fn.isdirectory(ctx.haunt_root .. "/debugging"), 1)
end)

T["haunt_delete rejects active delete without switch_to"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging")
  helpers.expect_err(r, "invalid_input")
end)

T["haunt_delete updates active context when deleting active with switch_to"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging", {
    switch_to = "main",
  })
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.active, "main")
end)

T["haunt_delete calls change_data_dir when active delete targets active workspace"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local calls = helpers.stub_haunt_api()
  local current = helpers.expect_ok(graph.read_current())

  current.workspace_id = ctx.workspace.workspace_id
  helpers.expect_ok(graph.write_current(current))
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging", {
    switch_to = "main",
  })
  helpers.expect_ok(r)
  expect.equality(#calls, 1)
end)

T["haunt_delete rejects deletion of last context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "main")
  helpers.expect_err(r, "conflict")
end)

T["haunt_delete rejects switch_to as itself"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local r = workspace_service.haunt_delete(ctx.workspace.workspace_id, "debugging", {
    switch_to = "debugging",
  })
  helpers.expect_err(r, "invalid_input")
end)

return T
