local result = require("loci.result")
local graph = require("loci.store.graph")
local tx = require("loci.service.workspace.tx")
local validation = require("loci.service.workspace.validation")
local resolve = require("loci.service.workspace.resolve")
local haunt_adapter = require("loci.integrations.haunt")
local registry = require("loci.service.workspace.registry")

local M = {}

local function current_workspace_id()
  local current_r = resolve.resolve_workspace_id(nil)
  if current_r.ok then
    return current_r.value
  end
  return nil
end

local contexts = registry.new({
  section = "haunt",
  entries_key = "contexts",
  active_key = "active",
  item_label = "Haunt context",
  default_name = "main",
  validate_name = validation.validate_context_name,
  allow_delete_default = true,
  allow_delete_last = false,
  make_entry = function(workspace, name)
    local data_dir_r = haunt_adapter.context_data_dir(workspace.workspace_id, name)
    if not data_dir_r.ok then
      return data_dir_r
    end
    return result.ok({ data_dir = data_dir_r.value })
  end,
})

local function maybe_change_runtime_data_dir(workspace_id, data_dir, opts)
  opts = opts or {}

  if opts.activate == false or not validation.is_active_workspace(workspace_id, current_workspace_id()) then
    return result.ok({ attempted = false, reason = "workspace inactive" })
  end

  local abs_r = haunt_adapter.abs_context_dir(data_dir)
  if not abs_r.ok then
    return abs_r
  end

  local change_r = haunt_adapter.change_data_dir(abs_r.value)
  if change_r.ok then
    return result.ok({ attempted = true, changed = true, abs_data_dir = abs_r.value })
  end

  if change_r.code == "integration_unavailable" then
    return result.ok({
      attempted = true,
      changed = false,
      integration = {
        ok = false,
        code = change_r.code,
        err = change_r.err,
      },
      abs_data_dir = abs_r.value,
    })
  end

  return result.err(change_r.err, change_r.code, {
    workspace_id = workspace_id,
    data_dir = data_dir,
    abs_data_dir = abs_r.value,
    integration = "haunt",
  })
end

