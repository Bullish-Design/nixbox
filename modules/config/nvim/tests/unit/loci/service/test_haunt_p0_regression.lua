local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function expect_ok(r)
  return helpers.expect_ok(r)
end

T["direct haunt module exports all workspace service functions"] = function()
  helpers.reset_modules()
  local haunt_service = require("loci.service.workspace.haunt")

  for _, name in ipairs({
    "haunt_list",
    "haunt_new",
    "haunt_switch",
    "haunt_rename",
    "haunt_delete",
  }) do
    expect.equality(type(haunt_service[name]), "function", name)
  end
end

T["direct haunt service lifecycle does not use global ensure_haunt_table"] = function()
  local ctx = helpers.create_phase7_fixture()

  local test_fn = helpers.async_test(function()
    local old_global = rawget(_G, "ensure_haunt_table")
    _G.ensure_haunt_table = function()
      error("global ensure_haunt_table must not be called")
    end

    local haunt_service = require("loci.service.workspace.haunt")
    local graph = require("loci.store.graph")
    local workspace_id = ctx.workspace.workspace_id

    local listed = expect_ok(haunt_service.haunt_list(workspace_id))
    expect.equality(listed.active, "main")

    expect_ok(haunt_service.haunt_new(workspace_id, "debugging"))
    local created_ws = expect_ok(graph.read_workspace(workspace_id))
    expect.no_equality(created_ws.haunt.contexts.debugging, nil)

    expect_ok(haunt_service.haunt_switch(workspace_id, "debugging"))
    local switched_ws = expect_ok(graph.read_workspace(workspace_id))
    expect.equality(switched_ws.haunt.active, "debugging")

    expect_ok(haunt_service.haunt_rename(workspace_id, "debugging", "review"))
    local renamed_ws = expect_ok(graph.read_workspace(workspace_id))
    expect.no_equality(renamed_ws.haunt.contexts.review, nil)
    expect.equality(renamed_ws.haunt.contexts.debugging, nil)

    expect_ok(haunt_service.haunt_delete(workspace_id, "review", {
      switch_to = "main",
      keep_data = true,
    }))
    local deleted_ws = expect_ok(graph.read_workspace(workspace_id))
    expect.equality(deleted_ws.haunt.active, "main")
    expect.equality(deleted_ws.haunt.contexts.review, nil)

    _G.ensure_haunt_table = old_global
  end)

  test_fn()
  ctx.cleanup()
end

return T
