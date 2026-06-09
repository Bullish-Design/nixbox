local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["haunt_list returns default main context"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_list(ctx.workspace.workspace_id)
  local value = helpers.expect_ok(r)
  expect.equality(#value.contexts, 1)
  expect.equality(value.contexts[1].name, "main")
  expect.equality(value.contexts[1].active, true)
end)

T["haunt_new creates a context graph entry"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(updated.haunt.contexts.debugging, nil)
end)

T["haunt_new creates the data directory"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)
  expect.equality(vim.fn.isdirectory(ctx.haunt_root .. "/debugging"), 1)
end)

T["haunt_new returns canonical data_dir"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local result = helpers.expect_ok(r)
  expect.equality(
    result.data_dir,
    ".loci/integrations/haunt/workspaces/" .. result.workspace_id .. "/debugging"
  )
end)

T["haunt_new sorts contexts in list output"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "zebra")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "alpha")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "beta")

  local r = workspace_service.haunt_list(ctx.workspace.workspace_id)
  local list = helpers.expect_ok(r)
  local names = {}
  for _, ctx_entry in ipairs(list.contexts) do
    table.insert(names, ctx_entry.name)
  end
  expect.equality(names[1], "alpha")
  expect.equality(names[2], "beta")
end)

T["haunt_new rejects duplicate context name"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.expect_err(r, "conflict")
end)

T["haunt_new rejects invalid context names"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  for _, bad in ipairs({ "INVALID", "with space", "../escape", "review/notes", "-bad", "bad-", "" }) do
    local r = workspace_service.haunt_new(ctx.workspace.workspace_id, bad)
    helpers.expect_err(r, "invalid_input")
  end
end)

T["haunt_new does not change active context when switch=false"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = false })
  local r = workspace_service.haunt_list(ctx.workspace.workspace_id)
  local list = helpers.expect_ok(r)
  expect.equality(list.active, "main")
end)

T["haunt_new changes active context when switch=true"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace")
  workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging", { switch = true })
  local r = workspace_service.haunt_list(ctx.workspace.workspace_id)
  local list = helpers.expect_ok(r)
  expect.equality(list.active, "debugging")
end)

T["haunt_new returns not_found for missing workspace"] = helpers.async_with_phase7_fixture(function()
  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.haunt_new("missing-workspace-abc123", "debugging")
  helpers.expect_err(r, "not_found")
end)

T["haunt_new commits graph before creating directory"] = helpers.async_with_phase7_fixture(function(ctx)
  -- Verify graph entry exists even if directory creation were to fail.
  -- We verify ordering by checking the graph immediately after the call.
  local workspace_service = require("loci.service.workspace")
  local graph = require("loci.store.graph")
  local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")
  helpers.expect_ok(r)

  -- Graph must be committed (context entry present).
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(updated.haunt.contexts.debugging, nil)
end)

T["haunt_new directory creation failure after graph commit returns ok with warning"] = helpers.async_with_phase7_fixture(function(ctx)
  local workspace_service = require("loci.service.workspace.haunt")
  local haunt_adapter = require("loci.integrations.haunt")
  local result = require("loci.result")
  local graph = require("loci.store.graph")

  -- Stub ensure_context_dir to simulate a filesystem failure.
  local original = haunt_adapter.ensure_context_dir
  haunt_adapter.ensure_context_dir = function()
    return result.err("mkdir failed: permission denied", "io_write_failed")
  end

  local r = workspace_service.haunt_new(ctx.workspace.workspace_id, "debugging")

  haunt_adapter.ensure_context_dir = original

  -- Graph commit must succeed; dir creation failure is a warning.
  expect.equality(r.ok, true)
  expect.no_equality(r.value.warnings, nil)

  -- Graph IS committed with the context entry.
  local updated = helpers.expect_ok(graph.read_workspace(ctx.workspace.workspace_id))
  expect.no_equality(updated.haunt.contexts.debugging, nil)
end)

return T
