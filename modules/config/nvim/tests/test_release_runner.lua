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

T["release runner exists and requires nv by default"] = function()
  local text = read_file("tests/run_loci_release_tests.sh")
  expect.equality(text:find("command -v nv", 1, true) ~= nil, true)
  expect.equality(text:find("LOCI_RELEASE_ALLOW_NON_NV", 1, true) ~= nil, true)
  expect.equality(text:find("NVIM_CMD=\"nv\"", 1, true) ~= nil, true)
end

T["developer runner supports selected file arguments"] = function()
  local text = read_file("tests/run_loci_tests.sh")
  expect.equality(text:find("Selected files", 1, true) ~= nil, true)
  expect.equality(text:find("$#", 1, true) ~= nil, true)
  expect.equality(text:find("run_one_file", 1, true) ~= nil, true)
end

T["release runner isolates state and cache"] = function()
  local text = read_file("tests/run_loci_release_tests.sh")
  expect.equality(text:find("XDG_STATE_HOME", 1, true) ~= nil, true)
  expect.equality(text:find("XDG_CACHE_HOME", 1, true) ~= nil, true)
  expect.equality(text:find("LOCI_RELEASE_KEEP_STATE", 1, true) ~= nil, true)
end

T["release runner supports selected file passthrough"] = function()
  local text = read_file("tests/run_loci_release_tests.sh")
  expect.equality(text:find("\"$@\"", 1, true) ~= nil, true)
  expect.equality(text:find("run_loci_tests.sh", 1, true) ~= nil, true)
end

return T
