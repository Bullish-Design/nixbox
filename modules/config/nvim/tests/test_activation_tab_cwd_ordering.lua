local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["activation switches tab before changing cwd"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local tabby = require("loci.integrations.tabby")

    -- Track the order of operations
    local operations = {}

    local original_activate_workspace = tabby.activate_workspace
    local original_switch_worktree = require("loci.integrations.git").switch_worktree

    tabby.activate_workspace = function(workspace)
      table.insert(operations, "tab_switch")
      return original_activate_workspace(workspace)
    end

    require("loci.integrations.git").switch_worktree = function(target_dir)
      table.insert(operations, "cwd_change")
      return original_switch_worktree(target_dir)
    end

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    helpers.expect_ok(r)

    -- Verify tab switch happens before cwd change
    expect.equality(#operations, 2)
    expect.equality(operations[1], "tab_switch")
    expect.equality(operations[2], "cwd_change")

    tabby.activate_workspace = original_activate_workspace
    require("loci.integrations.git").switch_worktree = original_switch_worktree
  end)

  test_fn()
  ctx.cleanup()
end

T["deactivate_current() uses tab-local workspace over global"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local graph = require("loci.store.graph")

    -- First activate to set up current workspace
    activation.activate(ctx.workspace.workspace_id, { notify = false })

    -- Create a second workspace
    local workspace_service = require("loci.service.workspace")
    local ws2_res = helpers.expect_ok(workspace_service.create({
      name = "Second Workspace",
    }))
    local second_workspace_id = ws2_res.workspace_id

    -- Set tab-local to the first workspace
    vim.t.loci_workspace_id = ctx.workspace.workspace_id

    -- Manually set global current.json to point to the second workspace
    local current = {
      repository_id = ctx.repository.repository_id,
      project_id = nil,
      workspace_id = second_workspace_id,
      activated_at = "2026-05-23T10:00:00Z",
    }
    helpers.expect_ok(graph.write_current(current))

    -- Call deactivate_current
    local deactivate_res = helpers.expect_ok(activation.deactivate_current())

    -- Should deactivate the workspace_id from tab (ctx.workspace.workspace_id), not from global current.json
    expect.equality(deactivate_res.deactivated, true)
    expect.equality(deactivate_res.workspace_id, ctx.workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["deactivate_current() falls back to global when tab-local missing"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    -- First activate to set up current workspace and global pointer
    activation.activate(ctx.workspace.workspace_id, { notify = false })

    -- Clear the tab-local variable
    vim.t.loci_workspace_id = ""

    -- Call deactivate_current
    local deactivate_res = helpers.expect_ok(activation.deactivate_current())

    -- Should deactivate using the global current.json
    expect.equality(deactivate_res.deactivated, true)
    expect.equality(deactivate_res.workspace_id, ctx.workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["activation can switch away from active workspace without crash"] = function()
  local ctx = helpers.create_phase6_fixture({
    now = function() return "2026-05-23T10:00:00Z" end,
  })
  helpers.reset_modules()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    helpers.expect_ok(activation.activate(ctx.workspace.workspace_id, {
      notify = false,
      clock = function() return "2026-05-23T10:05:00Z" end,
    }))

    helpers.expect_ok(activation.activate(ctx.fallback_workspace.workspace_id, {
      notify = false,
      clock = function() return "2026-05-23T10:06:00Z" end,
    }))

    local current = helpers.read_json(ctx.loci .. "/graph/current.json")
    expect.equality(current.workspace_id, ctx.fallback_workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

return T
