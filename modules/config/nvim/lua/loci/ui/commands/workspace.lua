local result = require("loci.result")
local repository = require("loci.service.repository")
local workspace_service = require("loci.service.workspace")
local project_forms = require("loci.ui.forms")
local project_picker = require("loci.ui.picker")
local util = require("loci.ui.commands.util")

local M = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Check if a workspace ID exists in the graph.
---@param value string
---@return boolean
local function workspace_exists(value)
  if not value or value == "" then return false end
  return workspace_service.exists(value)
end

---Get the current active workspace ID from tab-local variable.
---@return string|nil
local function current_workspace_id()
  local workspace_id = vim.t.loci_workspace_id
  if workspace_id and workspace_id ~= "" then return workspace_id end
  return nil
end

local function join_tokens(tokens, start_idx)
  return table.concat(tokens, " ", start_idx)
end

local function resolve_workspace_and_value(tokens, opts)
  opts = opts or {}
  tokens = tokens or {}

  if #tokens == 0 then
    return current_workspace_id(), nil
  end

  if #tokens == 1 then
    local first = tokens[1]
    if workspace_exists(first) then
      return first, nil
    end
    return current_workspace_id(), first
  end

  local value
  if opts.join_value ~= false then
    value = join_tokens(tokens, 2)
  else
    value = tokens[2]
  end

  return tokens[1], value
end

M._resolve_workspace_and_value_for_tests = resolve_workspace_and_value
M._workspace_exists_for_tests = workspace_exists

