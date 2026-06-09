local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")
local registry = require("loci.ui.commands.registry")

local T = MiniTest.new_set()

local function read_file(path)
  local f = assert(io.open(helpers.repo_file(path), "r"))
  local text = f:read("*a")
  f:close()
  return text
end

local function read_all_docs()
  local chunks = {}
  for _, path in ipairs(vim.fn.glob(helpers.repo_file("docs/loci/**/*.md"), true, true)) do
    chunks[#chunks + 1] = table.concat(vim.fn.readfile(path), "\n")
  end
  return table.concat(chunks, "\n")
end

T["all user docs exist"] = function()
  expect.equality(vim.fn.filereadable(helpers.repo_file("docs/loci/README.md")), 1)
  expect.equality(vim.fn.filereadable(helpers.repo_file("docs/loci/commands.md")), 1)
end

T["documents all canonical commands"] = function()
  local docs = read_all_docs()
  for _, command in ipairs(registry.CANONICAL) do
    expect.equality(docs:find(command, 1, true) ~= nil, true, command .. " must be documented")
  end
end

T["does not document forbidden commands as supported"] = function()
  local docs = read_all_docs()
  for _, command in ipairs(registry.FORBIDDEN) do
    expect.equality(docs:find("`:" .. command .. "`", 1, true) == nil, true, command .. " must not be documented as supported")
  end
end

T["documents Wayfinder named API requirement"] = function()
  local text = read_file("docs/loci/wayfinder-trails.md")
  expect.equality(text:find("direct named", 1, true) ~= nil, true)
  expect.equality(text:find("interactive fallback", 1, true) == nil, true)
end

T["documents graph authority model"] = function()
  local text = read_all_docs()
  expect.equality(text:find("source of truth", 1, true) ~= nil, true)
end

return T
