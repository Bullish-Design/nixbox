local result = require("loci.result")
local workspace_service = require("loci.service.workspace")
local forms = require("loci.ui.forms")
local util = require("loci.ui.commands.util")

local M = {}

function M.register()
  vim.api.nvim_create_user_command("LociHauntList", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id = tokens[1] or nil
    util.run_async(function()
      return workspace_service.haunt_list(workspace_id)
    end, function(r)
      if r.ok then
        local result = r.value
        local lines = { "Haunt contexts for " .. result.workspace_name .. ":" }
        for _, ctx in ipairs(result.contexts) do
          local prefix = ctx.active and "* " or "  "
          table.insert(lines, prefix .. ctx.name .. "  " .. ctx.data_dir)
        end
        util.notify_result(table.concat(lines, "\n"), result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "List Haunt contexts for a workspace",
    nargs = "?",
    force = true,
  })

  vim.api.nvim_create_user_command("LociHauntNew", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, name

    if #tokens == 1 then
      name = tokens[1]
    elseif #tokens >= 2 then
      workspace_id = tokens[1]
      name = tokens[2]
    end

    if not name then
      util.notify_result("LOCI: Haunt context name is required", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.haunt_new(workspace_id, name)
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Haunt context '" .. name .. "' created", result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "Create a new Haunt context",
    nargs = "+",
    force = true,
  })

  vim.api.nvim_create_user_command("LociHauntSwitch", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, name

    if #tokens == 1 then
      name = tokens[1]
    elseif #tokens >= 2 then
      workspace_id = tokens[1]
      name = tokens[2]
    end

    if not name then
      util.notify_result("LOCI: Haunt context name is required", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.haunt_switch(workspace_id, name)
    end, function(r)
      if r.ok then
        if r.value.integration and not r.value.integration.ok then
          util.notify_result("LOCI: Switched to context '" .. name .. "' (Haunt unavailable)", result.err("notification", "unknown"))
        else
          util.notify_result("LOCI: Switched to Haunt context '" .. name .. "'", result.ok())
        end
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "Switch active Haunt context",
    nargs = "+",
    force = true,
  })

  vim.api.nvim_create_user_command("LociHauntRename", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, old_name, new_name

    if #tokens == 2 then
      old_name = tokens[1]
      new_name = tokens[2]
    elseif #tokens >= 3 then
      workspace_id = tokens[1]
      old_name = tokens[2]
      new_name = tokens[3]
    end

    if not old_name or not new_name then
      util.notify_result("LOCI: Old and new context names are required", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.haunt_rename(workspace_id, old_name, new_name)
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Renamed Haunt context '" .. old_name .. "' to '" .. new_name .. "'", result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "Rename a Haunt context",
    nargs = "+",
    force = true,
  })

  vim.api.nvim_create_user_command("LociHauntDelete", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, name

    if #tokens == 1 then
      name = tokens[1]
    elseif #tokens >= 2 then
      workspace_id = tokens[1]
      name = tokens[2]
    end

    if not name then
      util.notify_result("LOCI: Haunt context name is required", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.haunt_delete(workspace_id, name)
    end, function(r)
      if not r.ok and r.code == "conflict" and r.meta and r.meta.requires_confirmation then
        forms.haunt_context_delete({ name = name }, function(confirm_r)
          if not confirm_r.ok then
            util.notify_result("LOCI: Cancelled context deletion", confirm_r)
            return
          end
          if not confirm_r.value then
            util.notify_result("LOCI: Cancelled context deletion", result.ok(false))
            return
          end
          util.run_async(function()
            return workspace_service.haunt_delete(workspace_id, name, { confirm = true })
          end, function(confirm_result)
            if confirm_result.ok then
              util.notify_result("LOCI: Deleted Haunt context '" .. name .. "'", result.ok())
            else
              util.notify_result("LOCI: " .. confirm_result.err, result.err("notification", "unknown"))
            end
          end)
        end)
      elseif r.ok then
        util.notify_result("LOCI: Deleted Haunt context '" .. name .. "'", result.ok())
      else
        util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
      end
    end)
  end, {
    desc = "Delete a Haunt context",
    nargs = "+",
    force = true,
  })
end

return M
