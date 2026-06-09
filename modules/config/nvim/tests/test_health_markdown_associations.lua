-- Test health checks for V3 markdown knowledge associations.

local H = require("tests.helpers")
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

local function before_test()
  H.reset_modules()
  require("loci.config").reset()
end

local function v3_project(opts)
  return {
    schema_version = 1,
    project_id = opts.project_id,
    content_path = opts.content_path,
    title_cache = opts.title or "Test Project",
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

T["Health: Missing project markdown reports warning"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local project = v3_project({
      project_id = "test-project-abc123",
      content_path = "projects/nonexistent.md",
    })
    H.write_json(ctx.loci_root .. "/graph/projects/" .. project.project_id .. ".json", project)

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "project_markdown_missing", "warn")
  end)
end)

T["Health: Project markdown loci_id mismatch reported"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local project = v3_project({
      project_id = "test-project-abc123",
      content_path = "projects/test.md",
    })

    local markdown_content = table.concat({
      "---",
      "loci_id: different-id-456",
      "title: Test Project",
      "---",
      "",
      "# Test Project",
    }, "\n")

    vim.fn.mkdir(ctx.loci_root .. "/content/projects", "p")
    H.write_json(ctx.loci_root .. "/graph/projects/" .. project.project_id .. ".json", project)
    H.write_file(ctx.loci_root .. "/content/projects/test.md", markdown_content)

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "project_markdown_loci_id_mismatch", "error")
  end)
end)

T["Health: Missing workspace knowledge markdown reports warning"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local workspace_path = ctx.loci_root .. "/graph/workspaces/" .. ctx.fallback_workspace.workspace_id .. ".json"
    local workspace = H.read_json(workspace_path)
    workspace.knowledge.objects = {
      {
        type = "task",
        loci_id = "missing-task-abc123",
        content_path = "tasks/missing-task.md",
        title_cache = "Missing Task",
        role = "primary",
      },
    }
    workspace.knowledge.primary_loci_id = "missing-task-abc123"
    H.write_json(workspace_path, workspace)

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "workspace_knowledge_missing", "warn")
  end)
end)

T["Health: Workspace knowledge loci_id mismatch reported"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local workspace_path = ctx.loci_root .. "/graph/workspaces/" .. ctx.fallback_workspace.workspace_id .. ".json"
    local workspace = H.read_json(workspace_path)
    workspace.knowledge.objects = {
      {
        type = "task",
        loci_id = "task-object-abc123",
        content_path = "tasks/task-object.md",
        title_cache = "Task Object",
        role = "primary",
      },
    }
    workspace.knowledge.primary_loci_id = "task-object-abc123"

    local markdown_content = table.concat({
      "---",
      "loci_id: different-task-abc123",
      "title: Task Object",
      "---",
      "",
      "# Task Object",
    }, "\n")

    vim.fn.mkdir(ctx.loci_root .. "/content/tasks", "p")
    H.write_json(workspace_path, workspace)
    H.write_file(ctx.loci_root .. "/content/tasks/task-object.md", markdown_content)

    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))
    H.expect_health_status(report, "workspace_knowledge_loci_id_mismatch", "error")
  end)
end)

T["Health: Health report structure is valid"] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local report = H.expect_ok(require("loci.health").collect({ root = ctx.tmpdir }))

    expect.no_equality(report, nil)
    expect.no_equality(report.root, nil)
    expect.no_equality(report.items, nil)
    expect.equality(type(report.items), "table")
  end)
end)

return T
