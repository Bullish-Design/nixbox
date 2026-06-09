local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

T["project Haunt DirChanged autocmd does not override LOCI workspace Haunt"] = function()
  helpers.reset_modules()
  pcall(vim.api.nvim_del_augroup_by_name, "HauntProjectDir")

  local calls = {}
  package.loaded["productivity.notes"] = {
    project_notes_dir = function()
      return "/tmp/project-notes"
    end,
  }
  package.loaded["haunt"] = {
    setup = function() end,
  }
  package.loaded["haunt.api"] = {
    change_data_dir = function(path)
      table.insert(calls, path)
      return true
    end,
  }

  local old_ws = vim.t.loci_workspace_id
  vim.t.loci_workspace_id = "workspace-active-abc123"

  local root = helpers.plugin_root()
  local ok, err = xpcall(function()
    dofile(root .. "/lua/development/haunt.lua")
    local before = #calls
    vim.api.nvim_exec_autocmds("DirChanged", {})
    expect.equality(#calls, before)
  end, debug.traceback)

  vim.t.loci_workspace_id = old_ws
  pcall(vim.api.nvim_del_augroup_by_name, "HauntProjectDir")
  if not ok then
    error(err)
  end
end

return T
