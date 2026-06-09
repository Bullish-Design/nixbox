local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["Archive: rejects fallback workspace"] = helpers.async_with_initialized_repo(function(ctx)
  local graph = require("loci.store.graph")
  local repo = helpers.expect_ok(graph.read_repository())
  local fallback_id = repo.default_workspace_id

  local workspace_service = require("loci.service.workspace")
  local r = workspace_service.archive(fallback_id)
  helpers.expect_err(r, "invalid_input")
end)

T["Archive: allows archiving regular workspace"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local ws = helpers.expect_ok(workspace_service.create({
    name = "Test Workspace",
    now = "2026-05-23T10:00:00Z",
  }))

  helpers.expect_ok(workspace_service.archive(ws.workspace_id))

  local graph = require("loci.store.graph")
  local archived_ws = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
  expect.no_equality(archived_ws.archive, nil)
end)

T["Archive: preserves archive reason"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local ws = helpers.expect_ok(workspace_service.create({
    name = "Test Workspace",
    now = "2026-05-23T10:00:00Z",
  }))

  helpers.expect_ok(workspace_service.archive(ws.workspace_id, { reason = "Project completed" }))

  local graph = require("loci.store.graph")
  local archived_ws = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
  expect.equality(archived_ws.archive.reason, "Project completed")
end)

T["Archive: removes from project when requested"] = helpers.async_with_initialized_repo(function(ctx)
  local project_service = require("loci.service.project")
  local proj = helpers.expect_ok(project_service.create({
    title = "Test Project",
    now = "2026-05-23T10:00:00Z",
  }))

  local workspace_service = require("loci.service.workspace")
  local ws = helpers.expect_ok(workspace_service.create({
    name = "Test Workspace",
    project_id = proj.project_id,
    now = "2026-05-23T10:00:00Z",
  }))

  helpers.expect_ok(workspace_service.archive(ws.workspace_id, { remove_from_project = true }))

  local graph = require("loci.store.graph")
  local proj_check = helpers.expect_ok(graph.read_project(proj.project_id))
  local found = false
  for _, id in ipairs(proj_check.workspace_ids or {}) do
    if id == ws.workspace_id then
      found = true
      break
    end
  end
  expect.equality(found, false)
end)

T["workspace archive implementation exists only in archive module"] = function()
  local core = require("loci.service.workspace.core")
  local archive = require("loci.service.workspace.archive")
  expect.equality(type(archive.archive), "function")
  expect.equality(core.archive, nil)
end

return T
