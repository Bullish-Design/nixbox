local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function read_file(path)
  local f = assert(io.open(helpers.repo_file(path), "r"))
  local text = f:read("*a")
  f:close()
  return text
end

T["manual validation module exists and covers required integrations"] = function()
  local text = read_file("tests/manual/loci_manual_validation.lua")
  for _, needle in ipairs({ "validate_haunt", "validate_wayfinder", "validate_resession", "validate_tabby" }) do
    expect.equality(text:find(needle, 1, true) ~= nil, true)
  end
end

T["manual validation shell runner isolates repo state and cache"] = function()
  local text = read_file("tests/manual/run_loci_manual_validation.sh")
  expect.equality(text:find("LOCI_PROJECT_ROOT", 1, true) ~= nil, true)
  expect.equality(text:find("XDG_STATE_HOME", 1, true) ~= nil, true)
  expect.equality(text:find("XDG_CACHE_HOME", 1, true) ~= nil, true)
  expect.equality(text:find("LOCI_MANUAL_KEEP", 1, true) ~= nil, true)
end

return T
