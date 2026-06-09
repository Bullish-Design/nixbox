local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["write_new_object creates frontmatter and H1 body"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.write_new_object({
      dir = "tasks",
      title = "Fix parser edge case",
      type = "task",
      loci_id = "fix-parser-edge-case-aaaaaa",
    }))

    expect.equality(obj.content_path, "tasks/fix-parser-edge-case.md")
    expect.equality(obj.type, "task")
    expect.equality(obj.loci_id, "fix-parser-edge-case-aaaaaa")

    -- Check file was created
    local file_content = helpers.read_file(tmpdir .. "/.loci/content/tasks/fix-parser-edge-case.md")
    expect.no_equality(file_content:find("loci_id: fix-parser-edge-case-aaaaaa", 1, true), nil)
    expect.no_equality(file_content:find("# Fix parser edge case", 1, true), nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object creates parent dir under content"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.write_new_object({
      dir = "custom/nested",
      title = "Test",
      loci_id = "test-aaaaaa",
    }))

    local filepath = tmpdir .. "/.loci/content/custom/nested/"
    expect.equality(vim.fn.isdirectory(filepath) == 1, true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object uses explicit filename"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.write_new_object({
      dir = "tasks",
      title = "Test",
      filename = "custom-name.md",
      loci_id = "test-aaaaaa",
    }))

    expect.equality(obj.content_path, "tasks/custom-name.md")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object rejects path traversal in dir"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.write_new_object({
      dir = "../../../etc",
      title = "Evil",
      loci_id = "evil-aaaaaa",
    })

    expect.equality(res.ok, false)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object rejects path traversal in filename"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.write_new_object({
      dir = "tasks",
      title = "Evil",
      filename = "../../../etc/evil.md",
      loci_id = "evil-aaaaaa",
    })

    expect.equality(res.ok, false)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object returns conflict when file exists and overwrite is false"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")

    -- Create first file
    local res1 = markdown.write_new_object({
      dir = "tasks",
      title = "First",
      loci_id = "first-aaaaaa",
    })
    expect.equality(res1.ok, true)

    -- Try to create same file again
    local res2 = markdown.write_new_object({
      dir = "tasks",
      title = "First",
      loci_id = "first-aaaaaa",
      overwrite = false,
    })

    expect.equality(res2.ok, false)
    expect.equality(res2.code, "conflict")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object can write projects and tags lists"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.write_new_object({
      dir = "tasks",
      title = "Test",
      type = "task",
      projects = { "[[projects/main]]" },
      tags = { "important", "urgent" },
      loci_id = "test-aaaaaa",
    }))

    expect.equality(obj.projects[1], "[[projects/main]]")
    expect.equality(obj.tags[1], "important")
    expect.equality(obj.tags[2], "urgent")

    -- Verify in file
    local file_content = helpers.read_file(tmpdir .. "/.loci/content/tasks/test.md")
    expect.no_equality(file_content:find("projects:", 1, true), nil)
    expect.no_equality(file_content:find("tags:", 1, true), nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["write_new_object preserves caller-supplied body"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local custom_body = "# Custom Heading\n\nCustom content here\n"
  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.write_new_object({
      dir = "tasks",
      title = "Test",
      body = custom_body,
      loci_id = "test-aaaaaa",
    }))

    local file_content = helpers.read_file(tmpdir .. "/.loci/content/tasks/test.md")
    expect.no_equality(file_content:find("Custom Heading", 1, true), nil)
    expect.no_equality(file_content:find("Custom content", 1, true), nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