function M.haunt_list(workspace_id)
  local list_r = contexts:list(workspace_id)
  if not list_r.ok then
    return list_r
  end

  local workspace = list_r.value.workspace
  local output = {}

  for _, item in ipairs(list_r.value.items) do
    local context = item.entry
    local info_r = haunt_adapter.context_dir_info(context.data_dir)

    local info = {
      name = item.name,
      active = item.active,
      data_dir = context.data_dir,
    }

    if info_r.ok then
      local dir_info = info_r.value
      info.abs_data_dir = dir_info.abs_data_dir
      info.exists = dir_info.exists
      info.non_empty = dir_info.non_empty
      info.file_count = dir_info.file_count
    else
      info.abs_data_dir = ""
      info.exists = false
      info.non_empty = false
      info.file_count = 0
    end

    output[#output + 1] = info
  end

  return result.ok({
    workspace_id = workspace.workspace_id,
    workspace_name = workspace.name,
    active = list_r.value.active,
    contexts = output,
  })
end

function M.haunt_new(workspace_id, name, opts)
  opts = opts or {}

  if not name or name == "" then
    return result.err("Haunt context name is required", "invalid_input")
  end

  local prepared_r = contexts:prepare(workspace_id, function(workspace)
    local name_r = validation.validate_context_name(name)
    if not name_r.ok then
      return name_r
    end
    name = name_r.value

    if workspace.haunt.contexts[name] then
      return result.err("Haunt context already exists: " .. name, "conflict", {
        workspace_id = workspace.workspace_id,
        context = name,
      })
    end

    local data_dir_r = haunt_adapter.context_data_dir(workspace.workspace_id, name)
    if not data_dir_r.ok then
      return data_dir_r
    end

    workspace.haunt.contexts[name] = { data_dir = data_dir_r.value }
    if opts.switch then
      workspace.haunt.active = name
    end

    return result.ok({ name = name, data_dir = data_dir_r.value })
  end)
  if not prepared_r.ok then
    return prepared_r
  end

  local data = prepared_r.value.prepared
  local workspace = prepared_r.value.workspace

  -- Graph commit first.
  local commit_r = contexts:commit(prepared_r.value)
  if not commit_r.ok then
    return result.err(commit_r.err, commit_r.code, {
      workspace_id = workspace.workspace_id,
      context = name,
      data_dir = data.data_dir,
      meta = commit_r.meta,
    })
  end

  -- Projection: ensure directory exists after graph commit.
  local warnings = {}
  local ensure_dir_r = haunt_adapter.ensure_context_dir(data.data_dir)
  if not ensure_dir_r.ok then
    table.insert(warnings, {
      code = "haunt_dir_creation_failed",
      message = ensure_dir_r.err,
      data_dir = data.data_dir,
    })
  end

  -- Projection: activate runtime if switching.
  if opts.switch then
    local runtime_r = maybe_change_runtime_data_dir(workspace.workspace_id, data.data_dir, opts)
    if not runtime_r.ok then
      table.insert(warnings, {
        code = "haunt_runtime_projection_failed",
        message = runtime_r.err,
        data_dir = data.data_dir,
      })
    end
  end

  local result_value = {
    workspace_id = workspace.workspace_id,
    name = data.name,
    data_dir = data.data_dir,
    changed = opts.switch == true,
  }
  if #warnings > 0 then
    result_value.warnings = warnings
  end

  return result.ok(result_value)
end

function M.haunt_switch(workspace_id, name, opts)
  opts = opts or {}

  if not name or name == "" then
    return result.err("Haunt context name is required", "invalid_input")
  end

  local target_r = contexts:get(workspace_id, name)
  if not target_r.ok then
    return target_r
  end

  local workspace = target_r.value.workspace
  local entry = target_r.value.entry
  workspace_id = workspace.workspace_id

  -- Graph commit first: set active context.
  local changed = workspace.haunt.active ~= name
  if changed then
    workspace.haunt.active = name
  end

  local write_r = tx.write(workspace)
  if not write_r.ok then
    return write_r
  end

  -- Projection: ensure directory exists after graph commit.
  local warnings = {}
  local ensure_dir_r = haunt_adapter.ensure_context_dir(entry.data_dir)
  if not ensure_dir_r.ok then
    table.insert(warnings, {
      code = "haunt_dir_creation_failed",
      message = ensure_dir_r.err,
      data_dir = entry.data_dir,
    })
  end

  -- Projection: activate Haunt runtime if workspace is active.
  local integration_meta = {}
  local should_runtime = opts.activate ~= false
    and validation.is_active_workspace(workspace_id, current_workspace_id())

  if should_runtime then
    local runtime_r = maybe_change_runtime_data_dir(workspace_id, entry.data_dir, opts)
    if not runtime_r.ok then
      integration_meta = { ok = false, code = runtime_r.code, err = runtime_r.err }
      table.insert(warnings, {
        code = "haunt_runtime_projection_failed",
        message = runtime_r.err,
        data_dir = entry.data_dir,
      })
    else
      integration_meta = { ok = true, changed = runtime_r.value.changed or false }
    end
  end

  local result_value = {
    workspace_id = workspace_id,
    name = name,
    data_dir = entry.data_dir,
    changed = changed,
    integration = next(integration_meta) ~= nil and integration_meta or nil,
  }
  if #warnings > 0 then
    result_value.warnings = warnings
  end

  return result.ok(result_value)
end

function M.haunt_rename(workspace_id, old_name, new_name, opts)
  opts = opts or {}

  if not old_name or old_name == "" then
    return result.err("Haunt context old name is required", "invalid_input")
  end
  if not new_name or new_name == "" then
    return result.err("Haunt context new name is required", "invalid_input")
  end

  local prepared_r = contexts:prepare(workspace_id, function(workspace)
    local old_r = validation.validate_context_name(old_name)
    if not old_r.ok then
      return old_r
    end
    old_name = old_r.value

    local new_r = validation.validate_context_name(new_name)
    if not new_r.ok then
      return new_r
    end
    new_name = new_r.value

    local entries = workspace.haunt.contexts
    if not entries[old_name] then
      return result.err("Haunt context not found: " .. old_name, "not_found", {
        workspace_id = workspace.workspace_id,
        context = old_name,
      })
    end

    if entries[new_name] then
      return result.err("Haunt context already exists: " .. new_name, "conflict", {
        workspace_id = workspace.workspace_id,
        context = new_name,
      })
    end

    local new_data_dir_r = haunt_adapter.context_data_dir(workspace.workspace_id, new_name)
    if not new_data_dir_r.ok then
      return new_data_dir_r
    end

    local old_data_dir = entries[old_name].data_dir
    local new_data_dir = new_data_dir_r.value

    entries[new_name] = { data_dir = new_data_dir }
    entries[old_name] = nil

    if workspace.haunt.active == old_name then
      workspace.haunt.active = new_name
    end

    local validate_r = validation.validate_haunt_state(workspace)
    if not validate_r.ok then
      return validate_r
    end

    return result.ok({
      old_name = old_name,
      new_name = new_name,
      old_data_dir = old_data_dir,
      new_data_dir = new_data_dir,
      active_after = workspace.haunt.active,
    })
  end)
  if not prepared_r.ok then
    return prepared_r
  end

  local data = prepared_r.value.prepared
  local workspace = prepared_r.value.workspace

  -- Graph commit first.
  local commit_r = contexts:commit(prepared_r.value)
  if not commit_r.ok then
    return result.err(commit_r.err, commit_r.code, {
      workspace_id = workspace.workspace_id,
      step = "write_workspace_after_haunt_rename",
      old_context = data.old_name,
      new_context = data.new_name,
      old_data_dir = data.old_data_dir,
      new_data_dir = data.new_data_dir,
      moved = false,
    })
  end

  -- Projection: move directory after graph commit.
  local warnings = {}
  local move_r = haunt_adapter.move_context_dir(data.old_data_dir, data.new_data_dir)
  if not move_r.ok then
    table.insert(warnings, {
      code = "haunt_dir_move_failed",
      message = move_r.err,
      old_data_dir = data.old_data_dir,
      new_data_dir = data.new_data_dir,
    })
  end

  -- Projection: activate runtime if renamed context is now active.
  if data.active_after == data.new_name
    and validation.is_active_workspace(workspace.workspace_id, current_workspace_id())
    and opts.activate ~= false then
    local runtime_r = maybe_change_runtime_data_dir(workspace.workspace_id, data.new_data_dir, opts)
    if not runtime_r.ok then
      table.insert(warnings, {
        code = "haunt_runtime_projection_failed",
        message = runtime_r.err,
        data_dir = data.new_data_dir,
      })
    end
  end

  local result_value = {
    workspace_id = workspace.workspace_id,
    old_name = data.old_name,
    new_name = data.new_name,
    changed = true,
  }
  if #warnings > 0 then
    result_value.warnings = warnings
  end

  return result.ok(result_value)
end

function M.haunt_delete(workspace_id, name, opts)
  opts = opts or {}

  if not name or name == "" then
    return result.err("Haunt context name is required", "invalid_input")
  end

  local name_r = validation.validate_context_name(name)
  if not name_r.ok then
    return name_r
  end
  name = name_r.value

  local target_r = contexts:get(workspace_id, name)
  if not target_r.ok then
    return target_r
  end

  local workspace = target_r.value.workspace
  local target_data_dir = target_r.value.entry.data_dir
  local is_active = target_r.value.active == name

  local context_count = 0
  for _ in pairs(contexts:get_entries(workspace)) do
    context_count = context_count + 1
  end
  if context_count <= 1 then
    return result.err("Cannot delete the last Haunt context for a Workspace", "conflict", {
      workspace_id = workspace.workspace_id,
      context = name,
    })
  end

  if is_active and not opts.switch_to then
    return result.err("Cannot delete active Haunt context without switch_to", "invalid_input", {
      workspace_id = workspace.workspace_id,
      context = name,
    })
  end

  local info_r = haunt_adapter.context_dir_info(target_data_dir)
  local non_empty = false
  if info_r.ok then
    non_empty = info_r.value.non_empty
  end

  if non_empty and opts.confirm ~= true and opts.keep_data ~= true then
    return result.err("Haunt context directory is non-empty", "conflict", {
      workspace_id = workspace.workspace_id,
      context = name,
      requires_confirmation = true,
    })
  end

  if is_active and opts.switch_to then
    local switch_r = validation.validate_context_name(opts.switch_to)
    if not switch_r.ok then
      return switch_r
    end
    opts.switch_to = switch_r.value
  end

  -- Pre-fetch switch_to data_dir before delete removes it from the workspace.
  local switch_to_data_dir = nil
  local should_runtime_switch = is_active and opts.switch_to
    and validation.is_active_workspace(workspace.workspace_id, current_workspace_id())
    and opts.activate ~= false
  if should_runtime_switch then
    local entries = contexts:get_entries(workspace)
    local switch_to_context = entries[opts.switch_to]
    if not switch_to_context then
      return result.err("switch_to context not found: " .. opts.switch_to, "not_found", {
        workspace_id = workspace.workspace_id,
        context = opts.switch_to,
      })
    end
    switch_to_data_dir = switch_to_context.data_dir
  end

  -- Graph commit first.
  local delete_r = contexts:delete(workspace.workspace_id, name, {
    switch_to = opts.switch_to,
    allow_delete_main = true,
  })
  if not delete_r.ok then
    return delete_r
  end

  local commit_r = contexts:commit(delete_r.value)
  if not commit_r.ok then
    return commit_r
  end

  -- Projection: switch runtime after graph commit.
  local warnings = {}
  if should_runtime_switch and switch_to_data_dir then
    local runtime_r = maybe_change_runtime_data_dir(workspace.workspace_id, switch_to_data_dir, opts)
    if not runtime_r.ok then
      table.insert(warnings, {
        code = "haunt_runtime_projection_failed",
        message = runtime_r.err,
        data_dir = switch_to_data_dir,
      })
    end
  end

  -- Projection: cleanup directory (soft failure).
  if opts.keep_data ~= true then
    local delete_dir_r = haunt_adapter.delete_context_dir(target_data_dir, { confirm = true })
    if not delete_dir_r.ok then
      table.insert(warnings, {
        code = delete_dir_r.code,
        err = delete_dir_r.err,
        data_dir = target_data_dir,
      })
    end
  end

  local result_value = {
    workspace_id = workspace.workspace_id,
    name = name,
    changed = true,
  }
  if #warnings > 0 then
    result_value.warnings = warnings
  end

  return result.ok(result_value)
end

return M
