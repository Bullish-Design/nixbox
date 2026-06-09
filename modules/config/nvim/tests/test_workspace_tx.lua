local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

-- ============================================================================
-- tx.read
-- ============================================================================

T["tx.read reads workspace by explicit id"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local tx = require("loci.service.workspace.tx")

  local ws = helpers.expect_ok(workspace_service.create({ name = "TX Read" }))
  local loaded = helpers.expect_ok(tx.read(ws.workspace_id))

  expect.equality(loaded.workspace_id, ws.workspace_id)
  expect.equality(loaded.name, "TX Read")
end)

T["tx.read returns error for invalid workspace id"] = helpers.async_with_initialized_repo(function(ctx)
  local tx = require("loci.service.workspace.tx")
  local r = tx.read("nonexistent-workspace-id-12345")
  helpers.expect_err(r)
end)

-- ============================================================================
-- tx.write
-- ============================================================================

T["tx.write writes and returns workspace"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local tx = require("loci.service.workspace.tx")
  local graph = require("loci.store.graph")

  local ws = helpers.expect_ok(workspace_service.create({ name = "TX Write" }))
  ws.name = "TX Write Updated"

  local written = helpers.expect_ok(tx.write(ws))
  expect.equality(written.name, "TX Write Updated")

  local reloaded = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
  expect.equality(reloaded.name, "TX Write Updated")
end)

T["tx.write rejects non-table input"] = helpers.async_with_initialized_repo(function(ctx)
  local tx = require("loci.service.workspace.tx")
  local r = tx.write("not a table")
  helpers.expect_err(r, "invalid_input")
end)

-- ============================================================================
-- tx.update
-- ============================================================================

T["tx.update writes successful mutation"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local tx = require("loci.service.workspace.tx")
  local result = require("loci.result")
  local graph = require("loci.store.graph")

  local ws = helpers.expect_ok(workspace_service.create({ name = "TX Update" }))

  helpers.expect_ok(tx.update(ws.workspace_id, function(workspace)
    workspace.tabby.label = "Updated Label"
    return result.ok(workspace)
  end))

  local reloaded = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
  expect.equality(reloaded.tabby.label, "Updated Label")
end)

T["tx.update does not write on mutator error"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local tx = require("loci.service.workspace.tx")
  local result = require("loci.result")
  local graph = require("loci.store.graph")

  local ws = helpers.expect_ok(workspace_service.create({ name = "TX Error" }))

  local r = tx.update(ws.workspace_id, function(workspace)
    workspace.name = "Should Not Persist"
    return result.err("stop", "invalid_input")
  end)

  helpers.expect_err(r, "invalid_input")

  local reloaded = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
  expect.equality(reloaded.name, "TX Error")
end)

T["tx.update returns custom payload from mutator"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local tx = require("loci.service.workspace.tx")
  local result = require("loci.result")

  local ws = helpers.expect_ok(workspace_service.create({ name = "TX Payload" }))

  local r = helpers.expect_ok(tx.update(ws.workspace_id, function(workspace)
    workspace.name = "TX Payload Updated"
    return result.ok({ changed = true, workspace_id = workspace.workspace_id })
  end))

  expect.equality(r.changed, true)
  expect.equality(r.workspace_id, ws.workspace_id)
end)

T["tx.update rejects non-function mutator"] = helpers.async_with_initialized_repo(function(ctx)
  local tx = require("loci.service.workspace.tx")
  local r = tx.update("some-id", "not a function")
  helpers.expect_err(r, "invalid_input")
end)

T["tx.update rejects mutator that returns non-Result"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local tx = require("loci.service.workspace.tx")

  local ws = helpers.expect_ok(workspace_service.create({ name = "TX Bad Return" }))

  local r = tx.update(ws.workspace_id, function(workspace)
    return "not a result"
  end)

  helpers.expect_err(r, "invalid_input")
end)

-- ============================================================================
-- Project membership helpers
-- ============================================================================

T["add_workspace_to_project is idempotent"] = helpers.async_with_initialized_repo(function(ctx)
  local project_service = require("loci.service.project")
  local tx = require("loci.service.workspace.tx")
  local graph = require("loci.store.graph")

  local proj = helpers.expect_ok(project_service.create({
    title = "Test Project",
    now = "2026-05-23T10:00:00Z",
  }))

  helpers.expect_ok(tx.add_workspace_to_project(proj.project_id, "ws-1"))
  helpers.expect_ok(tx.add_workspace_to_project(proj.project_id, "ws-1"))

  local reloaded = helpers.expect_ok(graph.read_project(proj.project_id))
  local count = 0
  for _, ws_id in ipairs(reloaded.workspace_ids) do
    if ws_id == "ws-1" then
      count = count + 1
    end
  end
  expect.equality(count, 1)
end)

T["remove_workspace_from_project is idempotent"] = helpers.async_with_initialized_repo(function(ctx)
  local project_service = require("loci.service.project")
  local tx = require("loci.service.workspace.tx")
  local graph = require("loci.store.graph")

  local proj = helpers.expect_ok(project_service.create({
    title = "Test Project",
    now = "2026-05-23T10:00:00Z",
  }))

  helpers.expect_ok(tx.add_workspace_to_project(proj.project_id, "ws-1"))
  helpers.expect_ok(tx.remove_workspace_from_project(proj.project_id, "ws-1"))
  helpers.expect_ok(tx.remove_workspace_from_project(proj.project_id, "ws-1"))

  local reloaded = helpers.expect_ok(graph.read_project(proj.project_id))
  local count = 0
  for _, ws_id in ipairs(reloaded.workspace_ids or {}) do
    if ws_id == "ws-1" then
      count = count + 1
    end
  end
  expect.equality(count, 0)
end)

T["project membership helpers accept nil project_id"] = helpers.async_with_initialized_repo(function(ctx)
  local tx = require("loci.service.workspace.tx")

  local add_r = helpers.expect_ok(tx.add_workspace_to_project(nil, "ws-1"))
  expect.equality(add_r, nil)

  local remove_r = helpers.expect_ok(tx.remove_workspace_from_project(nil, "ws-1"))
  expect.equality(remove_r, nil)
end)

T["project membership helpers accept vim.NIL project_id"] = helpers.async_with_initialized_repo(function(ctx)
  local tx = require("loci.service.workspace.tx")

  local add_r = helpers.expect_ok(tx.add_workspace_to_project(vim.NIL, "ws-1"))
  expect.equality(add_r, nil)

  local remove_r = helpers.expect_ok(tx.remove_workspace_from_project(vim.NIL, "ws-1"))
  expect.equality(remove_r, nil)
end)

return T
