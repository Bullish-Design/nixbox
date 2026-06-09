local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["refresh() runs successfully after project markdown changes"] = helpers.async_with_initialized_repo(function()
  local service = require("loci.service.project")
  local path = require("loci.store.path")

  local proj = helpers.expect_ok(service.create({
    title = "Original Title",
    project_id = "refresh-title-xyz123",
    now = "2026-05-23T10:10:00Z",
  }))

  local proj_path = path.must_content_path(proj.content_path)
  helpers.async_write_file(proj_path, "---\nloci_id: refresh-title-xyz123\ntitle: Updated Title\ntype: project\nstatus: archived\n---\n\n# Updated Title\n")

  helpers.expect_ok(service.refresh("refresh-title-xyz123"))
end)

T["refresh() succeeds with canonical frontmatter project ids"] = helpers.async_with_initialized_repo(function()
  local service = require("loci.service.project")
  local path = require("loci.store.path")

  local proj = helpers.expect_ok(service.create({
    title = "Membership Test",
    project_id = "membership-test-abc123",
    now = "2026-05-23T10:10:00Z",
  }))

  local note_path = path.must_content_path("notes/membership-note.md")
  helpers.async_write_file(note_path, "---\nloci_id: membership-note-abc123\ntitle: Membership Note\ntype: note\nprojects:\n  - membership-test-abc123\n---\n\n# Membership Note\n")

  helpers.expect_ok(service.refresh(proj.project_id))
end)

T["refresh() does not infer membership from body wikilinks"] = helpers.async_with_initialized_repo(function()
  local service = require("loci.service.project")
  local path = require("loci.store.path")

  local proj = helpers.expect_ok(service.create({
    title = "Body Link Test",
    project_id = "body-link-test-abc123",
    now = "2026-05-23T10:10:00Z",
  }))

  local note_path = path.must_content_path("notes/body-link-note.md")
  helpers.async_write_file(note_path, "---\nloci_id: body-link-note-abc123\ntitle: Body Link Note\ntype: note\n---\n\n# Body Link Note\n\nSee [[projects/body-link-test]].\n")

  local updated = helpers.expect_ok(service.refresh(proj.project_id))
  expect.equality(#(updated.cache.note_loci_ids or {}), 0)
end)

return T
