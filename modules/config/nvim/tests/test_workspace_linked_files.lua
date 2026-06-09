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
  return tmpdir, restore, require("loci.service.workspace")
end

T["link_current_file with explicit path links that path"] = function()
  local tmpdir, restore, service = setup()

  local test_fn = helpers.async_test(function()
    local ws = helpers.expect_ok(service.create({ name = "Test Workspace" }))

    local result = helpers.expect_ok(service.link_current_file(ws.workspace_id, {
      path = "src/parser.ts",
      role = "implementation",
      allow_missing = true,
    }))

    expect.equality(#result.linked_files, 1)
    expect.equality(result.linked_files[1].path, "src/parser.ts")
    expect.equality(result.linked_files[1].role, "implementation")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["link_current_file respects explicit role"] = function()
  local tmpdir, restore, service = setup()

  local test_fn = helpers.async_test(function()
    local ws = helpers.expect_ok(service.create({ name = "Test Workspace" }))

    local result = helpers.expect_ok(service.link_current_file(ws.workspace_id, {
      path = "docs/readme.md",
      role = "documentation",
      allow_missing = true,
    }))

    expect.equality(#result.linked_files, 1)
    expect.equality(result.linked_files[1].role, "documentation")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["unlink_current_file with explicit path removes that path"] = function()
  local tmpdir, restore, service = setup()

  local test_fn = helpers.async_test(function()
    local ws = helpers.expect_ok(service.create({ name = "Test Workspace" }))

    -- Add a file
    helpers.expect_ok(service.link_current_file(ws.workspace_id, {
      path = "src/parser.ts",
      allow_missing = true,
    }))

    -- Unlink it
    local result = helpers.expect_ok(service.unlink_current_file(ws.workspace_id, {
      path = "src/parser.ts",
    }))

    expect.equality(#result.linked_files, 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
