local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()
local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local plugin_root = vim.fn.fnamemodify(test_dir, ":h")

local function loci_path(rel)
  return vim.fn.fnameescape(plugin_root .. "/" .. rel)
end

local function run_capture(cmd)
  local out = vim.fn.system(cmd)
  return vim.v.shell_error, out
end

local function nonempty_lines(text)
  local lines = {}
  for line in text:gmatch("[^\n]+") do
    if line ~= "" then
      table.insert(lines, line)
    end
  end
  return lines
end

T["layer boundaries: service has no ui imports"] = function()
  local code, out = run_capture("rg -n \"require\\(.*loci\\.ui\" " .. loci_path("lua/loci/service") .. " --glob '*.lua'")
  expect.equality(code, 1, out)
end

T["layer boundaries: ui has no direct store imports except documented seams"] = function()
  local code, out = run_capture("rg -n \"require\\(.*loci\\.store\" " .. loci_path("lua/loci/ui") .. " --glob '*.lua'")
  if code == 1 then
    expect.equality(true, true)
    return
  end
  local filtered = {}
  for _, line in ipairs(nonempty_lines(out)) do
    if not line:match("ui/commands/completion%.lua")
      and not line:match("ui/status%.lua") then
      table.insert(filtered, line)
    end
  end
  expect.equality(#filtered, 0, table.concat(filtered, "\n"))
end

T["layer boundaries: only runtime module may read vim.t in service layer"] = function()
  local code, out = run_capture("rg -n \"vim\\.t\\.\" " .. loci_path("lua/loci/service") .. " --glob '*.lua'")
  if code == 1 then
    expect.equality(true, true)
    return
  end
  local filtered = {}
  for _, line in ipairs(nonempty_lines(out)) do
    if not line:match("service/runtime%.lua") then
      table.insert(filtered, line)
    end
  end
  expect.equality(#filtered, 0, table.concat(filtered, "\n"))
end

T["layer boundaries: no legacy top-level linked_files service; workspace module exists"] = function()
  local ok_legacy = pcall(require, "loci.service.linked_files")
  expect.equality(ok_legacy, false)

  local ok_workspace = pcall(require, "loci.service.workspace.linked_files")
  expect.equality(ok_workspace, true)
end

return T
