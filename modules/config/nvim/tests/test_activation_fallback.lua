local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
end

T["activate(nil) opens fallback workspace"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    local r = activation.activate(nil, { notify = false, clock = function() return "2026-05-23T10:05:00Z" end })
    local value = helpers.expect_ok(r)

    expect.equality(value.workspace_id, ctx.fallback_workspace.workspace_id)
    expect.equality(value.workspace_name, "Repository")
  end)

  test_fn()
  ctx.cleanup()
end

T["activate('') opens fallback workspace"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    local r = activation.activate("", { notify = false, clock = function() return "2026-05-23T10:05:00Z" end })
    local value = helpers.expect_ok(r)

    expect.equality(value.workspace_id, ctx.fallback_workspace.workspace_id)
  end)

  test_fn()
  ctx.cleanup()
end

T["fallback activation writes current.json"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local fixed_now = "2026-05-23T10:05:00Z"

    local r = activation.activate(nil, { notify = false, clock = function() return fixed_now end })
    helpers.expect_ok(r)

    local current = helpers.read_json(ctx.loci .. "/graph/current.json")
    expect.equality(current.workspace_id, ctx.fallback_workspace.workspace_id)
    expect.equality(current.activated_at, fixed_now)
    expect.equality(current.repository_id, ctx.repository.repository_id)
  end)

  test_fn()
  ctx.cleanup()
end

return T
