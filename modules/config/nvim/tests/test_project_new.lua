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

T["create() writes project markdown"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res = helpers.expect_ok(service.create({
      title = "Loci V3 Redesign",
      project_id = "loci-v3-redesign-4k9m2q",
      now = "2026-05-23T10:10:00Z",
    }))

    local path_module = require("loci.store.path")
    local md_path = path_module.must_content_path("projects/loci-v3-redesign.md")
    expect.equality(vim.fn.filereadable(md_path), 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() writes project graph"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res = helpers.expect_ok(service.create({
      title = "Test Project",
      project_id = "test-project-123456",
      now = "2026-05-23T10:10:00Z",
    }))

    local path_module = require("loci.store.path")
    local graph_path = path_module.must_graph_path("projects/test-project-123456.json")
    expect.equality(vim.fn.filereadable(graph_path), 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() writes projects index"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    helpers.expect_ok(service.create({
      title = "Test Project",
      now = "2026-05-23T10:10:00Z",
    }))

    local path_module = require("loci.store.path")
    local index_path = path_module.must_index_path("projects.json")
    expect.equality(vim.fn.filereadable(index_path), 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() returns graph record"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res = helpers.expect_ok(service.create({
      title = "Test Project",
      project_id = "test-project-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    expect.equality(res.project_id, "test-project-xyz123")
    expect.equality(res.title_cache, "Test Project")
    expect.equality(res.schema_version, 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() uses explicit project_id in tests"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res = helpers.expect_ok(service.create({
      title = "Explicit ID Test",
      project_id = "explicit-id-8x2k1q",
      now = "2026-05-23T10:10:00Z",
    }))

    expect.equality(res.project_id, "explicit-id-8x2k1q")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() slugifies content filename"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res = helpers.expect_ok(service.create({
      title = "Hello World Test",
      now = "2026-05-23T10:10:00Z",
    }))

    helpers.expect_match(res.content_path, "hello%-world%-test")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() avoids markdown filename collision with -2 suffix"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res1 = helpers.expect_ok(service.create({
      title = "Test Project",
      now = "2026-05-23T10:10:00Z",
    }))

    local res2 = helpers.expect_ok(service.create({
      title = "Test Project",
      now = "2026-05-23T10:11:00Z",
    }))

    expect.no_equality(res1.content_path, res2.content_path)
    helpers.expect_match(res2.content_path, "%-2%.md$")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() rejects empty title"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local res = service.create({
      title = "",
      now = "2026-05-23T10:10:00Z",
    })

    helpers.expect_err(res, "invalid_input")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create({ open = true }) opens created markdown through test hook"] = function()
  local tmpdir, restore, service, repository = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:10:00Z" }))
    local opened_path = nil
    service._set_open_file_for_test(function(abs_path)
      opened_path = abs_path
    end)

    local res = helpers.expect_ok(service.create({
      title = "Test Project",
      open = true,
      now = "2026-05-23T10:10:00Z",
    }))

    expect.no_equality(opened_path, nil)
    helpers.expect_match(opened_path, "test%-project")

    service._set_open_file_for_test(function(abs_path)
      vim.cmd.edit(vim.fn.fnameescape(abs_path))
    end)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
