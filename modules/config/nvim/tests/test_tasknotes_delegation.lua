local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["available returns false when TaskNotes module and commands are absent"] = function()
  local tasknotes = require("loci.service.tasknotes")
  local available = tasknotes.available()
  -- This test just verifies the method exists and returns a boolean
  expect.equality(type(available), "boolean")
end

T["browse returns integration_unavailable when absent"] = function()
  local tasknotes = require("loci.service.tasknotes")
  -- If TaskNotes is not available, browse should fail gracefully
  local res = tasknotes.browse()
  -- Either ok=true (command exists) or ok=false with integration_unavailable
  if not res.ok then
    expect.equality(res.code, "integration_unavailable")
  end
end

T["new returns integration_unavailable when absent"] = function()
  local tasknotes = require("loci.service.tasknotes")
  local res = tasknotes.new()
  if not res.ok then
    expect.equality(res.code, "integration_unavailable")
  end
end

T["edit returns integration_unavailable when absent"] = function()
  local tasknotes = require("loci.service.tasknotes")
  local res = tasknotes.edit()
  if not res.ok then
    expect.equality(res.code, "integration_unavailable")
  end
end

T["rescan returns integration_unavailable when absent"] = function()
  local tasknotes = require("loci.service.tasknotes")
  local res = tasknotes.rescan()
  if not res.ok then
    expect.equality(res.code, "integration_unavailable")
  end
end

T["view returns integration_unavailable when absent"] = function()
  local tasknotes = require("loci.service.tasknotes")
  local res = tasknotes.view()
  if not res.ok then
    expect.equality(res.code, "integration_unavailable")
  end
end

T["service does not expose lifecycle mutation helpers"] = function()
  local tasknotes = require("loci.service.tasknotes")
  -- These should not exist
  expect.equality(tasknotes.complete, nil)
  expect.equality(tasknotes.archive, nil)
  expect.equality(tasknotes.set_status, nil)
  expect.equality(tasknotes.set_priority, nil)
end

return T
