local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function fixed_clock()
  return "2026-05-23T12:00:00-04:00"
end

local function create_test_markdown(rel_path, title, loci_type)
  local path_module = require("loci.store.path")
  local abs_path = path_module.must_abs(rel_path)
  local parent = abs_path:match("^(.+)/[^/]*$")
  if parent then
    helpers.async_mkdirp(parent)
  end

  local frontmatter = vim.json.encode({
    title = title,
    type = loci_type or "task",
  })

  local content = "---\n" .. frontmatter .. "\n---\n\nContent here.\n"
  helpers.async_write_file(abs_path, content)
  return abs_path
end

T["add_knowledge() adds first markdown to workspace"] = helpers.async_with_initialized_repo(function(ctx)
    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    create_test_markdown(".loci/content/tasks/fix-parser.md", "Fix parser", "task")

    local updated = helpers.expect_ok(workspace_service.add_knowledge(
      ws.workspace_id,
      "tasks/fix-parser.md",
      { role = "primary" }
    ))

    expect.equality(#updated.knowledge.objects, 1)
    expect.equality(updated.knowledge.objects[1].type, "task")
    expect.equality(updated.knowledge.objects[1].role, "primary")
end)

T["add_knowledge() adds multiple markdown to workspace"] = helpers.async_with_initialized_repo(function(ctx)
    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    create_test_markdown(".loci/content/tasks/fix-parser.md", "Fix parser", "task")
    create_test_markdown(".loci/content/notes/design.md", "Design notes", "note")

    local ws1 = helpers.expect_ok(workspace_service.add_knowledge(
      ws.workspace_id,
      "tasks/fix-parser.md"
    ))
    expect.equality(#ws1.knowledge.objects, 1)

    local ws2 = helpers.expect_ok(workspace_service.add_knowledge(
      ws1.workspace_id,
      "notes/design.md"
    ))
    expect.equality(#ws2.knowledge.objects, 2)
end)

T["add_knowledge() same loci_id twice does not duplicate"] = helpers.async_with_initialized_repo(function(ctx)
    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    create_test_markdown(".loci/content/tasks/fix-parser.md", "Fix parser", "task")

    local ws1 = helpers.expect_ok(workspace_service.add_knowledge(
      ws.workspace_id,
      "tasks/fix-parser.md"
    ))
    local ws2 = helpers.expect_ok(workspace_service.add_knowledge(
      ws1.workspace_id,
      "tasks/fix-parser.md",
      { role = "implementation" }
    ))

    expect.equality(#ws2.knowledge.objects, 1)
    expect.equality(ws2.knowledge.objects[1].role, "implementation")
end)

T["remove_knowledge() removes association but not file"] = helpers.async_with_initialized_repo(function(ctx)
    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    local md_path = create_test_markdown(".loci/content/tasks/fix-parser.md", "Fix parser", "task")

    local ws1 = helpers.expect_ok(workspace_service.add_knowledge(
      ws.workspace_id,
      "tasks/fix-parser.md"
    ))

    local loci_id = ws1.knowledge.objects[1].loci_id

    local ws2 = helpers.expect_ok(workspace_service.remove_knowledge(
      ws1.workspace_id,
      loci_id
    ))

    expect.equality(#ws2.knowledge.objects, 0)
    expect.equality(vim.fn.filereadable(md_path), 1)
end)

T["remove_knowledge() missing knowledge returns not_found"] = helpers.async_with_initialized_repo(function(ctx)
    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    local err = workspace_service.remove_knowledge(
      ws.workspace_id,
      "missing-id-aaaaaa"
    )

    helpers.expect_err(err, "not_found")
end)

T["add_knowledge() with invalid workspace does not mutate markdown"] = helpers.async_with_initialized_repo(function(ctx)
    local workspace_service = require("loci.service.workspace")
    local fs = require("loci.store.fs")
    local markdown = require("loci.store.markdown")
    local abs_path = create_test_markdown(".loci/content/tasks/no-workspace.md", "No Workspace", "task")

    local add_r = workspace_service.add_knowledge("missing-workspace-aaaaaa", "tasks/no-workspace.md")
    helpers.expect_err(add_r, "not_found")

    local raw_r = helpers.expect_ok(fs.read_file(abs_path))
    local inspection = markdown.parse_frontmatter(markdown.split_frontmatter(raw_r).raw_frontmatter, {})
    expect.equality(inspection.ok, true)
    expect.equality(inspection.value.frontmatter.loci_id, nil)
end)

return T
