local result = require("loci.result")
local graph = require("loci.store.graph")
local tx = require("loci.service.workspace.tx")
local validation = require("loci.service.workspace.validation")
local wayfinder = require("loci.integrations.wayfinder")
local resolve = require("loci.service.workspace.resolve")
local registry = require("loci.service.workspace.registry")

local M = {}

local function generated_trail_name(workspace_id, logical_name)
  return "loci-" .. workspace_id .. "-" .. logical_name
end

local trails = registry.new({
  section = "wayfinder",
  entries_key = "trails",
  active_key = "active",
  item_label = "Trail",
  default_name = "main",
  validate_name = validation.validate_logical_name,
  allow_delete_default = false,
  allow_delete_last = false,
  make_entry = function(workspace, logical_name)
    return result.ok({
      trail_name = generated_trail_name(workspace.workspace_id, logical_name),
    })
  end,
  sort_names = function(names)
    table.sort(names)
    for i, name in ipairs(names) do
      if name == "main" then
        table.remove(names, i)
        table.insert(names, 1, "main")
        break
      end
    end
    return names
  end,
})

local function integration_summary(r)
  return {
    ok = r.ok,
    action = r.ok and r.value.action or nil,
    mode = r.ok and r.value.mode or nil,
    command = r.ok and r.value.command or nil,
    named = r.ok and r.value.named or false,
    user_action_required = r.ok and r.value.user_action_required or false,
    err = (not r.ok) and r.err or nil,
    code = (not r.ok) and r.code or nil,
  }
end

function M.list_trails(workspace_id, opts)
  opts = opts or {}

  local list_r = trails:list(workspace_id)
  if not list_r.ok then
    return list_r
  end

  local output = {}
  for _, item in ipairs(list_r.value.items) do
    output[#output + 1] = {
      logical_name = item.name,
      trail_name = item.entry.trail_name,
      active = item.active,
    }
  end

  return result.ok({
    workspace_id = list_r.value.workspace_id,
    active = list_r.value.active,
    trails = output,
  })
end

function M.create_trail(workspace_id, logical_name)
  local create_r = trails:create(workspace_id, logical_name, { switch = false })
  if not create_r.ok then
    return create_r
  end

  local write_r = tx.write(create_r.value.workspace)
  if not write_r.ok then
    return write_r
  end

  local value = create_r.value
  local result_value = {
    workspace_id = value.workspace.workspace_id,
    logical_name = value.name,
    trail_name = value.entry.trail_name,
    active = value.active,
    changed = true,
  }

  return result.ok(result_value)
end

function M.switch_trail(workspace_id, logical_name)
  local switch_r = trails:switch(workspace_id, logical_name)
  if not switch_r.ok then
    return switch_r
  end

  local value = switch_r.value
  local write_r = tx.write(value.workspace)
  if not write_r.ok then
    return write_r
  end

  local result_value = {
    workspace_id = value.workspace.workspace_id,
    logical_name = value.name,
    trail_name = value.entry.trail_name,
    active = value.active,
    changed = value.changed,
  }

  local load_r = wayfinder.load_named(value.entry.trail_name)
  result_value.integration = integration_summary(load_r)
  if not load_r.ok then
    result_value.warnings = { load_r.err }
  end

  return result.ok(result_value)
end

function M.save_active_trail(workspace_id)
  local ws_r = trails:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local wf = workspace.wayfinder
  local target_logical = wf.active or "main"

  local trail_name = wf.trails[target_logical] and wf.trails[target_logical].trail_name
  if not trail_name then
    return result.err("Trail name not found", "invalid_input", {
      workspace_id = workspace.workspace_id,
      logical_name = target_logical,
    })
  end

  local save_r = wayfinder.save_active(trail_name)

  local result_value = {
    workspace_id = workspace.workspace_id,
    logical_name = target_logical,
    trail_name = trail_name,
    active = wf.active,
    changed = false,
    integration = integration_summary(save_r),
  }

  if not save_r.ok then
    result_value.warnings = { save_r.err }
  end

  return result.ok(result_value)
end

function M.load_trail(workspace_id, logical_name)
  local ws_r = trails:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local wf = workspace.wayfinder
  local target_logical = logical_name or (wf.active or "main")

  if not wf.trails[target_logical] then
    return result.err("Trail not found", "not_found", {
      workspace_id = workspace.workspace_id,
      logical_name = target_logical,
    })
  end

  wf.active = target_logical
  local write_r = tx.write(workspace)
  if not write_r.ok then
    return write_r
  end

  local trail_name = wf.trails[target_logical].trail_name
  local load_r = wayfinder.load_named(trail_name)

  local result_value = {
    workspace_id = workspace.workspace_id,
    logical_name = target_logical,
    trail_name = trail_name,
    active = wf.active,
    changed = true,
    integration = integration_summary(load_r),
  }

  if not load_r.ok then
    result_value.warnings = { load_r.err }
  end

  return result.ok(result_value)
end

