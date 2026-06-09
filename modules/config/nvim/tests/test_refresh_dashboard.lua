local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["refresh.run returns canonical stage summary"] = helpers.async_with_initialized_repo(function()
  local refresh = require("loci.store.refresh")
  local r = refresh.run({ mode = "strict", now = "2026-05-23T10:00:00Z" })
  expect.equality(r.ok, true)
  expect.equality(type(r.value.scan), "table")
  expect.equality(type(r.value.snapshot), "table")
  expect.equality(type(r.value.plan), "table")
  expect.equality(type(r.value.apply), "table")
end)

return T
