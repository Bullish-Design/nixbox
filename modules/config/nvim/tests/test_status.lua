local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
end

T["status.current_ids() reflects runtime globals"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local status = require("loci.ui.status")
    local activation = require("loci.service.activation")

    -- Activate a workspace
    activation.activate(ctx.workspace.workspace_id, { notify = false })

    -- Get current IDs
    local ids = status.current_ids()
    expect.equality(ids.repository_id, ctx.repository.repository_id)
    expect.equality(ids.project_id, ctx.project.project_id)
    expect.equality(ids.workspace_id, ctx.workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["status.current_label() returns workspace label"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local status = require("loci.ui.status")
    local activation = require("loci.service.activation")

    -- Activate a workspace
    activation.activate(ctx.workspace.workspace_id, { notify = false })

    -- Get label
    local label = status.current_label()
    -- Should be the workspace's tabby.label or name
    expect.equality(label, "Parser fix")
  end)

  test_fn()
  ctx.cleanup()
end

T["status.workspace_label() falls back to name"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local status = require("loci.ui.status")

    -- Get label for a workspace
    local label = status.workspace_label(ctx.workspace)
    -- Should be the label
    expect.equality(label, "Parser fix")
  end)

  test_fn()
  ctx.cleanup()
end

T["status.current_label() falls back to current graph workspace when cache is empty"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local status = require("loci.ui.status")

    -- Without activation callback cache, status should still resolve from graph/current fallback.
    local label = status.current_label()
    expect.equality(label, "Repository")
  end)

  test_fn()
  ctx.cleanup()
end

T["status.refresh_cache() updates in-memory cache"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local status = require("loci.ui.status")

    -- Refresh cache
    local r = status.refresh_cache({
      repository = ctx.repository,
      workspace = ctx.workspace,
    })
    helpers.expect_ok(r)

    -- Get IDs from cache
    local ids = status.current_ids()
    expect.equality(ids.repository_id, ctx.repository.repository_id)
    expect.equality(ids.workspace_id, ctx.workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

return T
