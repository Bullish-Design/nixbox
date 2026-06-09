local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["open(project_id) opens project markdown"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local opened_path = nil
    service._set_open_file_for_test(function(abs_path)
      opened_path = abs_path
    end)

    helpers.expect_ok(service.create({
      title = "Test Project",
      project_id = "test-project-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    local open_res = helpers.expect_ok(service.open("test-project-xyz123"))
    expect.no_equality(opened_path, nil)

    service._set_open_file_for_test(nil)
end)

T["open({ project_id = ... }) opens project markdown"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local opened_path = nil
    service._set_open_file_for_test(function(abs_path)
      opened_path = abs_path
    end)

    helpers.expect_ok(service.create({
      title = "Test Project",
      now = "2026-05-23T10:10:00Z",
    }))

    local list_res = helpers.expect_ok(service.list())
    local proj = list_res[1]
    local open_res = helpers.expect_ok(service.open({ project_id = proj.project_id }))
    expect.no_equality(opened_path, nil)

    service._set_open_file_for_test(nil)
end)

T["open() returns not_found for missing project"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local res = service.open("nonexistent-project-xyz123")
    helpers.expect_err(res, "not_found")
end)

T["open() returns invalid_input for malformed project_id"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local res = service.open("invalid!!!project")
    helpers.expect_err(res, "invalid_input")
end)

T["list() includes created project_id"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local created = helpers.expect_ok(service.create({
      title = "Test Project",
      project_id = "resolve-test-abc123",
      now = "2026-05-23T10:10:00Z",
    }))

    local list = helpers.expect_ok(service.list())
    expect.equality(list[1].project_id, "resolve-test-abc123")
end)

T["open() opens project by listed project_id"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local opened_path = nil
    service._set_open_file_for_test(function(abs_path)
      opened_path = abs_path
    end)
    local created = helpers.expect_ok(service.create({
      title = "Resolve Content Path Test",
      now = "2026-05-23T10:10:00Z",
    }))

    local list = helpers.expect_ok(service.list())
    local opened = helpers.expect_ok(service.open(list[1].project_id))
    expect.equality(opened.project_id, created.project_id)
    expect.no_equality(opened_path, nil)
    service._set_open_file_for_test(nil)
end)

T["list() reads projects index"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    helpers.expect_ok(service.create({
      title = "List Test 1",
      now = "2026-05-23T10:10:00Z",
    }))

    helpers.expect_ok(service.create({
      title = "List Test 2",
      now = "2026-05-23T10:11:00Z",
    }))

    local list = helpers.expect_ok(service.list())
    expect.equality(#list, 2)
end)

T["list() works when index is missing (graph-backed)"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    helpers.expect_ok(service.create({
      title = "Rebuild Index Test",
      now = "2026-05-23T10:10:00Z",
    }))

    local path = require("loci.store.path")
    local index_path = path.must_index_path("projects.json")
    helpers.async_rm_rf(index_path)

    local list = helpers.expect_ok(service.list())
    expect.equality(#list, 1)
    expect.equality(vim.fn.filereadable(index_path), 0)
end)

T["get() returns project graph"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local created = helpers.expect_ok(service.create({
      title = "Get Test",
      project_id = "get-test-xyz123",
      now = "2026-05-23T10:10:00Z",
    }))

    local got = helpers.expect_ok(service.get("get-test-xyz123"))
    expect.equality(got.project_id, "get-test-xyz123")
    expect.equality(got.title_cache, "Get Test")
end)

T["get() returns not_found for missing project"] = helpers.async_with_initialized_repo(function(ctx)
  local service = require("loci.service.project")
    local res = service.get("nonexistent-project-xyz123")
    helpers.expect_err(res, "not_found")
end)

return T
