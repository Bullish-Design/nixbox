local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()

  -- Set up resession stub
  package.loaded["resession"] = {
    loaded = {},
    saved = {},
    load = function(name, opts)
      table.insert(package.loaded["resession"].loaded, { name = name, opts = opts })
    end,
    save = function(name, opts)
      table.insert(package.loaded["resession"].saved, { name = name, opts = opts })
    end,
  }
end

T["activation calls resession.load with session_name"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    local stub = package.loaded["resession"]
    expect.equality(#stub.loaded, 1)
    expect.equality(stub.loaded[1].name, ctx.workspace.resession.session_name)
  end)

  test_fn()
  ctx.cleanup()
end

T["deactivation calls resession.save with session_name"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    -- First activate to set up current workspace
    activation.activate(ctx.workspace.workspace_id, { notify = false })

    -- Reset saved count
    package.loaded["resession"].saved = {}

    -- Then deactivate
    local r = activation.deactivate_current({ save_resession = true, notify = false })
    helpers.expect_ok(r)

    local stub = package.loaded["resession"]
    expect.equality(#stub.saved, 1)
    expect.equality(stub.saved[1].name, ctx.workspace.resession.session_name)
  end)

  test_fn()
  ctx.cleanup()
end

T["Resession plugin errors are soft activation failures"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    -- Make resession.load fail
    package.loaded["resession"].load = function(name, opts)
      error("Resession mock error")
    end

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, { notify = false })
    local value = helpers.expect_ok(r)

    -- Activation should still succeed
    expect.equality(value.integrations.resession.ok, false)
    expect.equality(value.integrations.resession.code, "integration_failed")
  end)

  test_fn()
  ctx.cleanup()
end

return T
