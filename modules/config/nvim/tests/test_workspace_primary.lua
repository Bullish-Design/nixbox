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
  local frontmatter = vim.json.encode({ title = title, type = loci_type or "task" })
  local content = "---\n" .. frontmatter .. "\n---\n\nContent here.\n"
  helpers.async_write_file(abs_path, content)
  return abs_path
end

T["set_primary() succeeds for associated object"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local ws = helpers.expect_ok(workspace_service.create({ name = "Test Workspace", clock = fixed_clock }))
  create_test_markdown(".loci/content/tasks/fix-parser.md", "Fix parser", "task")
  local ws1 = helpers.expect_ok(workspace_service.add_knowledge(ws.workspace_id, "tasks/fix-parser.md"))
  local loci_id = ws1.knowledge.objects[1].loci_id
  local ws2 = helpers.expect_ok(workspace_service.set_primary(ws1.workspace_id, loci_id))
  expect.equality(ws2.knowledge.primary_loci_id, loci_id)
end)

T["set_primary() rejects unassociated loci_id"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local ws = helpers.expect_ok(workspace_service.create({ name = "Test Workspace", clock = fixed_clock }))
  local err = workspace_service.set_primary(ws.workspace_id, "missing-id-aaaaaa")
  helpers.expect_err(err, "invalid_input")
end)

T["remove_knowledge() clears primary when primary is removed"] = helpers.async_with_initialized_repo(function(ctx)
  local workspace_service = require("loci.service.workspace")
  local ws = helpers.expect_ok(workspace_service.create({ name = "Test Workspace", clock = fixed_clock }))
  create_test_markdown(".loci/content/tasks/fix-parser.md", "Fix parser", "task")
  local ws1 = helpers.expect_ok(workspace_service.add_knowledge(
    ws.workspace_id,
    "tasks/fix-parser.md",
    { primary = true }
  ))
  local loci_id = ws1.knowledge.objects[1].loci_id
  local ws2 = helpers.expect_ok(workspace_service.remove_knowledge(ws1.workspace_id, loci_id))
  expect.equality(ws2.knowledge.primary_loci_id == vim.NIL or ws2.knowledge.primary_loci_id == nil, true)
end)

return T