function M.rename_trail(workspace_id, old_logical_name, new_logical_name, opts)
  opts = opts or {}

  local old_r = trails:get(workspace_id, old_logical_name)
  if not old_r.ok then
    return old_r
  end

  local new_validate_r = validation.validate_logical_name(new_logical_name)
  if not new_validate_r.ok then
    return new_validate_r
  end
  new_logical_name = new_validate_r.value

  local workspace = old_r.value.workspace
  local old_trail_name = old_r.value.entry.trail_name
  local new_trail_name = generated_trail_name(workspace.workspace_id, new_logical_name)

  local entries = trails:get_entries(workspace)
  if entries[new_logical_name] then
    return result.err("Trail name already exists", "conflict", {
      workspace_id = workspace.workspace_id,
      logical_name = new_logical_name,
    })
  end

  -- Graph commit first, then project Wayfinder rename.
  local rename_r = trails:rename(workspace.workspace_id, old_logical_name, new_logical_name)
  if not rename_r.ok then
    return rename_r
  end

  local write_r = tx.write(rename_r.value.workspace)
  if not write_r.ok then
    return write_r
  end

  local result_value = {
    workspace_id = workspace.workspace_id,
    old_logical_name = old_logical_name,
    new_logical_name = new_logical_name,
    old_trail_name = old_trail_name,
    new_trail_name = rename_r.value.new_entry.trail_name,
    changed = true,
  }

  -- Wayfinder projection: soft failure after graph commit.
  local rename_wf_r = wayfinder.rename(old_trail_name, new_trail_name)
  if not rename_wf_r.ok then
    result_value.integration = { ok = false, err = rename_wf_r.err, code = rename_wf_r.code }
    result_value.warnings = {
      {
        code = "wayfinder_projection_failed",
        message = rename_wf_r.err,
        old_trail_name = old_trail_name,
        new_trail_name = new_trail_name,
      },
    }
  else
    result_value.integration = { ok = true, action = "rename", mode = "direct_api", named = true }
  end

  return result.ok(result_value)
end

function M.delete_trail(workspace_id, logical_name, opts)
  opts = opts or {}

  local target_r = trails:get(workspace_id, logical_name)
  if not target_r.ok then
    return target_r
  end

  local workspace = target_r.value.workspace
  local trail_name = target_r.value.entry.trail_name
  local wf = workspace.wayfinder

  -- Pre-validate the operation before touching Wayfinder.
  if logical_name == (trails.default_name or "main") and not opts.allow_delete_main then
    return result.err("Cannot delete main Trail", "conflict", {
      workspace_id = workspace.workspace_id,
      logical_name = logical_name,
    })
  end

  local entry_count = 0
  for _ in pairs(wf.trails or {}) do
    entry_count = entry_count + 1
  end
  if entry_count <= 1 then
    return result.err("Cannot delete last Trail", "conflict", {
      workspace_id = workspace.workspace_id,
      logical_name = logical_name,
    })
  end

  if wf.active == logical_name and not opts.switch_to then
    return result.err("Cannot delete active Trail without switch_to", "conflict", {
      workspace_id = workspace.workspace_id,
      logical_name = logical_name,
    })
  end

  -- Graph commit first, then project Wayfinder delete.
  local delete_r = trails:delete(workspace.workspace_id, logical_name, {
    switch_to = opts.switch_to,
    allow_delete_main = opts.allow_delete_main,
  })
  if not delete_r.ok then
    return delete_r
  end

  local write_r = tx.write(delete_r.value.workspace)
  if not write_r.ok then
    return write_r
  end

  local result_value = {
    workspace_id = workspace.workspace_id,
    logical_name = logical_name,
    trail_name = trail_name,
    changed = true,
    registry_deleted = true,
  }

  -- Wayfinder projection: soft failure after graph commit.
  -- Extra Wayfinder data is safer than graph pointing at a missing Trail.
  local delete_wf_r = wayfinder.delete_named(trail_name)
  if not delete_wf_r.ok then
    result_value.integration = { ok = false, err = delete_wf_r.err, code = delete_wf_r.code }
    result_value.warnings = {
      {
        code = "stale_integration_artifact",
        message = delete_wf_r.err,
        trail_name = trail_name,
      },
    }
  else
    result_value.integration = { ok = true, action = "delete", mode = "direct_api", named = true }
  end

  return result.ok(result_value)
end

function M.show_trail(workspace_id, opts)
  opts = opts or {}

  local ws_id_r = resolve.resolve_workspace_id(workspace_id)
  local workspace_id_for_result = nil

  if ws_id_r.ok then
    local ws_r = tx.read(ws_id_r.value)
    if ws_r.ok then
      workspace_id_for_result = ws_r.value.workspace_id
      trails:ensure(ws_r.value)
    end
  end

  local show_r = wayfinder.show(opts)

  return result.ok({
    workspace_id = workspace_id_for_result,
    integration = {
      ok = show_r.ok,
      action = show_r.ok and show_r.value.action or nil,
      mode = show_r.ok and show_r.value.mode or nil,
      command = show_r.ok and show_r.value.command or nil,
    },
  })
end

function M.export_trail_quickfix(workspace_id, opts)
  opts = opts or {}

  local ws_id_r = resolve.resolve_workspace_id(workspace_id)
  local workspace_id_for_result = nil

  if ws_id_r.ok then
    local ws_r = tx.read(ws_id_r.value)
    if ws_r.ok then
      workspace_id_for_result = ws_r.value.workspace_id
      trails:ensure(ws_r.value)
    end
  end

  local export_r = wayfinder.export_quickfix(opts)

  return result.ok({
    workspace_id = workspace_id_for_result,
    integration = {
      ok = export_r.ok,
      action = export_r.ok and export_r.value.action or nil,
      mode = export_r.ok and export_r.value.mode or nil,
      command = export_r.ok and export_r.value.command or nil,
    },
  })
end

return M
