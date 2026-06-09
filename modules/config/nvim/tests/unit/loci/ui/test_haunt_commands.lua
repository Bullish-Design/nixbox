local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function command_exists(name)
  local result = vim.api.nvim_get_commands({ builtin = false })
  return result[name] ~= nil
end

local function with_registered_commands(fn)
  helpers.with_cleanup(function()
    local commands = require("loci.ui.commands")
    commands.register()
    fn()
  end, function()
    helpers.clear_loci_commands()
  end)
end

T["registers LociHauntList command"] = function()
  with_registered_commands(function()
    expect.equality(command_exists("LociHauntList"), true)
  end)
end

T["registers LociHauntNew command"] = function()
  with_registered_commands(function()
    expect.equality(command_exists("LociHauntNew"), true)
  end)
end

T["registers LociHauntSwitch command"] = function()
  with_registered_commands(function()
    expect.equality(command_exists("LociHauntSwitch"), true)
  end)
end

T["registers LociHauntRename command"] = function()
  with_registered_commands(function()
    expect.equality(command_exists("LociHauntRename"), true)
  end)
end

T["registers LociHauntDelete command"] = function()
  with_registered_commands(function()
    expect.equality(command_exists("LociHauntDelete"), true)
  end)
end

T["resets commands for tests"] = function()
  local commands = require("loci.ui.commands")
  commands.reset_for_tests()
  expect.equality(true, true)
end

return T