function M.register()
  vim.api.nvim_create_user_command("LociWorkspaceSwitch", function(args)
    local workspace_id = args.args ~= "" and args.args or nil
    if not workspace_id then
      project_picker.workspace(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return workspace_service.open(res.value.workspace_id)
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Workspace opened: " .. r.value.workspace_name, r)
          else
            util.notify_result("LOCI: Failed to open workspace", r)
          end
        end)
      end)
      return
    end

    util.run_async(function()
      return workspace_service.open(workspace_id)
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Workspace opened: " .. r.value.workspace_name, r)
      else
        util.notify_result("LOCI: Failed to open workspace", r)
      end
    end)
  end, {
    desc = "Switch active workspace",
    nargs = "?",
    complete = require("loci.ui.commands.completion").complete_workspace_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociRepositoryOpen", function()
    util.run_async(function()
      return repository.open_repository()
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Repository workspace opened", r)
      else
        util.notify_result("LOCI: Failed to open repository workspace", r)
      end
    end)
  end, {
    desc = "Activate the repository fallback workspace",
    force = true,
  })

  vim.api.nvim_create_user_command("LociWorkspaceCreate", function(args)
    local name = args.args ~= "" and args.args or nil
    project_forms.workspace_new({ name = name }, function(form_r)
      if not form_r.ok then
        util.notify_result("LOCI: Workspace cancelled", form_r)
        return
      end
      util.run_async(function()
        return workspace_service.create(form_r.value)
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Workspace created: " .. r.value.name, result.ok())
        else
          util.notify_result("LOCI: Workspace create failed", r)
        end
      end)
    end)
  end, {
    desc = "Create a new workspace",
    nargs = "?",
    complete = require("loci.ui.commands.completion").complete_workspace_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociWorkspaceClone", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, clone_name

    if #tokens == 0 then
      -- Pick source workspace then prompt for name
      project_picker.workspace(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        workspace_id = res.value.workspace_id
        local source_name = res.value.name or workspace_id
        project_forms.workspace_clone({ workspace_id = workspace_id, default_name = source_name .. " copy" }, function(form_r)
          if not form_r.ok then
            util.notify_result("LOCI: Clone cancelled", form_r)
            return
          end
          util.run_async(function()
            return workspace_service.clone(workspace_id, form_r.value)
          end, function(r)
            if r.ok then
              util.notify_result("LOCI: Workspace cloned: " .. r.value.name, result.ok())
            else
              util.notify_result("LOCI: Clone failed", r)
            end
          end)
        end)
      end)
    elseif #tokens == 1 then
      -- Workspace ID supplied, prompt for name
      workspace_id = tokens[1]
      project_forms.workspace_clone({ workspace_id = workspace_id }, function(form_r)
        if not form_r.ok then
          util.notify_result("LOCI: Clone cancelled", form_r)
          return
        end
        util.run_async(function()
          return workspace_service.clone(workspace_id, form_r.value)
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Workspace cloned: " .. r.value.name, result.ok())
          else
            util.notify_result("LOCI: Clone failed", r)
          end
        end)
      end)
    else
      -- Both workspace ID and name supplied
      workspace_id = tokens[1]
      clone_name = table.concat(tokens, " ", 2)
      util.run_async(function()
        return workspace_service.clone(workspace_id, { name = clone_name })
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Workspace cloned: " .. r.value.name, result.ok())
        else
          util.notify_result("LOCI: Clone failed", r)
        end
      end)
    end
  end, {
    desc = "Clone a workspace",
    nargs = "*",
    complete = require("loci.ui.commands.completion").complete_workspace_id,
    force = true,
  })

  vim.api.nvim_create_user_command("LociKnowledgeAdd", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, content_path

    if #tokens == 0 then
      -- 0 args: use current workspace + pick markdown
      workspace_id = current_workspace_id()
      if not workspace_id then
        util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
        return
      end
      project_picker.markdown(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return workspace_service.add_knowledge(workspace_id, res.value.content_path, { primary = false })
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Knowledge added to workspace", result.ok())
          else
            util.notify_result("LOCI: Add knowledge failed", r)
          end
        end)
      end)
    elseif #tokens == 1 then
      -- 1 arg: if existing workspace_id, use it + pick markdown; else current workspace + treat as content_path
      if workspace_exists(tokens[1]) then
        -- Arg is existing workspace ID
        workspace_id = tokens[1]
        project_picker.markdown(function(res)
          if not res.ok then
            util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
            return
          end
          util.run_async(function()
            return workspace_service.add_knowledge(workspace_id, res.value.content_path, { primary = false })
          end, function(r)
            if r.ok then
              util.notify_result("LOCI: Knowledge added to workspace", result.ok())
            else
              util.notify_result("LOCI: Add knowledge failed", r)
            end
          end)
        end)
      else
        -- Arg is content path, use current workspace
        workspace_id = current_workspace_id()
        if not workspace_id then
          util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
          return
        end
        content_path = tokens[1]
        util.run_async(function()
          return workspace_service.add_knowledge(workspace_id, content_path, { primary = false })
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Knowledge added to workspace", result.ok())
          else
            util.notify_result("LOCI: Add knowledge failed", r)
          end
        end)
      end
    else
      -- 2+ args: first is workspace ID, rest is content path
      workspace_id = tokens[1]
      content_path = table.concat(tokens, " ", 2)
      util.run_async(function()
        return workspace_service.add_knowledge(workspace_id, content_path, { primary = false })
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Knowledge added to workspace", result.ok())
        else
          util.notify_result("LOCI: Add knowledge failed", r)
        end
      end)
    end
  end, {
    desc = "Add knowledge to workspace",
    nargs = "*",
    force = true,
  })

  vim.api.nvim_create_user_command("LociKnowledgeRemove", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, loci_id = resolve_workspace_and_value(tokens, { join_value = false })

    if #tokens == 0 or (#tokens == 1 and workspace_exists(tokens[1])) then
      -- 0 args: use current workspace + pick knowledge
      if not workspace_id then
        util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
        return
      end
      project_picker.knowledge(workspace_id, function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return workspace_service.remove_knowledge(workspace_id, res.value.loci_id)
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Knowledge removed from workspace", result.ok())
          else
            util.notify_result("LOCI: Remove knowledge failed", r)
          end
        end)
      end)
    else
      if not workspace_id or not loci_id then
        util.notify_result("LOCI: Workspace and loci_id are required", result.err("notification", "unknown"))
        return
      end
      util.run_async(function()
        return workspace_service.remove_knowledge(workspace_id, loci_id)
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Knowledge removed from workspace", result.ok())
        else
          util.notify_result("LOCI: Remove knowledge failed", r)
        end
      end)
    end
  end, {
    desc = "Remove knowledge from workspace",
    nargs = "*",
    force = true,
  })

  vim.api.nvim_create_user_command("LociKnowledgeSetPrimary", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, loci_id = resolve_workspace_and_value(tokens, { join_value = false })

    if #tokens == 0 or (#tokens == 1 and workspace_exists(tokens[1])) then
      -- 0 args: use current workspace + pick knowledge
      if not workspace_id then
        util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
        return
      end
      project_picker.knowledge(workspace_id, function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return workspace_service.set_primary(workspace_id, res.value.loci_id)
        end, function(r)
          if r.ok then
            util.notify_result("LOCI: Primary knowledge updated", result.ok())
          else
            util.notify_result("LOCI: Set primary failed", r)
          end
        end)
      end)
    else
      if not workspace_id or not loci_id then
        util.notify_result("LOCI: Workspace and loci_id are required", result.err("notification", "unknown"))
        return
      end
      util.run_async(function()
        return workspace_service.set_primary(workspace_id, loci_id)
      end, function(r)
        if r.ok then
          util.notify_result("LOCI: Primary knowledge updated", result.ok())
        else
          util.notify_result("LOCI: Set primary failed", r)
        end
      end)
    end
  end, {
    desc = "Set primary knowledge for workspace",
    nargs = "*",
    force = true,
  })

  vim.api.nvim_create_user_command("LociFileLink", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, file_path = resolve_workspace_and_value(tokens, { join_value = true })
    local current_file = vim.api.nvim_buf_get_name(0)

    if #tokens == 0 or (#tokens == 1 and workspace_exists(tokens[1])) then
      file_path = current_file
    end
    if not workspace_id then
      util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.link_current_file(workspace_id, { path = file_path })
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: File linked to workspace", result.ok())
      else
        util.notify_result("LOCI: Link file failed", r)
      end
    end)
  end, {
    desc = "Link current file to workspace",
    nargs = "*",
    force = true,
  })

  vim.api.nvim_create_user_command("LociFileUnlink", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, file_path = resolve_workspace_and_value(tokens, { join_value = true })
    local current_file = vim.api.nvim_buf_get_name(0)

    if #tokens == 0 or (#tokens == 1 and workspace_exists(tokens[1])) then
      file_path = current_file
    end
    if not workspace_id then
      util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.unlink_current_file(workspace_id, { path = file_path })
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: File unlinked from workspace", result.ok())
      else
        util.notify_result("LOCI: Unlink file failed", r)
      end
    end)
  end, {
    desc = "Unlink file from workspace",
    nargs = "*",
    force = true,
  })

  vim.api.nvim_create_user_command("LociWorkspaceInfo", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id = tokens[1] or vim.t.loci_workspace_id

    if not workspace_id then
      project_picker.workspace(function(res)
        if not res.ok then
          util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
          return
        end
        util.run_async(function()
          return workspace_service.info(res.value.workspace_id)
        end, function(r)
          if r.ok then
            local info = r.value
            local msg = string.format(
              "Workspace: %s [%s]\nProject: %s\nKnowledge: %d | Linked files: %d",
              info.name or "Unnamed", info.workspace_id, info.project_title or "N/A",
              info.knowledge_count or 0, info.linked_file_count or 0
            )
            util.notify_result(msg, result.ok())
          else
            util.notify_result("LOCI: Workspace info failed", r)
          end
        end)
      end)
    else
      util.run_async(function()
        return workspace_service.info(workspace_id)
      end, function(r)
        if r.ok then
          local info = r.value
          local msg = string.format(
            "Workspace: %s [%s]\nProject: %s\nKnowledge: %d | Linked files: %d",
            info.name or "Unnamed", info.workspace_id, info.project_title or "N/A",
            info.knowledge_count or 0, info.linked_file_count or 0
          )
          util.notify_result(msg, result.ok())
        else
          util.notify_result("LOCI: Workspace info failed", r)
        end
      end)
    end
  end, {
    desc = "Show workspace information",
    nargs = "?",
    force = true,
  })

  vim.api.nvim_create_user_command("LociWorkspaceArchive", function(args)
    local tokens = util.split_args(args.args)
    local workspace_id, reason = resolve_workspace_and_value(tokens, { join_value = true })
    local remove_from_project = args.bang or false

    if #tokens == 0 then
      -- 0 args: use current workspace or picker
      workspace_id = current_workspace_id()
      if not workspace_id then
        -- No current workspace, show picker
        project_picker.workspace(function(res)
          if not res.ok then
            util.notify_result("LOCI: " .. res.err, result.err("notification", "unknown"))
            return
          end
          util.run_async(function()
            return workspace_service.archive(res.value.workspace_id, { reason = nil, remove_from_project = remove_from_project })
          end, function(r)
            if r.ok then
              util.notify_result("LOCI: Workspace archived", result.ok())
            else
              util.notify_result("LOCI: Archive failed", r)
            end
          end)
        end)
        return
      end
    elseif not workspace_id then
      util.notify_result("LOCI: No active workspace", result.err("notification", "unknown"))
      return
    end

    util.run_async(function()
      return workspace_service.archive(workspace_id, { reason = reason, remove_from_project = remove_from_project })
    end, function(r)
      if r.ok then
        util.notify_result("LOCI: Workspace archived", result.ok())
      else
        util.notify_result("LOCI: Archive failed", r)
      end
    end)
  end, {
    desc = "Archive a workspace (use ! to remove from project)",
    nargs = "*",
    bang = true,
    force = true,
  })

  vim.api.nvim_create_user_command("LociWorkspaceRefresh", function(args)
    local workspace_id = args.args ~= "" and args.args or nil

    util.run_async(function()
      if not workspace_id then
        -- Try to use current workspace
        local current_r = require("loci.service.activation").current()
        if not current_r.ok or not current_r.value then
          return result.err("Workspace ID required or no active workspace")
        end
        workspace_id = current_r.value.workspace_id
      end
      return workspace_service.refresh(workspace_id)
    end, function(r)
      if r.ok then
        util.notify_result(
          string.format("LOCI: refreshed workspace %s (%d diagnostics)", workspace_id, #(r.value.diagnostics or {})),
          result.ok()
        )
      else
        util.notify_result("LOCI: workspace refresh failed", r)
      end
    end)
  end, {
    nargs = "?",
    desc = "Refresh a specific LOCI workspace by ID or current workspace",
    force = true,
  })
end

return M
