local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  require("loci.config").setup({ refresh = { on_setup = false } })
  helpers.init_loci_dir(tmpdir)
  return tmpdir, restore, require("loci.service.project"), require("loci.service.repository")
end

T["list() returns project graph entries"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    helpers.expect_ok(service.create({
      title = "Entry Test Project",
      project_id = "entry-test-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    local list = helpers.expect_ok(service.list())
    expect.equality(#list, 1)

    local entry = list[1]
    -- Entry is a project graph object.
    expect.no_equality(entry.project_id, nil)
    expect.no_equality(entry.title_cache, nil)
    expect.no_equality(entry.status_cache, nil)
    expect.equality(entry.project_id, "entry-test-xyz123")
    expect.equality(entry.title_cache, "Entry Test Project")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["list() works when index is missing (graph-backed)"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    helpers.expect_ok(service.create({
      title = "Rebuild Test Project",
      now = "2026-05-23T10:10:00Z",
    }))

    local path = require("loci.store.path")
    local index_path = path.must_index_path("projects.json")
    helpers.expect_ok(require("loci.store.fs").unlink(index_path))

    local list = helpers.expect_ok(service.list())
    expect.equality(#list, 1)
    expect.equality(vim.fn.filereadable(index_path), 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["list() includes created project title_cache after create"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    helpers.expect_ok(service.create({
      title = "Resolve After Create",
      now = "2026-05-23T10:10:00Z",
    }))

    local list = helpers.expect_ok(service.list())
    expect.no_equality(list[1].project_id, nil)
    expect.equality(list[1].title_cache, "Resolve After Create")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
