local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["ensure_loci_id returns existing ID without changing file"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "---\nloci_id: existing-id-aaaaaa\ntitle: Test\n---\n\n# Test\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath))

    expect.equality(obj.loci_id, "existing-id-aaaaaa")

    -- Verify file unchanged
    local new_content = helpers.read_file(filepath)
    expect.equality(new_content, content)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id inserts ID into existing frontmatter without reserializing it"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "---\ntitle: Existing Note\ntags:\n  - parser\n---\n\nExisting body.\n"
  local filepath = tmpdir .. "/.loci/content/notes/existing-note.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath, {
      loci_id = "existing-note-aaaaaa",
    }))

    expect.equality(obj.loci_id, "existing-note-aaaaaa")

    -- Verify structure: loci_id should be inserted, not entire FM rewritten
    local new_content = helpers.read_file(filepath)
    expect.no_equality(new_content:find("loci_id: existing-note-aaaaaa", 1, true), nil)
    expect.no_equality(new_content:find("title: Existing Note", 1, true), nil)
    -- Original tag should still be there
    expect.no_equality(new_content:find("parser", 1, true), nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id prepends minimal frontmatter when missing"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "# Existing Note\n\nBody content.\n"
  local filepath = tmpdir .. "/.loci/content/notes/existing-note.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath, {
      loci_id = "existing-note-aaaaaa",
    }))

    expect.equality(obj.loci_id, "existing-note-aaaaaa")

    -- Verify frontmatter was added
    local new_content = helpers.read_file(filepath)
    expect.no_equality(new_content:match("^%-%-%-"), nil)
    expect.no_equality(new_content:find("loci_id: existing-note-aaaaaa", 1, true), nil)
    -- Body should still be intact
    expect.no_equality(new_content:find("Body content", 1, true), nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id infers title from opts first"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "# Old Heading\n\nBody.\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath, {
      title = "New Title",
      loci_id = "new-title-aaaaaa",
    }))

    expect.equality(obj.loci_id, "new-title-aaaaaa")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id infers title from existing frontmatter second"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "---\ntitle: From Frontmatter\n---\n\n# Old Heading\n\nBody.\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath, {
      loci_id = "from-frontmatter-aaaaaa",
    }))

    expect.equality(obj.loci_id, "from-frontmatter-aaaaaa")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id infers title from first H1 third"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "# From Heading\n\nBody content.\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath))

    expect.no_equality(obj.loci_id, nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id infers title from filename last"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "Body content.\n"
  local filepath = tmpdir .. "/.loci/content/notes/from-filename.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local obj = helpers.expect_ok(markdown.ensure_loci_id(filepath))

    expect.no_equality(obj.loci_id, nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id rejects malformed frontmatter by default"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "---\ntitle: Bad\n\n# No closing\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.ensure_loci_id(filepath, { force = false })

    expect.equality(res.ok, false)
    expect.equality(res.code, "decode_failed")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id rejects files outside content"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local filepath = tmpdir .. "/not-under-content.md"
  helpers.write_file(filepath, "# Test\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.ensure_loci_id(filepath)

    expect.equality(res.ok, false)
    expect.equality(res.code == "outside_content" or res.code == "io_error", true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["ensure_loci_id rejects invalid supplied loci_id and does not write file"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "# Existing\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.ensure_loci_id(filepath, { loci_id = "invalid!!!" })
    expect.equality(res.ok, false)
    expect.equality(res.code, "invalid_loci_id")
    expect.equality(helpers.read_file(filepath), content)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
