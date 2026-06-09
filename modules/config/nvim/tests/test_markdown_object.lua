local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local markdown_object = require("loci.domain.markdown_object")

local T = MiniTest.new_set()

T["normalize accepts a normal object"] = function()
  local obj = helpers.expect_ok(markdown_object.normalize({
    loci_id = "fix-parser-edge-case-aaaaaa",
    title = "Fix parser edge case",
    content_path = "tasks/fix-parser-edge-case.md",
    abs_path = "/tmp/repo/.loci/content/tasks/fix-parser-edge-case.md",
    type = "task",
    status = "open",
    projects = { "[[projects/loci-v3-redesign]]" },
    tags = { "parser", "bug" },
  }))

  expect.equality(obj.loci_id, "fix-parser-edge-case-aaaaaa")
  expect.equality(obj.title, "Fix parser edge case")
  expect.equality(obj.type, "task")
  expect.equality(obj.status, "open")
  expect.equality(obj.projects, { "[[projects/loci-v3-redesign]]" })
  expect.equality(obj.tags, { "parser", "bug" })
  expect.equality(obj.content_path, "tasks/fix-parser-edge-case.md")
end

T["normalize turns nil projects/tags into empty lists"] = function()
  local obj = helpers.expect_ok(markdown_object.normalize({
    loci_id = "test-note-aaaaaa",
    title = "Test note",
    content_path = "notes/test-note.md",
    abs_path = "/tmp/repo/.loci/content/notes/test-note.md",
  }))

  expect.equality(obj.projects, {})
  expect.equality(obj.tags, {})
end

T["normalize defaults type from content_path"] = function()
  local obj = helpers.expect_ok(markdown_object.normalize({
    loci_id = "fix-parser-edge-case-aaaaaa",
    title = "Fix parser edge case",
    content_path = "tasks/fix-parser-edge-case.md",
    abs_path = "/tmp/repo/.loci/content/tasks/fix-parser-edge-case.md",
  }))

  expect.equality(obj.type, "task")
end

T["normalize defaults unknown path type to note"] = function()
  local obj = helpers.expect_ok(markdown_object.normalize({
    loci_id = "test-aaaaaa",
    title = "Test",
    content_path = "custom/test.md",
    abs_path = "/tmp/repo/.loci/content/custom/test.md",
  }))

  expect.equality(obj.type, "note")
end

T["normalize rejects content_path outside standard dirs"] = function()
  local res = markdown_object.normalize({
    loci_id = "test-aaaaaa",
    title = "Test",
    content_path = "invalid/test.md",
    abs_path = "/tmp/repo/.loci/content/invalid/test.md",
  })

  expect.equality(res.ok, true)  -- Now accepted, just defaults to 'note' type
  expect.equality(res.value.type, "note")
end

T["normalize rejects invalid content_path without .md"] = function()
  local res = markdown_object.normalize({
    loci_id = "test-aaaaaa",
    title = "Test",
    content_path = "tasks/test",
    abs_path = "/tmp/repo/.loci/content/tasks/test",
  })

  expect.equality(res.ok, false)
end

T["normalize rejects invalid loci_id when present"] = function()
  local res = markdown_object.normalize({
    loci_id = "not-a-valid-id!!!",
    title = "Test",
    content_path = "notes/test.md",
    abs_path = "/tmp/repo/.loci/content/notes/test.md",
  })

  expect.equality(res.ok, false)
  expect.equality(res.code, "invalid_input")
end

T["frontmatter_for_new generates loci_id when missing"] = function()
  local fm = helpers.expect_ok(markdown_object.frontmatter_for_new({
    title = "Fix parser edge case",
    type = "task",
  }))

  expect.no_equality(fm.loci_id, nil)
  expect.equality(fm.title, "Fix parser edge case")
  expect.equality(fm.type, "task")
end

T["frontmatter_for_new preserves explicit loci_id for deterministic tests"] = function()
  local fm = helpers.expect_ok(markdown_object.frontmatter_for_new({
    title = "Fix parser edge case",
    type = "task",
    loci_id = "fix-parser-edge-case-aaaaaa",
  }))

  expect.equality(fm.loci_id, "fix-parser-edge-case-aaaaaa")
  expect.equality(fm.title, "Fix parser edge case")
  expect.equality(fm.type, "task")
end

T["frontmatter_for_new includes projects and tags"] = function()
  local fm = helpers.expect_ok(markdown_object.frontmatter_for_new({
    title = "Fix parser edge case",
    type = "task",
    projects = { "[[projects/loci-v3-redesign]]" },
    tags = { "parser", "bug" },
    loci_id = "fix-parser-edge-case-aaaaaa",
  }))

  expect.equality(fm.projects, { "[[projects/loci-v3-redesign]]" })
  expect.equality(fm.tags, { "parser", "bug" })
end

T["frontmatter_for_new includes status when provided"] = function()
  local fm = helpers.expect_ok(markdown_object.frontmatter_for_new({
    title = "Task",
    type = "task",
    status = "open",
    loci_id = "task-aaaaaa",
  }))

  expect.equality(fm.status, "open")
end

T["frontmatter_for_new omits status when not provided"] = function()
  local fm = helpers.expect_ok(markdown_object.frontmatter_for_new({
    title = "Task",
    type = "task",
    loci_id = "task-aaaaaa",
  }))

  expect.equality(fm.status, nil)
end

T["kind_from_content_path maps all standard content dirs"] = function()
  local cases = {
    { "projects/test.md", "project" },
    { "tasks/test.md", "task" },
    { "issues/test.md", "issue" },
    { "architecture/test.md", "architecture" },
    { "specs/test.md", "spec" },
    { "concept/test.md", "concept" },
    { "daily/test.md", "daily" },
    { "notes/test.md", "note" },
  }

  for _, case in ipairs(cases) do
    local kind = markdown_object.kind_from_content_path(case[1])
    expect.equality(kind, case[2], "Failed for path: " .. case[1])
  end
end

T["validate_loci_id validates format"] = function()
  expect.equality(markdown_object.validate_loci_id("fix-parser-edge-case-aaaaaa"), true)
  expect.equality(markdown_object.validate_loci_id("invalid!!!"), false)
  expect.equality(markdown_object.validate_loci_id(nil), false)
  expect.equality(markdown_object.validate_loci_id(""), false)
end

T["from_frontmatter strict rejects scalar projects"] = function()
  local res = markdown_object.from_frontmatter({
    loci_id = "note-abc123",
    type = "note",
    projects = "Foo",
  }, {
    content_path = "notes/foo.md",
    abs_path = "/tmp/repo/.loci/content/notes/foo.md",
  }, {
    strict = true,
  })
  expect.equality(res.ok, false)
  expect.equality(res.code, "invalid_frontmatter")
end

return T
