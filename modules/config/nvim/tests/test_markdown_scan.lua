local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["scan_content returns all markdown files under content"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  -- Create some files
  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/task1.md", "---\nloci_id: task1-aaaaaa\n---\n\n# Task 1\n")
  helpers.write_file(tasks_dir .. "/task2.md", "---\nloci_id: task2-aaaaaa\n---\n\n# Task 2\n")

  local notes_dir = tmpdir .. "/.loci/content/notes"
  vim.fn.mkdir(notes_dir, "p")
  helpers.write_file(notes_dir .. "/note1.md", "---\nloci_id: note1-aaaaaa\n---\n\n# Note 1\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.scan_content()

    expect.equality(res.ok, true)
    local scan = res.value
    expect.equality(#scan.objects, 3)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["scan_content ignores non-markdown files"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/task.md", "---\nloci_id: task-aaaaaa\n---\n\n# Task\n")
  helpers.write_file(tasks_dir .. "/readme.txt", "Just a text file\n")
  helpers.write_file(tasks_dir .. "/config.json", '{"key": "value"}\n')

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.scan_content()

    expect.equality(res.ok, true)
    local scan = res.value
    expect.equality(#scan.objects, 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["scan_content excludes files missing loci_id by default"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/with-id.md", "---\nloci_id: with-id-aaaaaa\n---\n\n# With ID\n")
  helpers.write_file(tasks_dir .. "/no-id.md", "---\ntitle: No ID\n---\n\n# No ID\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.scan_content()

    expect.equality(res.ok, true)
    local scan = res.value
    expect.equality(#scan.objects, 1)
    expect.no_equality(#scan.diagnostics, 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["scan_content excludes malformed frontmatter files by default"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/good.md", "---\nloci_id: good-aaaaaa\n---\n\n# Good\n")
  helpers.write_file(tasks_dir .. "/bad.md", "---\nno closing\n\n# Bad\n")
  helpers.write_file(tasks_dir .. "/also-good.md", "---\nloci_id: also-good-aaaaaa\n---\n\n# Also Good\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.scan_content()

    expect.equality(res.ok, true)
    local scan = res.value
    expect.equality(#scan.objects, 2)
    expect.no_equality(#scan.diagnostics, 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["scan_content detects duplicate loci_id values"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/first.md", "---\nloci_id: duplicate-aaaaaa\n---\n\n# First\n")

  local notes_dir = tmpdir .. "/.loci/content/notes"
  vim.fn.mkdir(notes_dir, "p")
  helpers.write_file(notes_dir .. "/second.md", "---\nloci_id: duplicate-aaaaaa\n---\n\n# Second\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.scan_content()

    expect.equality(res.ok, true)
    local scan = res.value
    expect.equality(#scan.objects, 2)

    -- Should have duplicate_loci_id diagnostic
    local has_dup_diag = false
    for _, diag in ipairs(scan.diagnostics) do
      if diag.code == "duplicate_loci_id" then
        has_dup_diag = true
        break
      end
    end
    expect.equality(has_dup_diag, true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["scan_content sorts objects by content_path"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/z-task.md", "---\nloci_id: z-task-aaaaaa\n---\n\n# Z\n")
  helpers.write_file(tasks_dir .. "/a-task.md", "---\nloci_id: a-task-aaaaaa\n---\n\n# A\n")
  helpers.write_file(tasks_dir .. "/m-task.md", "---\nloci_id: m-task-aaaaaa\n---\n\n# M\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.scan_content()

    expect.equality(res.ok, true)
    local scan = res.value
    expect.equality(#scan.objects, 3)

    -- Objects should be sorted by content_path
    expect.equality(scan.objects[1].content_path, "tasks/a-task.md")
    expect.equality(scan.objects[2].content_path, "tasks/m-task.md")
    expect.equality(scan.objects[3].content_path, "tasks/z-task.md")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["find_by_loci_id returns matching object"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/task.md", "---\nloci_id: target-id-aaaaaa\ntitle: Target\n---\n\n# Task\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.find_by_loci_id("target-id-aaaaaa")

    expect.equality(res.ok, true)
    local obj = res.value
    expect.equality(obj.loci_id, "target-id-aaaaaa")
    expect.equality(obj.title, "Target")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["find_by_loci_id returns not_found for missing ID"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local tasks_dir = tmpdir .. "/.loci/content/tasks"
  vim.fn.mkdir(tasks_dir, "p")
  helpers.write_file(tasks_dir .. "/task.md", "---\nloci_id: existing-id-aaaaaa\n---\n\n# Task\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.find_by_loci_id("nonexistent-id-aaaaaa")

    expect.equality(res.ok, false)
    expect.equality(res.code, "not_found")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
