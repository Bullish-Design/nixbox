local result = require("loci.result")
local workspace_service = require("loci.service.workspace")
local forms = require("loci.ui.forms")
local util = require("loci.ui.commands.util")

local M = {}

function M.register()
  vim.api.nvim_create_user_command("LociTrailList", function()
    util.run_async(function()
      return workspace_service.list_trails(nil)
    end, function(r)
      if not r.ok then
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        return
      end
      local lines = {}
      for _, item in ipairs(r.value.trails) do
        local marker = item.active and "*" or " "
        table.insert(lines, marker .. " " .. item.logical_name .. " -> " .. item.trail_name)
      end
      util.notify_result("LOCI Trails:\n" .. table.concat(lines, "\n"), result.ok())
    end)
  end, {
    desc = "List LOCI Wayfinder Trails for current workspace",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailCreate", function(args)
    local logical_name = args.args ~= "" and args.args or nil
    local function run(name)
      util.run_async(function()
        return workspace_service.create_trail(nil, name)
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Trail created: " .. r.value.logical_name, result.ok())
        else
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end

    if logical_name then
      run(logical_name)
    else
      forms.trail_new({}, function(form_r)
        if not form_r.ok then
          util.notify_result("LOCI: Trail creation cancelled", form_r)
          return
        end
        run(form_r.value.logical_name)
      end)
    end
  end, {
    nargs = "?",
    desc = "Create a new LOCI Wayfinder Trail",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailSwitch", function(args)
    local logical_name = args.args ~= "" and args.args or nil
    local function run(name)
      util.run_async(function()
        return workspace_service.switch_trail(nil, name)
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Trail switched to " .. r.value.logical_name, result.ok())
        else
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end

    if logical_name then
      run(logical_name)
    else
      util.run_async(function()
        return workspace_service.list_trails(nil)
      end, function(list_r)
        if not list_r.ok then
          util.notify_result("LOCI: " .. list_r.err, result.err("notification", "unknown"))
          return
        end
        local choices = {}
        for _, item in ipairs(list_r.value.trails) do
          table.insert(choices, item.logical_name)
        end
        forms.trail_select({ choices = choices }, function(choice_r)
          if not choice_r.ok then
            util.notify_result("LOCI: Trail switch cancelled", choice_r)
            return
          end
          run(choice_r.value)
        end)
      end)
    end
  end, {
    nargs = "?",
    desc = "Switch active LOCI Wayfinder Trail",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailSave", function(_args)
    util.run_async(function()
      return workspace_service.save_active_trail(nil)
    end, function(r)
      if r.ok then
        local msg = "LOCI: Trail saved"
        if r.value.integration and r.value.integration.user_action_required then
          msg = msg .. " (interactive command - complete in Wayfinder)"
        end
        util.notify_result(msg, result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "Save active LOCI Wayfinder Trail",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailLoad", function(args)
    local logical_name = args.args ~= "" and args.args or nil
    util.run_async(function()
      return workspace_service.load_trail(nil, logical_name)
    end, function(r)
      if r.ok then
        local msg = "LOCI: Trail loaded"
        if r.value.integration and r.value.integration.user_action_required then
          msg = msg .. " (interactive command - complete in Wayfinder)"
        end
        util.notify_result(msg, result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    nargs = "?",
    desc = "Load a LOCI Wayfinder Trail",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailRename", function(args)
    local old_name, new_name = args.args:match("^(%S+)%s+(%S+)$")
    if not old_name or not new_name then
      util.notify_result("LOCI: usage: LociTrailRename <old> <new>", result.err("notification", "unknown"))
      return
    end
    util.run_async(function()
      return workspace_service.rename_trail(nil, old_name, new_name)
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Trail renamed to " .. r.value.new_logical_name, result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    nargs = "+",
    desc = "Rename a LOCI Wayfinder Trail",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailDelete", function(args)
    local logical_name = args.args
    if logical_name == "" then
      util.notify_result("LOCI: Trail name required", result.err("notification", "unknown"))
      return
    end
    util.run_async(function()
      return workspace_service.delete_trail(nil, logical_name)
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Trail deleted", result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    nargs = "+",
    desc = "Delete a LOCI Wayfinder Trail",
    force = true,
  })

  vim.api.nvim_create_user_command("LociTrailExport", function()
    util.run_async(function()
      return workspace_service.export_trail_quickfix(nil)
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Trail exported to quickfix", result.ok())
      else
        util.notify_result("LOCI: " .. (r.err or "export failed"), result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "Export LOCI Wayfinder Trail to quickfix",
    force = true,
  })
end

return M
