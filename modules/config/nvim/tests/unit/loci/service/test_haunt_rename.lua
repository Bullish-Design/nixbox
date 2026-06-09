local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["haunt_rename updates context key"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(updated.haunt.contexts.review, nil)
end)

T["haunt_rename removes old key"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.contexts.debugging, nil)
end)

T["haunt_rename updates canonical data directory"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(
    updated.haunt.contexts.review.data_dir,
    ".loci/integrations/haunt/workspaces/" .. updated.workspace_id .. "/review"
  )
end)

T["haunt_rename moves existing files to new directory"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.write_file(ctx.haunt_root .. "/debugging/bookmarks.json", "{}\n")

  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)
  expect.equality(vim.fn.filereadable(ctx.haunt_root .. "/review/bookmarks.json"), 1)
end)

T["haunt_rename updates active context when renaming active"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.equality(updated.haunt.active, "review")
end)

T["haunt_rename calls change_data_dir when active context is renamed and workspace is active"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local calls = helpers.stub_haunt_api()
  local current = helpers.expect_ok(graph.read_current())

  current.workspace_id = ctx.workspace.workspace_id
  helpers.expect_ok(graph.write_current(current))
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)
  expect.equality(#calls, 1)
end)

T["haunt_rename returns not_found for missing context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "nonexistent", "review")
  helpers.expect_err(r, "not_found")
end)

T["haunt_rename returns conflict for existing target"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "review")

  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_err(r, "conflict")
end)

T["haunt_rename returns invalid_input for invalid names"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "INVALID")
  helpers.expect_err(r, "invalid_input")
end)

T["haunt_rename commits graph with warning when target directory already exists"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.async_mkdirp(ctx.haunt_root .. "/review")

  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")

  -- Graph commit succeeds; directory move failure is a projection warning.
  expect.equality(r.ok, true)
  expect.no_equality(r.value.warnings, nil)

  -- Graph IS updated with the new context name.
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(updated.haunt.contexts.review, nil)
  expect.equality(updated.haunt.contexts.debugging, nil)
end)

T["haunt_rename commits graph before moving directory"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")

  local r = workspace_service.haunt_rename(ctx.workspace.workspace_id, "debugging", "review")
  helpers.expect_ok(r)

  -- Graph must be committed with the new name immediately after rename.
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(updated.haunt.contexts.review, nil)
  expect.equality(updated.haunt.contexts.debugging, nil)
end)

return T
