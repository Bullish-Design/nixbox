local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local project = require("loci.domain.project")

T["new() builds valid project graph"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Loci V3 Redesign",
    project_id = "loci-v3-redesign-4k9m2q",
    content_path = "projects/loci-v3-redesign.md",
    now = "2026-05-23T10:10:00Z",
  }))

  expect.equality(graph.project_id, "loci-v3-redesign-4k9m2q")
  expect.equality(graph.content_path, "projects/loci-v3-redesign.md")
  expect.equality(graph.title_cache, "Loci V3 Redesign")
  expect.equality(graph.status_cache, "active")
  expect.equality(#graph.workspace_ids, 0)
  expect.equality(#graph.cache.task_loci_ids, 0)
  expect.equality(graph.schema_version, 1)
end

T["new() trims title"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "  Loci V3 Redesign  ",
    content_path = "projects/loci-v3-redesign.md",
    now = "2026-05-23T10:10:00Z",
  }))

  expect.equality(graph.title_cache, "Loci V3 Redesign")
end

T["new() defaults status to active"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test Project",
    content_path = "projects/test-project.md",
    now = "2026-05-23T10:10:00Z",
  }))

  expect.equality(graph.status_cache, "active")
end

T["new() accepts explicit project_id"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test",
    project_id = "custom-id-123abc",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  }))

  expect.equality(graph.project_id, "custom-id-123abc")
end

T["new() rejects empty title"] = function()
  local res = project.new({
    title = "",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  })

  helpers.expect_err(res, "invalid_input")
end

T["new() rejects whitespace-only title"] = function()
  local res = project.new({
    title = "   ",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  })

  helpers.expect_err(res, "invalid_input")
end

T["new() rejects invalid project_id"] = function()
  local res = project.new({
    title = "Test",
    project_id = "invalid!!!",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  })

  helpers.expect_err(res, "invalid_input")
end

T["new() rejects content_path outside content/projects"] = function()
  local res = project.new({
    title = "Test",
    content_path = "notes/test.md",
    now = "2026-05-23T10:10:00Z",
  })

  helpers.expect_err(res, "invalid_input")
end

T["new() rejects non-markdown content_path"] = function()
  local res = project.new({
    title = "Test",
    content_path = "projects/test.txt",
    now = "2026-05-23T10:10:00Z",
  })

  helpers.expect_err(res, "invalid_input")
end

T["new() requires timestamp"] = function()
  local res = project.new({
    title = "Test",
    content_path = "projects/test.md",
  })

  helpers.expect_err(res, "invalid_input")
end

T["validate() accepts valid graph"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  }))

  local valid = helpers.expect_ok(project.validate(graph))
  expect.equality(valid.project_id, graph.project_id)
end

T["validate() rejects missing schema_version"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  }))
  graph.schema_version = nil

  helpers.expect_err(project.validate(graph), "invalid_input")
end

T["validate() rejects missing project_id"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  }))
  graph.project_id = nil

  helpers.expect_err(project.validate(graph), "invalid_input")
end

T["validate() rejects invalid content_path"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  }))
  graph.content_path = "notes/test.md"

  helpers.expect_err(project.validate(graph), "invalid_input")
end

T["index_entry() returns picker-safe summary counts"] = function()
  local graph = helpers.expect_ok(project.new({
    title = "Test Project",
    content_path = "projects/test.md",
    now = "2026-05-23T10:10:00Z",
  }))

  local entry = project.index_entry(graph)

  expect.equality(entry.project_id, graph.project_id)
  expect.equality(entry.title, "Test Project")
  expect.equality(entry.status, "active")
  expect.equality(entry.workspace_count, 0)
  expect.equality(entry.task_count, 0)
  expect.equality(entry.issue_count, 0)
  expect.equality(entry.note_count, 0)
end

T["default_cache() returns independent tables"] = function()
  local cache1 = project.default_cache()
  local cache2 = project.default_cache()

  table.insert(cache1.task_loci_ids, "test")
  expect.no_equality(#cache2.task_loci_ids, #cache1.task_loci_ids)
end

T["default_provenance() returns tables with timestamps"] = function()
  local now = "2026-05-23T10:10:00Z"
  local prov = project.default_provenance(now)

  expect.equality(prov.created_at, now)
  expect.equality(prov.last_refreshed_at, now)
end

return T
