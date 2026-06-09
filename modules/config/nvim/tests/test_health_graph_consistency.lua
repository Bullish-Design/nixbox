-- Test health checks for V3 graph consistency.

local H = require("tests.helpers")
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

local function before_test()
  H.reset_modules()
  require("loci.config").reset()
end

local function v3_project(id, title)
  return {
    schema_version = 1,
    project_id = id,
    content_path = "projects/" .. id .. ".md",
    title_cache = title,
    status_cache = "active",
    workspace_ids = {},
    linked_files = {},
    cache = { task_loci_ids = {}, issue_loci_ids = {}, note_loci_ids = {} },
    provenance = {
      created_at = "2026-05-23T10:00:00Z",
      last_refreshed_at = "2026-05-23T10:00:00Z",
    },
  }
end

T["Health: Missing current.json reported"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    H.remove_file(ctx.loci_root .. "/graph/current.json")

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "current_json_missing", "error")
  end)
end)

T["Health: Malformed current.json reported"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    H.write_invalid_json(ctx.loci_root .. "/graph/current.json", "{ bad json }")

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "current_json_decode_failed", "error")
  end)
end)

T["Health: Current repository mismatch reported"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    H.write_json(ctx.loci_root .. "/graph/current.json", {
      repository_id = "different-repo-abc123",
      project_id = vim.NIL,
      workspace_id = ctx.fallback_workspace.workspace_id,
      activated_at = "2026-05-23T10:00:00Z",
    })

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "current_repository_mismatch", "error")
  end)
end)

T["Health: Current workspace missing reports warning"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    H.write_json(ctx.loci_root .. "/graph/current.json", {
      repository_id = ctx.repository.repository_id,
      project_id = vim.NIL,
      workspace_id = "does-not-exist-123456",
      activated_at = "2026-05-23T10:00:00Z",
    })

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "current_workspace_missing", "warn")
  end)
end)

T["Health: Missing default workspace reports error"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    H.remove_file(ctx.loci_root .. "/graph/workspaces/" .. ctx.fallback_workspace.workspace_id .. ".json")

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "fallback_workspace_missing", "error")
  end)
end)

T["Health: Invalid default workspace JSON reported"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    H.write_invalid_json(
      ctx.loci_root .. "/graph/workspaces/" .. ctx.fallback_workspace.workspace_id .. ".json",
      "{ malformed json }"
    )

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "fallback_workspace_invalid", "error")
  end)
end)

T["Health: Empty projects directory handled"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    local empty_item = H.find_health_item(report, "project_graph_empty")
    expect.no_equality(empty_item, nil)
    expect.equality(empty_item.status, "info")
  end)
end)

T["Health: Multiple V3 projects in graph counted correctly"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    for _, project in ipairs({
      v3_project("project-one-abc123", "Project One"),
      v3_project("project-two-abc123", "Project Two"),
      v3_project("project-three-abc123", "Project Three"),
    }) do
      H.write_json(ctx.loci_root .. "/graph/projects/" .. project.project_id .. ".json", project)
    end

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    local count_item = H.find_health_item(report, "project_graph_valid")
    expect.no_equality(count_item, nil)
    expect.equality(count_item.message:find("3 project") ~= nil, true)
  end)
end)

return T
