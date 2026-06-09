local result = require("loci.result")
local project_service = require("loci.service.project")
local project_forms = require("loci.ui.forms")
local project_picker = require("loci.ui.picker")
local util = require("loci.ui.commands.util")
local completion = require("loci.ui.commands.completion")

local M = {}

local function resolve_project_id_input(value)
  if not value or value == "" then
    return result.err("project argument is required", "invalid_input")
  end
  local entries_r = project_service.index_entries()
  if not entries_r.ok then
    return entries_r
  end
  local entries = entries_r.value or {}
  local exact = {}
  local insensitive = {}
  for _, entry in ipairs(entries) do
    if entry.project_id == value or entry.content_path == value or entry.title == value then
      table.insert(exact, entry)
    elseif type(entry.title) == "string" and entry.title:lower() == value:lower() then
      table.insert(insensitive, entry)
    end
  end
  if #exact == 1 then
    return result.ok(exact[1].project_id)
  end
  if #exact > 1 then
    return result.err("Ambiguous project argument", "conflict", { matches = exact })
  end
  if #insensitive == 1 then
    return result.ok(insensitive[1].project_id)
  end
  if #insensitive > 1 then
    return result.err("Ambiguous project argument", "conflict", { matches = insensitive })
  end
  return result.err("project not found: " .. value, "not_found")
end

function M.register()
  vim.api.nvim_create_user_command("LociProjectCreate", function(args)
    local title = args.args ~= "" and args.args or nil
    project_forms.project_new({ title = title }, function(opts_res)
      if not opts_res.ok then
        util.notify_result("LOCI: " .. opts_res.err, result.err("notification", "unknown"))
        return
      end
      util.run_async(function()
        return project_service.create(vim.tbl_extend("force", opts_res.value, { open = true }))
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Project '" .. r.value.title_cache .. "' created", result.ok())
        else
          util.notify_result("LOCI: Project creation failed", r)
        end
      end)
    end)
  end, {
    desc = "Create a new project",
    nargs = "?",
    force = true,
  })

  vim.api.nvim_create_user_command("LociProjectOpen", function(args)
    local project_id = args.args ~= "" and args.args or nil
    if not project_id then
      project_picker.project(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return project_service.open(res.value.project_id)
        end, function(r)
          if not r.ok then
            util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
          end
        end)
      end)
    else
      util.run_async(function()
        local resolved_r = resolve_project_id_input(project_id)
        if not resolved_r.ok then
          return resolved_r
        end
        return project_service.open(resolved_r.value)
      end, function(r)
        if not r.ok then
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end
  end, {
    desc = "Open a project",
    nargs = "?",
    complete = completion.complete_project_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociProjectSwitch", function(args)
    local project_id = args.args ~= "" and args.args or nil
    if project_id then
      util.run_async(function()
        local resolved_r = resolve_project_id_input(project_id)
        if not resolved_r.ok then
          return resolved_r
        end
        return project_service.open(resolved_r.value)
      end, function(r)
        if not r.ok then
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
      return
    end

    project_picker.project(function(res)
      if not res.ok then
        util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
        return
      end
      util.run_async(function()
        return project_service.open(res.value.project_id)
      end, function(r)
        if not r.ok then
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end)
  end, {
    desc = "Switch active project",
    nargs = "?",
    complete = completion.complete_project_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociProjectLink", function(args)
    local project_id = args.args ~= "" and args.args or nil
    if not project_id then
      project_picker.project(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return project_service.link_current({ project_id = res.value.project_id })
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Linked to '" .. r.value.project.title_cache .. "'", result.ok())
          else
            util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
          end
        end)
      end)
    else
      util.run_async(function()
        local resolved_r = resolve_project_id_input(project_id)
        if not resolved_r.ok then
          return resolved_r
        end
        return project_service.link_current({ project_id = resolved_r.value })
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Linked to '" .. r.value.project.title_cache .. "'", result.ok())
        else
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end
  end, {
    desc = "Link current note to a project",
    nargs = "?",
    complete = completion.complete_project_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociProjectInfo", function(args)
    local project_id = args.args ~= "" and args.args or nil
    if not project_id then
      project_picker.project(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return project_service.info(res.value.project_id)
        end, function(r)
          if r.ok then
            local info = r.value
            local msg = string.format(
              "Project: %s [%s]\nTasks: %d | Issues: %d | Notes: %d | Workspaces: %d",
              info.title, info.status, info.task_count, info.issue_count, info.note_count, info.workspace_count
            )
            util.notify_result(msg, result.ok())
          else
            util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
          end
        end)
      end)
    else
      util.run_async(function()
        local resolved_r = resolve_project_id_input(project_id)
        if not resolved_r.ok then
          return resolved_r
        end
        return project_service.info(resolved_r.value)
      end, function(r)
        if r.ok then
          local info = r.value
          local msg = string.format(
            "Project: %s [%s]\nTasks: %d | Issues: %d | Notes: %d | Workspaces: %d",
            info.title, info.status, info.task_count, info.issue_count, info.note_count, info.workspace_count
          )
          util.notify_result(msg, result.ok())
        else
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end
  end, {
    desc = "Show project information",
    nargs = "?",
    complete = completion.complete_project_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociProjectRefresh", function(args)
    local project_id = args.args ~= "" and args.args or nil
    if not project_id then
      project_picker.project(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return project_service.refresh(res.value.project_id)
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Project '" .. r.value.title_cache .. "' refreshed", result.ok())
          else
            util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
          end
        end)
      end)
    else
      util.run_async(function()
        local resolved_r = resolve_project_id_input(project_id)
        if not resolved_r.ok then
          return resolved_r
        end
        return project_service.refresh(resolved_r.value)
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Project '" .. r.value.title_cache .. "' refreshed", result.ok())
        else
          util.notify_result("LOCI: " .. r.err, result.err("notification", "unknown"))
        end
      end)
    end
  end, {
    desc = "Refresh project cache",
    nargs = "?",
    force = true,
  })
end

return M
