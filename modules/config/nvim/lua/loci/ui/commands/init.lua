local result = require("loci.result")
local util = require("loci.ui.commands.util")

local M = {}

local registered = false

function M.register()
  if registered then
    return result.ok({ registered = false, reason = "already_registered" })
  end

  -- Register all command submodules
  require("loci.ui.commands.repository").register()
  require("loci.ui.commands.workspace").register()
  require("loci.ui.commands.project").register()
  require("loci.ui.commands.haunt").register()
  require("loci.ui.commands.trails").register()
  require("loci.ui.commands.notes").register()

  -- Global refresh commands
  vim.api.nvim_create_user_command("LociRefresh", function()
    util.run_async(function()
      local refresh_async = require("loci.service.refresh_async")
      return refresh_async.refresh_all({
        on_progress = function(progress)
          -- Progress hook reserved for future status integration.
          return progress
        end,
      })
    end, function(r)
      if r.ok then
        util.notify_result(
          string.format(
            "LOCI: refreshed %d Markdown objects, %d projects, %d workspaces (%d diagnostics)",
            r.value.markdown_count or 0,
            r.value.project_count or 0,
            r.value.workspace_count or 0,
            #(r.value.diagnostics or {})
          ),
          result.ok()
        )
      else
        util.notify_result("LOCI: refresh failed", r)
      end
    end)
  end, {
    desc = "Refresh LOCI indexes and caches",
    force = true,
  })

  vim.api.nvim_create_user_command("LociJobCancel", function(cmd)
    local jobs = require("loci.service.jobs")
    local active = jobs.list()
    if #active == 0 then
      vim.notify("LOCI: No active jobs", vim.log.levels.INFO)
      return
    end
    if cmd.args and #cmd.args > 0 then
      local r = jobs.cancel(cmd.args)
      util.notify_result("Cancel", r)
    else
      local r = jobs.cancel(active[#active].id)
      util.notify_result("Cancel", r)
    end
  end, { nargs = "?", desc = "Cancel active Loci job" })

  vim.api.nvim_create_user_command("LociJobList", function()
    local jobs = require("loci.service.jobs")
    local active = jobs.list()
    if #active == 0 then
      vim.notify("LOCI: No active jobs", vim.log.levels.INFO)
      return
    end
    for _, job in ipairs(active) do
      local status = job.cancelled and "CANCELLING" or "RUNNING"
      local progress = ""
      if job.progress then
        progress = string.format(" [%d/%d]", job.progress.current, job.progress.total)
      end
      vim.notify(string.format("  %s %s: %s%s", status, job.id, job.name, progress))
    end
  end, { desc = "List active Loci jobs" })

  registered = true
  return result.ok({ registered = true })
end

function M.reset_for_tests()
  registered = false
  util.reset_for_tests = function() end
end

-- Export completion functions from completion module
local completion = require("loci.ui.commands.completion")
M.complete_project_id = completion.complete_project_id
M.complete_workspace_id = completion.complete_workspace_id
M.complete_markdown_id = completion.complete_markdown_id
M.complete_content_path = completion.complete_content_path
M.complete_haunt_context = completion.complete_haunt_context
M.complete_trail = completion.complete_trail

return M
