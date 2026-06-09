local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["deactivate_current reports Resession save integration_failed"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })

  package.loaded["resession"] = {
    save = function()
      error("save boom")
    end,
    load = function() end,
  }

  vim.t.loci_workspace_id = ctx.workspace.workspace_id

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local r = activation.deactivate_current({ save_resession = true })
    local value = helpers.expect_ok(r)

    expect.equality(value.integrations.resession.ok, false)
    expect.equality(value.integrations.resession.code, "integration_failed")
    expect.no_equality(string.find(value.integrations.resession.err, "save boom", 1, true), nil)
  end)

  test_fn()
  ctx.cleanup()
end

T["deactivate_current reports Wayfinder save integration_failed"] = function()
  local ctx = helpers.create_phase8_fixture({ now = function() return "2026-05-23T10:00:00Z" end })

  vim.api.nvim_create_user_command("WayfinderTrailSave", function()
    error("trail save boom")
  end, {})

  vim.t.loci_workspace_id = ctx.workspace.workspace_id

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local r = activation.deactivate_current({ save_resession = false, save_wayfinder = true })
    local value = helpers.expect_ok(r)

    expect.equality(value.integrations.wayfinder.ok, false)
    expect.equality(value.integrations.wayfinder.code, "wayfinder_named_api_unavailable")
    expect.no_equality(value.integrations.wayfinder.meta, nil)
  end)

  test_fn()
  ctx.cleanup()
end

T["activate includes deactivation save failure summary"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })

  package.loaded["resession"] = {
    save = function()
      error("save boom")
    end,
    load = function()
      return true
    end,
  }

  vim.t.loci_workspace_id = ctx.workspace.workspace_id

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local r = activation.activate(ctx.workspace.workspace_id, { notify = false, save_current = true })
    local value = helpers.expect_ok(r)

    expect.no_equality(value.deactivation, nil)
    expect.equality(value.deactivation.integrations.resession.ok, false)
    expect.equality(value.deactivation.integrations.resession.code, "integration_failed")
  end)

  test_fn()
  ctx.cleanup()
end

T["activation integration failure entries include metadata"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })

  package.loaded["resession"] = {
    load = function()
      error("load boom")
    end,
    save = function()
      return true
    end,
  }

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local r = activation.activate(ctx.workspace.workspace_id, { notify = false, save_current = false })
    local value = helpers.expect_ok(r)

    expect.equality(value.integrations.resession.ok, false)
    expect.equality(value.integrations.resession.code, "integration_failed")
    expect.no_equality(value.integrations.resession.meta, nil)
  end)

  test_fn()
  ctx.cleanup()
end

return T
