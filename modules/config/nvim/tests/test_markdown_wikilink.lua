local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["wikilink_for_content_path strips content prefix and md suffix"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.wikilink_for_content_path("projects/loci-v3-redesign.md")

    expect.equality(res.ok, true)
    expect.equality(res.value, "[[projects/loci-v3-redesign]]")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["wikilink_for_content_path preserves subdirectories"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.wikilink_for_content_path("projects/team/backend-redesign.md")

    expect.equality(res.ok, true)
    expect.equality(res.value, "[[projects/team/backend-redesign]]")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["wikilink_for_content_path supports alias"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.wikilink_for_content_path("projects/loci-v3-redesign.md", {
      alias = "Loci V3 Redesign",
    })

    expect.equality(res.ok, true)
    expect.equality(res.value, "[[projects/loci-v3-redesign|Loci V3 Redesign]]")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["wikilink_for_content_path accepts valid relative markdown path"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.wikilink_for_content_path("invalid/path/file.md")

    expect.equality(res.ok, true)
    expect.equality(res.value, "[[invalid/path/file]]")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["wikilink_for_content_path rejects traversal"] = function()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  helpers.init_loci_dir(tmpdir)
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local markdown = require("loci.store.markdown")
    local res = markdown.wikilink_for_content_path("../../../etc/passwd.md")

    expect.equality(res.ok, false)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
