local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

local function read_file(path)
  local f = assert(io.open(path, "r"))
  local text = f:read("*a")
  f:close()
  return text
end

local function test_files()
  local files = {}
  vim.list_extend(files, vim.fn.globpath("tests", "**/*.lua", false, true))
  table.sort(files)
  return files
end

T["no busted-style test globals"] = function()
  local offenders = {}
  for _, file in ipairs(test_files()) do
    local text = read_file(file)
    if text:match("%f[%w_]describe%s*%(")
        or text:match("%f[%w_]it%s*%(")
        or text:match("%f[%w_]defer%s*%(") then
      table.insert(offenders, file)
    end
  end
  expect.equality(offenders, {})
end

T["only helpers call async runner"] = function()
  local offenders = {}
  local async_pattern = table.concat({
    "nio",
    "%.",
    "run%s*%(",
  }, "")
  for _, file in ipairs(test_files()) do
    if file ~= "tests/helpers.lua" then
      local text = read_file(file)
      if text:match(async_pattern) then
        table.insert(offenders, file)
      end
    end
  end
  expect.equality(offenders, {})
end

T["health tests do not use legacy current pointer fields"] = function()
  local offenders = {}
  local legacy_patterns = {
    "fallback" .. "_workspace_id",
    "current" .. "_workspace_id",
    "current" .. "_repository_id",
    "markdown" .. "_path",
  }
  for _, file in ipairs(test_files()) do
    if file ~= "tests/test_suite_hygiene.lua" then
      local text = read_file(file)
      for _, pattern in ipairs(legacy_patterns) do
        if text:match(pattern) then
          table.insert(offenders, file)
          break
        end
      end
    end
  end
  expect.equality(offenders, {})
end

return T
