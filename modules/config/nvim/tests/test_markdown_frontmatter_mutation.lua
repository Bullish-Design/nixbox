local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup_file(content)
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()
  local filepath = tmpdir .. "/.loci/content/notes/test.md"
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  helpers.write_file(filepath, content)
  return tmpdir, restore, filepath
end

T["add frontmatter list value rewrites into canonical frontmatter"] = function()
  local tmpdir, restore, filepath = setup_file("---\n# user comment\ntitle: 'Preserve This Quote Style'\ntype: note\nprojects:\n  - \"[[projects/existing]]\"\ncustom_field: { keep: this }\n---\n# Body\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local r = markdown.add_frontmatter_list_value(filepath, "projects", "[[projects/new-project]]")
    expect.equality(r.ok, true)
    local out = helpers.read_file(filepath)
    expect.equality(out:find("# user comment", 1, true), nil)
    expect.no_equality(out:find("title: Preserve This Quote Style", 1, true), nil)
    expect.equality(out:find("custom_field: { keep: this }", 1, true), nil)
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

T["add frontmatter list value writes canonical field order"] = function()
  local tmpdir, restore, filepath = setup_file("---\na: 1\ntags:\n  - old\nz: 2\n---\n# Body\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local r = markdown.add_frontmatter_list_value(filepath, "tags", "new")
    expect.equality(r.ok, true)
    local out = helpers.read_file(filepath)
    expect.equality(out:find("a: 1", 1, true), nil)
    expect.equality(out:find("z: 2", 1, true), nil)
    expect.no_equality(out:find("tags:", 1, true), nil)
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

T["add frontmatter list value is idempotent"] = function()
  local tmpdir, restore, filepath = setup_file("---\ntags:\n  - existing\n---\n# Body\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    helpers.expect_ok(markdown.add_frontmatter_list_value(filepath, "tags", "existing"))
    local out = helpers.read_file(filepath)
    local count = 0
    for _ in out:gmatch("existing") do count = count + 1 end
    expect.equality(count, 1)
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

T["add frontmatter list value accepts inline list and canonicalizes"] = function()
  local tmpdir, restore, filepath = setup_file("---\ntags: [one, two]\n---\n# Body\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local r = markdown.add_frontmatter_list_value(filepath, "tags", "three")
    expect.equality(r.ok, true)
    local out = helpers.read_file(filepath)
    expect.no_equality(out:find("tags:\n  - one\n  - two\n  - three", 1, true), nil)
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

T["add frontmatter list value ignores force_reserialize and remains canonical"] = function()
  local tmpdir, restore, filepath = setup_file("---\ntags: [one, two]\n---\n# Body\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local r = markdown.add_frontmatter_list_value(filepath, "tags", "three", { force_reserialize = true })
    expect.equality(r.ok, true)
    expect.equality(#r.value.frontmatter.tags, 3)
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

T["add frontmatter list value creates frontmatter when absent"] = function()
  local tmpdir, restore, filepath = setup_file("# Body\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local r = markdown.add_frontmatter_list_value(filepath, "tags", "new-tag")
    expect.equality(r.ok, true)
    local out = helpers.read_file(filepath)
    expect.equality(out:match("^%-%-%-") ~= nil, true)
    expect.no_equality(out:find("new-tag", 1, true), nil)
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

T["add frontmatter list value rejects malformed frontmatter"] = function()
  local tmpdir, restore, filepath = setup_file("---\ntags:\n  - x\n# no closing fence\n")
  helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local r = markdown.add_frontmatter_list_value(filepath, "tags", "y")
    expect.equality(r.ok, false)
    expect.equality(r.code, "decode_failed")
  end)()
  restore(); helpers.remove_tmpdir(tmpdir)
end

return T
