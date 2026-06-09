local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["link_current() ensures current markdown has loci_id"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Link Test Project",
      project_id = "link-test-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    local note_path = path.must_content_path("notes/test-note.md")
    helpers.async_write_file(note_path, "---\ntitle: Test Note\n---\n\n# Test Note\n")

    helpers.async_edit(note_path)

    local link_res = helpers.expect_ok(service.link_current({
      project_id = "link-test-xyz123",
    }))

    expect.no_equality(link_res.markdown_loci_id, nil)
end)

T["link_current() adds projects frontmatter list when missing"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Link Test",
      project_id = "link-test-ab0002",
      now = "2026-05-23T10:10:00Z",
    }))

    local note_path = path.must_content_path("notes/test-link.md")
    helpers.async_write_file(note_path, "---\nloci_id: test-note-xyz123\ntitle: Test Note\n---\n\n# Test Note\n")

    helpers.async_edit(note_path)

    local link_res = helpers.expect_ok(service.link_current({
      project_id = "link-test-ab0002",
    }))

    local read_res = helpers.expect_ok(markdown.read_frontmatter(note_path))
    local projects_list = read_res.frontmatter.projects
    expect.no_equality(projects_list, nil)
end)

T["link_current() appends project wikilink to existing projects list"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj1 = helpers.expect_ok(service.create({
      title = "Project 1",
      now = "2026-05-23T10:10:00Z",
    }))

    local proj2 = helpers.expect_ok(service.create({
      title = "Project 2",
      now = "2026-05-23T10:11:00Z",
    }))

    local note_path = path.must_content_path("notes/multi-project.md")
    helpers.async_write_file(note_path, "---\nloci_id: multi-note-xyz123\ntitle: Multi Project Note\nprojects:\n  - \"[[projects/project-1]]\"\n---\n\n# Multi Project Note\n")

    helpers.async_edit(note_path)

    local link_res = helpers.expect_ok(service.link_current({
      project_id = proj2.project_id,
    }))

    local read_res = helpers.expect_ok(markdown.read_frontmatter(note_path))
    local projects_list = read_res.frontmatter.projects
    expect.equality(#projects_list, 2)
end)

T["link_current() does not duplicate existing project link"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Duplicate Link Test",
      project_id = "dup-link-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    local note_path = path.must_content_path("notes/dup-test.md")
    helpers.async_write_file(note_path, "---\nloci_id: dup-note-xyz123\ntitle: Dup Test\nprojects:\n  - \"[[projects/duplicate-link-test]]\"\n---\n\n# Dup Test\n")

    helpers.async_edit(note_path)

    helpers.expect_ok(service.link_current({
      project_id = proj.project_id,
    }))

    helpers.await_main()
    local link_res2 = helpers.expect_ok(service.link_current({
      project_id = proj.project_id,
    }))

    local read_res = helpers.expect_ok(markdown.read_frontmatter(note_path))
    local projects_list = read_res.frontmatter.projects
    expect.equality(#projects_list, 1)
end)

T["link_current() preserves markdown body"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Preserve Body Test",
      now = "2026-05-23T10:10:00Z",
    }))

    local original_body = "# Test Note\n\nSome important content here.\n\nMore paragraphs."
    local note_path = path.must_content_path("notes/preserve-body.md")
    helpers.async_write_file(note_path, "---\nloci_id: preserve-xyz123\ntitle: Test\n---\n" .. original_body)

    helpers.async_edit(note_path)

    helpers.expect_ok(service.link_current({
      project_id = proj.project_id,
    }))

    local read_res = helpers.expect_ok(markdown.read_frontmatter(note_path))
    helpers.expect_match(read_res.body, "Some important content here")
end)

T["link_current() rejects unnamed buffer"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Unnamed Buffer Test",
      now = "2026-05-23T10:10:00Z",
    }))

    helpers.async_enew()

    local res = service.link_current({
      project_id = proj.project_id,
    })

    helpers.expect_err(res, "invalid_input")
end)

T["link_current() rejects file outside .loci/content"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Outside Content Test",
      now = "2026-05-23T10:10:00Z",
    }))

    local outside_path = ctx.tmpdir .. "/outside.md"
    helpers.async_write_file(outside_path, "# Outside\n")
    helpers.async_edit(outside_path)

    local res = service.link_current({
      project_id = proj.project_id,
    })

    helpers.expect_err(res, "outside_content")
end)

T["link_current() treats project markdown itself as no-op"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Self Link Test",
      now = "2026-05-23T10:10:00Z",
    }))

    local proj_md_path = path.must_content_path(proj.content_path)
    helpers.async_edit(proj_md_path)

    local link_res = helpers.expect_ok(service.link_current({
      project_id = proj.project_id,
    }))

    expect.equality(link_res.changed, false)
end)

T["link_current() refreshes project cache"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
  local markdown = require("loci.store.markdown")
  local path = require("loci.store.path")
    local proj = helpers.expect_ok(service.create({
      title = "Refresh Cache Test",
      project_id = "refresh-cache-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    local note_path = path.must_content_path("notes/cache-refresh.md")
    helpers.async_write_file(note_path, "---\nloci_id: cache-refresh-note-abc123\ntitle: Cache Refresh Note\ntype: note\n---\n\n# Cache Refresh Note\n")

    helpers.async_edit(note_path)

    local link_res = helpers.expect_ok(service.link_current({
      project_id = proj.project_id,
    }))

    expect.no_equality(link_res.project, nil)
end)

return T
