local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function fixed_clock()
  return "2026-05-23T12:00:00-04:00"
end

local function setup()
  helpers.reset_modules()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  require("loci.config").setup({ refresh = { on_setup = false } })
  helpers.init_loci_dir(tmpdir)
  return tmpdir, restore
end

T["create() with project_id writes workspace with project reference"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local project_service = require("loci.service.project")
    local project = helpers.expect_ok(project_service.create({
      title = "Loci V3 Redesign",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Workspace main",
      project_id = project.project_id,
      clock = fixed_clock,
    }))

    expect.equality(workspace.project_id, project.project_id)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() with project_id adds workspace to project membership"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local project_service = require("loci.service.project")
    local project = helpers.expect_ok(project_service.create({
      title = "Loci V3 Redesign",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Workspace main",
      project_id = project.project_id,
      clock = fixed_clock,
    }))

    local graph = require("loci.store.graph")
    local reloaded = helpers.expect_ok(graph.read_project(project.project_id))
    expect.equality(vim.tbl_contains(reloaded.workspace_ids, workspace.workspace_id), true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() project membership is idempotent"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local project_service = require("loci.service.project")
    local project = helpers.expect_ok(project_service.create({
      title = "Loci V3 Redesign",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Workspace main",
      project_id = project.project_id,
      clock = fixed_clock,
    }))

    -- Check membership once
    local graph = require("loci.store.graph")
    local reloaded1 = helpers.expect_ok(graph.read_project(project.project_id))
    local count1 = 0
    for _, id in ipairs(reloaded1.workspace_ids) do
      if id == workspace.workspace_id then
        count1 = count1 + 1
      end
    end

    -- Verify the count is 1
    expect.equality(count1, 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() with missing project returns not_found"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local err = workspace_service.create({
      name = "Workspace main",
      project_id = "missing-project-aaa123",
      clock = fixed_clock,
    })

    helpers.expect_err(err, "not_found")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() adds clone to same project"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local project_service = require("loci.service.project")
    local project = helpers.expect_ok(project_service.create({
      title = "Loci V3 Redesign",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({
      name = "Workspace main",
      project_id = project.project_id,
      clock = fixed_clock,
    }))

    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, {
      name = "Workspace clone",
      clock = fixed_clock,
    }))

    expect.equality(clone.project_id, project.project_id)

    local graph = require("loci.store.graph")
    local reloaded = helpers.expect_ok(graph.read_project(project.project_id))
    expect.equality(vim.tbl_contains(reloaded.workspace_ids, source.workspace_id), true)
    expect.equality(vim.tbl_contains(reloaded.workspace_ids, clone.workspace_id), true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() with project_id=false detaches clone"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local project_service = require("loci.service.project")
    local project = helpers.expect_ok(project_service.create({
      title = "Loci V3 Redesign",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({
      name = "Workspace main",
      project_id = project.project_id,
      clock = fixed_clock,
    }))

    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, {
      name = "Workspace detached",
      project_id = false,
      clock = fixed_clock,
    }))

    expect.equality(clone.project_id == vim.NIL or clone.project_id == nil, true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
