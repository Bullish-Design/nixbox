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

T["clone() gets new workspace_id"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({ name = "test-repo", clock = fixed_clock }))
    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({ name = "Source", clock = fixed_clock }))
    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, { name = "Clone", clock = fixed_clock }))
    expect.no_equality(clone.workspace_id, source.workspace_id)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() gets new resession session name"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({ name = "test-repo", clock = fixed_clock }))
    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({ name = "Source", clock = fixed_clock }))
    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, { name = "Clone", clock = fixed_clock }))
    expect.no_equality(clone.resession.session_name, source.resession.session_name)
    expect.equality(clone.resession.session_name, "loci:workspace:" .. clone.workspace_id)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() gets new haunt data dirs"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({ name = "test-repo", clock = fixed_clock }))
    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({ name = "Source", clock = fixed_clock }))
    source.haunt.contexts.alt = { data_dir = ".loci/integrations/haunt/workspaces/" .. source.workspace_id .. "/alt" }
    local graph = require("loci.store.graph")
    helpers.expect_ok(graph.write_workspace(source))
    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, { name = "Clone", clock = fixed_clock }))
    expect.no_equality(clone.haunt.contexts.main.data_dir, source.haunt.contexts.main.data_dir)
    expect.equality(clone.haunt.contexts.main.data_dir:find(clone.workspace_id, 1, true) ~= nil, true)
    expect.equality(clone.haunt.contexts.alt.data_dir:find(clone.workspace_id, 1, true) ~= nil, true)
    expect.equality(clone.haunt.active, source.haunt.active)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() gets new wayfinder trail names"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({ name = "test-repo", clock = fixed_clock }))
    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({ name = "Source", clock = fixed_clock }))
    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, { name = "Clone", clock = fixed_clock }))
    expect.no_equality(clone.wayfinder.trails.main.trail_name, source.wayfinder.trails.main.trail_name)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() does not copy archive"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({ name = "test-repo", clock = fixed_clock }))
    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({ name = "Source", clock = fixed_clock }))
    helpers.expect_ok(workspace_service.archive(source.workspace_id, { reason = "done", clock = fixed_clock }))
    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, { name = "Clone", clock = fixed_clock }))
    expect.equality(clone.archive, nil)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["clone() does not copy tab_id_cache"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    local repo_service = require("loci.service.repository")
    helpers.expect_ok(repo_service.init({ name = "test-repo", clock = fixed_clock }))
    local workspace_service = require("loci.service.workspace")
    local source = helpers.expect_ok(workspace_service.create({ name = "Source", clock = fixed_clock }))
    local clone = helpers.expect_ok(workspace_service.clone(source.workspace_id, { name = "Clone", clock = fixed_clock }))
    expect.equality(clone.tabby.tab_id_cache == vim.NIL or clone.tabby.tab_id_cache == nil, true)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
