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
  return tmpdir, restore
end

T["LociFileLink with one path arg uses current workspace"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    require("loci").setup({ refresh = { on_setup = false } })
    helpers.ensure_main()

    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Command Workspace",
      now = "2026-05-23T10:00:00Z",
    }))

    vim.t.loci_workspace_id = ws.workspace_id

    -- Simulate the command being called
    helpers.ensure_main()
    require("loci.ui.commands.workspace").register()
    vim.cmd("LociFileLink src/parser.ts")
    vim.wait(100)

    local graph = require("loci.store.graph")
    local reloaded = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
    expect.equality(#reloaded.linked_files, 1)
    expect.equality(reloaded.linked_files[1].path, "src/parser.ts")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["LociFileLink workspace and path args are preserved"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    require("loci").setup({ refresh = { on_setup = false } })
    helpers.ensure_main()

    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Command Workspace",
      now = "2026-05-23T10:00:00Z",
    }))

    helpers.ensure_main()
    require("loci.ui.commands.workspace").register()
    vim.cmd("LociFileLink " .. ws.workspace_id .. " src/parser.ts")
    vim.wait(100)

    local graph = require("loci.store.graph")
    local reloaded = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
    expect.equality(#reloaded.linked_files, 1)
    expect.equality(reloaded.linked_files[1].path, "src/parser.ts")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["LociFileUnlink: 0 args uses current"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    require("loci").setup({ refresh = { on_setup = false } })
    helpers.ensure_main()

    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Command Workspace",
      now = "2026-05-23T10:00:00Z",
    }))

    -- Link a file first
    local link_r = workspace_service.link_current_file(ws.workspace_id, { path = "src/test.ts" })
    expect.equality(link_r.ok, true)

    vim.t.loci_workspace_id = ws.workspace_id
    helpers.ensure_main()
    require("loci.ui.commands.workspace").register()
    vim.cmd("LociFileUnlink src/test.ts")
    vim.wait(100)

    local graph = require("loci.store.graph")
    local reloaded = helpers.expect_ok(graph.read_workspace(ws.workspace_id))
    expect.equality(#reloaded.linked_files, 0)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["LociWorkspaceArchive: blocks fallback workspace archival"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    require("loci").setup({ refresh = { on_setup = false } })
    local repository = require("loci.service.repository")
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:00:00Z" }))

    local graph = require("loci.store.graph")
    local repo_r = graph.read_repository()
    expect.equality(repo_r.ok, true)

    local fallback_id = repo_r.value.default_workspace_id

    -- Attempt to archive fallback workspace
    local workspace_service = require("loci.service.workspace")
    local result = workspace_service.archive(fallback_id)

    -- Should fail with service-level fallback protection
    expect.equality(result.ok, false)
    expect.equality(result.code, "invalid_input")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["LociWorkspaceArchive: can archive non-fallback workspace"] = function()
  local tmpdir, restore = setup()

  local test_fn = helpers.async_test(function()
    require("loci").setup({ refresh = { on_setup = false } })
    local repository = require("loci.service.repository")
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:00:00Z" }))

    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({
      name = "Test Workspace",
      now = "2026-05-23T10:00:00Z",
    }))

    -- Should succeed for non-fallback workspace
    local result = workspace_service.archive(ws.workspace_id)
    expect.equality(result.ok, true)
    expect.no_equality(result.value, nil)
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["parser: 0 args returns current Workspace + nil value"] = function()
  helpers.reset_modules()
  local commands = require("loci.ui.commands.workspace")
  vim.t.loci_workspace_id = "ws-current"
  local ws, value = commands._resolve_workspace_and_value_for_tests({})
  expect.equality(ws, "ws-current")
  expect.equality(value, nil)
end

T["parser: 1 non-Workspace token returns current Workspace + token value"] = function()
  helpers.reset_modules()
  local commands = require("loci.ui.commands.workspace")
  vim.t.loci_workspace_id = "ws-current"
  local ws, value = commands._resolve_workspace_and_value_for_tests({ "path.md" })
  expect.equality(ws, "ws-current")
  expect.equality(value, "path.md")
end

T["parser: 2+ args returns explicit Workspace + joined value"] = function()
  helpers.reset_modules()
  local commands = require("loci.ui.commands.workspace")
  local ws, value = commands._resolve_workspace_and_value_for_tests({ "ws-123", "a", "b", "c" }, { join_value = true })
  expect.equality(ws, "ws-123")
  expect.equality(value, "a b c")
end

T["parser: 1 existing Workspace ID returns Workspace + nil value"] = function()
  local tmpdir, restore = setup()
  local test_fn = helpers.async_test(function()
    require("loci").setup({ refresh = { on_setup = false } })
    local repository = require("loci.service.repository")
    helpers.expect_ok(repository.init({ now = "2026-05-23T10:00:00Z" }))
    local workspace_service = require("loci.service.workspace")
    local ws = helpers.expect_ok(workspace_service.create({ name = "Parser Workspace", now = "2026-05-23T10:00:00Z" }))
    local commands = require("loci.ui.commands.workspace")
    local resolved_ws, value = commands._resolve_workspace_and_value_for_tests({ ws.workspace_id })
    expect.equality(resolved_ws, ws.workspace_id)
    expect.equality(value, nil)
  end)
  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
