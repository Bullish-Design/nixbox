local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
end

T["activation sets vim.g.loci_repository_id"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    activation.activate(ctx.workspace.workspace_id, { notify = false })

    expect.equality(vim.g.loci_repository_id, ctx.repository.repository_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["activation sets vim.g.loci_project_id for project workspace"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    activation.activate(ctx.workspace.workspace_id, { notify = false })

    expect.equality(vim.g.loci_project_id, ctx.project.project_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["activation clears vim.g.loci_project_id for fallback workspace"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    -- Activate fallback (no project)
    activation.activate(nil, { notify = false })

    -- Project ID should be nil
    expect.equality(vim.g.loci_project_id, nil)
  end)

  test_fn()
  ctx.cleanup()
end

T["activation sets vim.t.loci_workspace_id in active tab"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    activation.activate(ctx.workspace.workspace_id, { notify = false })

    expect.equality(vim.t.loci_workspace_id, ctx.workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["activation changes tab-local cwd"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    -- Before activation, cwd should be tmpdir
    helpers.ensure_main()
    local before_cwd = vim.fn.getcwd(-1, 0)

    activation.activate(ctx.workspace.workspace_id, { notify = false })

    -- After activation, cwd should be tmpdir (worktree_path is nil, resolves to repo root)
    helpers.ensure_main()
    local after_cwd = vim.fn.getcwd(-1, 0)
    expect.equality(after_cwd, ctx.tmpdir)
  end)

  test_fn()
  ctx.cleanup()
end

return T
