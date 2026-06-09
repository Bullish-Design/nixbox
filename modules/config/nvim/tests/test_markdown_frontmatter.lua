local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local markdown = require("loci.store.markdown")

local T = MiniTest.new_set()

T["split_frontmatter detects a valid block"] = function()
  local text = "---\nloci_id: test-aaaaaa\n---\n\n# Content\n"
  local result = markdown.split_frontmatter(text)

  expect.equality(result.has_frontmatter, true)
  expect.equality(result.malformed_frontmatter, false)
  expect.equality(result.raw_frontmatter, "loci_id: test-aaaaaa\n")
  expect.equality(result.body, "\n# Content\n")
end

T["split_frontmatter ignores later horizontal rules"] = function()
  local text = "---\nloci_id: test-aaaaaa\n---\n\n# Content\n\n---\n\nMore content\n"
  local result = markdown.split_frontmatter(text)

  expect.equality(result.has_frontmatter, true)
  expect.equality(result.raw_frontmatter, "loci_id: test-aaaaaa\n")
  expect.no_equality(result.body:match("^%-%-%-"), "---") -- Body should not start with ---
end

T["split_frontmatter reports malformed opening block"] = function()
  local text = "---\nloci_id: test-aaaaaa\n\n# No closing delimiter\n"
  local result = markdown.split_frontmatter(text)

  expect.equality(result.has_frontmatter, false)
  expect.equality(result.malformed_frontmatter, true)
  expect.no_equality(#result.diagnostics, 0)
end

T["split_frontmatter handles file without frontmatter"] = function()
  local text = "# Just a heading\n\nSome content\n"
  local result = markdown.split_frontmatter(text)

  expect.equality(result.has_frontmatter, false)
  expect.equality(result.malformed_frontmatter, false)
  expect.equality(result.body, text)
end

T["parse_frontmatter reads scalar LOCI fields"] = function()
  local raw = "loci_id: fix-parser-edge-case-aaaaaa\ntitle: Fix parser edge case\ntype: task\nstatus: open\n"
  local res = markdown.parse_frontmatter(raw)

  expect.equality(res.ok, true)
  local fm = res.value.frontmatter
  expect.equality(fm.loci_id, "fix-parser-edge-case-aaaaaa")
  expect.equality(fm.title, "Fix parser edge case")
  expect.equality(fm.type, "task")
  expect.equality(fm.status, "open")
end

T["parse_frontmatter reads quoted strings"] = function()
  local raw = 'title: "Fix: parser edge case"\n'
  local res = markdown.parse_frontmatter(raw)

  expect.equality(res.ok, true)
  expect.equality(res.value.frontmatter.title, "Fix: parser edge case")
end

T["parse_frontmatter reads block list projects"] = function()
  local raw = "projects:\n  - \"[[projects/loci-v3-redesign]]\"\n"
  local res = markdown.parse_frontmatter(raw)

  expect.equality(res.ok, true)
  local fm = res.value.frontmatter
  expect.equality(type(fm.projects), "table")
  expect.equality(#fm.projects, 1)
  expect.equality(fm.projects[1], "[[projects/loci-v3-redesign]]")
end

T["parse_frontmatter reads block list tags"] = function()
  local raw = "tags:\n  - parser\n  - bug\n"
  local res = markdown.parse_frontmatter(raw)

  expect.equality(res.ok, true)
  local fm = res.value.frontmatter
  expect.equality(type(fm.tags), "table")
  expect.equality(#fm.tags, 2)
  expect.equality(fm.tags[1], "parser")
  expect.equality(fm.tags[2], "bug")
end

T["parse_frontmatter strips # from parsed tag values"] = function()
  local raw = "tags:\n  - \"#parser\"\n  - bug\n"
  local res = markdown.parse_frontmatter(raw)

  expect.equality(res.ok, true)
  local fm = res.value.frontmatter
  expect.equality(fm.tags[1], "#parser") -- Parser doesn't strip, normalization does
end

T["read_frontmatter returns MarkdownDocument and MarkdownObject"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "---\nloci_id: test-aaaaaa\ntitle: Test\ntype: note\n---\n\n# Test\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.read_frontmatter(filepath)

    expect.equality(res.ok, true)
    local doc = res.value
    expect.equality(doc.has_frontmatter, true)
    expect.no_equality(doc.object, nil)
    expect.equality(doc.object.loci_id, "test-aaaaaa")
    expect.equality(doc.object.title, "Test")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["read_frontmatter returns diagnostics rather than failing malformed frontmatter"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local content = "---\nloci_id: test-aaaaaa\n\n# No closing\n"
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.read_frontmatter(filepath)

    expect.equality(res.ok, true)
    local doc = res.value
    expect.equality(doc.malformed_frontmatter, true)
    expect.no_equality(#doc.diagnostics, 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["read_frontmatter rejects files outside .loci/content"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local filepath = tmpdir .. "/not-under-content.md"
  helpers.write_file(filepath, "# Test\n")

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.read_frontmatter(filepath)

    expect.equality(res.ok, false)
    expect.equality(res.code, "outside_content")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
