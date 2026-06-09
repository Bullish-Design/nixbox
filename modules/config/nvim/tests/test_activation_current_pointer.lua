local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
end

T["explicit workspace activation writes current.json"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local fixed_now = "2026-05-23T10:05:00Z"

    local r = activation.activate(ctx.workspace.workspace_id, {
      notify = false,
      clock = function() return fixed_now end,
    })
    local value = helpers.expect_ok(r)

    local current = helpers.read_json(ctx.loci .. "/graph/current.json")
    expect.equality(current.repository_id, ctx.repository.repository_id)
    expect.equality(current.project_id, ctx.project.project_id)
    expect.equality(current.workspace_id, ctx.workspace.workspace_id)
    expect.equality(current.activated_at, fixed_now)
  end)

  test_fn()
  ctx.cleanup()
end

T["workspace provenance is updated on activation"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")
    local fixed_now = "2026-05-23T10:05:00Z"

    activation.activate(ctx.workspace.workspace_id, {
      notify = false,
      clock = function() return fixed_now end,
    })

    local workspace = helpers.read_json(
      ctx.loci .. "/graph/workspaces/" .. ctx.workspace.workspace_id .. ".json"
    )
    expect.equality(workspace.provenance.last_activated_at, fixed_now)
  end)

  test_fn()
  ctx.cleanup()
end

T["tab_id_cache is persisted as runtime cache"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    activation.activate(ctx.workspace.workspace_id, { notify = false })

    local workspace = helpers.read_json(
      ctx.loci .. "/graph/workspaces/" .. ctx.workspace.workspace_id .. ".json"
    )
    expect.equality(type(workspace.tabby.tab_id_cache), "number")
  end)

  test_fn()
  ctx.cleanup()
end

T["fallback workspace has nil project_id in current.json"] = function()
  local ctx = helpers.create_phase6_fixture({ now = function() return "2026-05-23T10:00:00Z" end })
  setup()

  local test_fn = helpers.async_test(function()
    local activation = require("loci.service.activation")

    activation.activate(nil, { notify = false })

    local current = helpers.read_json(ctx.loci .. "/graph/current.json")
    -- JSON null should be vim.NIL when read, or nil when json_null_to_nil is applied
    expect.equality(current.project_id == vim.NIL or current.project_id == nil, true)
  end)

  test_fn()
  ctx.cleanup()
end

return T
