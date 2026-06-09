local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["daily() uses daily/<date>.md content path"] = helpers.async_with_initialized_repo(function(_)
  local notes = require("loci.service.notes")
  local markdown = require("loci.store.markdown")
  local date = "2026-05-28"

  local created = helpers.expect_ok(notes.daily({ date_string = date }))
  local content_path = helpers.expect_ok(markdown.content_path_for_abs(created.abs_path))
  expect.equality(content_path, "daily/" .. date .. ".md")
end)

return T
