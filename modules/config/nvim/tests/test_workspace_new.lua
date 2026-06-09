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

T["create() basic repository-level workspace"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    -- Initialize repository first
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    -- Create workspace
    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Parser fix main",
      branch = "loci/parser-fix",
      worktree_path = "../loci-parser-fix",
      clock = fixed_clock,
    }))

    expect.equality(workspace.name, "Parser fix main")
    expect.equality(workspace.schema_version, 1)
    expect.equality(workspace.git.branch, "loci/parser-fix")
    expect.equality(workspace.git.worktree_path, "../loci-parser-fix")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() sets project_id to null when not provided"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    expect.equality(workspace.project_id == vim.NIL or workspace.project_id == nil, true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() sets resession session name"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    expect.equality(workspace.resession.session_name, "loci:workspace:" .. workspace.workspace_id)
    expect.equality(workspace.resession.scope, "tab")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() sets haunt main context"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    expect.equality(workspace.haunt.active, "main")
    expect.equality(workspace.haunt.contexts.main.data_dir,
      ".loci/integrations/haunt/workspaces/" .. workspace.workspace_id .. "/main")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() sets wayfinder main trail"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    expect.equality(workspace.wayfinder.active, "main")
    expect.equality(workspace.wayfinder.trails.main.trail_name,
      "loci-" .. workspace.workspace_id .. "-main")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() initializes empty knowledge"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    expect.equality(#workspace.knowledge.objects, 0)
    expect.equality(workspace.knowledge.primary_loci_id == vim.NIL or workspace.knowledge.primary_loci_id == nil, true)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() initializes empty linked_files"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    expect.equality(#workspace.linked_files, 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() creates haunt directory"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    local path_module = require("loci.store.path")
    local haunt_dir = path_module.loci_root() .. "/" .. workspace.haunt.contexts.main.data_dir:gsub("^%.loci/", "")
    expect.equality(vim.fn.isdirectory(haunt_dir), 1)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["create() rejects missing name"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local err = workspace_service.create({ clock = fixed_clock })
    helpers.expect_err(err, "invalid_input")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["open() writes current state"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    local current = helpers.expect_ok(workspace_service.open(workspace.workspace_id, {
      clock = fixed_clock,
    }))

    expect.equality(current.workspace_id, workspace.workspace_id)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["open() sets runtime variables"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({
      name = "test-repo",
      clock = fixed_clock,
    }))

    local workspace_service = require("loci.service.workspace")
    local workspace = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      clock = fixed_clock,
    }))

    helpers.expect_ok(workspace_service.open(workspace.workspace_id, {
      clock = fixed_clock,
    }))

    expect.equality(vim.t.loci_workspace_id, workspace.workspace_id)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
