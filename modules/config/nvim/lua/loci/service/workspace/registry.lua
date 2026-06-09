local result = require("loci.result")
local tx = require("loci.service.workspace.tx")

local Registry = {}
Registry.__index = Registry

local function is_nilish(value)
  return value == nil or value == vim.NIL
end

local function count_entries(entries)
  local n = 0
  for _ in pairs(entries or {}) do
    n = n + 1
  end
  return n
end

local function sorted_names(entries)
  local names = {}
  for name in pairs(entries or {}) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local M = {}

function M.new(spec)
  assert(type(spec) == "table", "registry spec is required")
  assert(type(spec.section) == "string" and spec.section ~= "", "registry.section is required")
  assert(type(spec.entries_key) == "string" and spec.entries_key ~= "", "registry.entries_key is required")
  assert(type(spec.item_label) == "string" and spec.item_label ~= "", "registry.item_label is required")
  assert(type(spec.default_name) == "string" and spec.default_name ~= "", "registry.default_name is required")
  assert(type(spec.validate_name) == "function", "registry.validate_name is required")
  assert(type(spec.make_entry) == "function", "registry.make_entry is required")

  return setmetatable({
    section = spec.section,
    entries_key = spec.entries_key,
    active_key = spec.active_key or "active",
    item_label = spec.item_label,
    default_name = spec.default_name,
    validate_name = spec.validate_name,
    make_entry = spec.make_entry,
    sort_names = spec.sort_names,
    allow_delete_default = spec.allow_delete_default or false,
    allow_delete_last = spec.allow_delete_last or false,
  }, Registry)
end

function Registry:ensure(workspace)
  workspace[self.section] = workspace[self.section] or {}
  local sec = workspace[self.section]
  sec[self.entries_key] = sec[self.entries_key] or {}
  local entries = sec[self.entries_key]

  if is_nilish(sec[self.active_key]) or sec[self.active_key] == "" then
    sec[self.active_key] = self.default_name
  end

  local active = sec[self.active_key]
  if not entries[active] then
    local entry_r = self.make_entry(workspace, active)
    if not entry_r.ok then
      return entry_r
    end
    entries[active] = entry_r.value
  end

  if not entries[self.default_name] then
    local entry_r = self.make_entry(workspace, self.default_name)
    if not entry_r.ok then
      return entry_r
    end
    entries[self.default_name] = entry_r.value
  end

  return result.ok(sec)
end

function Registry:get_entries(workspace)
  return workspace[self.section][self.entries_key]
end

function Registry:get_active(workspace)
  return workspace[self.section][self.active_key]
end

function Registry:read_workspace(workspace_id)
  local read_r = tx.resolve_and_read(workspace_id)
  if not read_r.ok then
    return read_r
  end
  local workspace = read_r.value.workspace
  local ensure_r = self:ensure(workspace)
  if not ensure_r.ok then
    return ensure_r
  end
  return result.ok(workspace)
end

function Registry:prepare(workspace_id, fn)
  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end
  local workspace = vim.deepcopy(ws_r.value)
  local prepared_r = fn(workspace)
  if not prepared_r.ok then
    return prepared_r
  end
  return result.ok({ workspace = workspace, prepared = prepared_r.value })
end

function Registry:commit(prepared)
  return tx.write(prepared.workspace)
end


function Registry:list(workspace_id)
  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local entries = self:get_entries(workspace)
  local active = self:get_active(workspace)

  local names = sorted_names(entries)
  if self.sort_names then
    names = self.sort_names(names) or names
  end

  local items = {}
  for _, name in ipairs(names) do
    items[#items + 1] = {
      name = name,
      active = name == active,
      entry = entries[name],
    }
  end

  return result.ok({
    workspace = workspace,
    workspace_id = workspace.workspace_id,
    active = active,
    items = items,
  })
end

function Registry:get(workspace_id, name)
  local name_r = self.validate_name(name)
  if not name_r.ok then
    return name_r
  end
  name = name_r.value

  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local entries = self:get_entries(workspace)
  local entry = entries[name]

  if not entry then
    return result.err(self.item_label .. " not found: " .. name, "not_found", {
      workspace_id = workspace.workspace_id,
    })
  end

  return result.ok({
    workspace = workspace,
    name = name,
    entry = entry,
    active = self:get_active(workspace),
  })
end

function Registry:create(workspace_id, name, opts)
  opts = opts or {}

  local name_r = self.validate_name(name)
  if not name_r.ok then
    return name_r
  end
  name = name_r.value

  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local sec = workspace[self.section]
  local entries = sec[self.entries_key]

  if entries[name] then
    return result.err(self.item_label .. " already exists: " .. name, "conflict", {
      workspace_id = workspace.workspace_id,
    })
  end

  local entry_r = self.make_entry(workspace, name)
  if not entry_r.ok then
    return entry_r
  end

  entries[name] = entry_r.value

  if opts.switch == true then
    sec[self.active_key] = name
  end

  return result.ok({
    workspace = workspace,
    name = name,
    entry = entry_r.value,
    active = sec[self.active_key],
    changed = true,
  })
end

function Registry:switch(workspace_id, name)
  local name_r = self.validate_name(name)
  if not name_r.ok then
    return name_r
  end
  name = name_r.value

  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local sec = workspace[self.section]
  local entries = sec[self.entries_key]
  local entry = entries[name]

  if not entry then
    return result.err(self.item_label .. " not found: " .. name, "not_found", {
      workspace_id = workspace.workspace_id,
    })
  end

  local changed = sec[self.active_key] ~= name
  sec[self.active_key] = name

  return result.ok({
    workspace = workspace,
    name = name,
    entry = entry,
    active = name,
    changed = changed,
  })
end

function Registry:rename(workspace_id, old_name, new_name)
  local old_r = self.validate_name(old_name)
  if not old_r.ok then
    return old_r
  end
  old_name = old_r.value

  local new_r = self.validate_name(new_name)
  if not new_r.ok then
    return new_r
  end
  new_name = new_r.value

  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local sec = workspace[self.section]
  local entries = sec[self.entries_key]

  if not entries[old_name] then
    return result.err(self.item_label .. " not found: " .. old_name, "not_found", {
      workspace_id = workspace.workspace_id,
    })
  end

  if entries[new_name] then
    return result.err(self.item_label .. " already exists: " .. new_name, "conflict", {
      workspace_id = workspace.workspace_id,
    })
  end

  local old_entry = entries[old_name]
  local new_entry_r = self.make_entry(workspace, new_name)
  if not new_entry_r.ok then
    return new_entry_r
  end
  local new_entry = new_entry_r.value

  entries[new_name] = new_entry
  entries[old_name] = nil

  if sec[self.active_key] == old_name then
    sec[self.active_key] = new_name
  end

  return result.ok({
    workspace = workspace,
    old_name = old_name,
    new_name = new_name,
    old_entry = old_entry,
    new_entry = new_entry,
    active = sec[self.active_key],
    changed = true,
  })
end

function Registry:delete(workspace_id, name, opts)
  opts = opts or {}

  local name_r = self.validate_name(name)
  if not name_r.ok then
    return name_r
  end
  name = name_r.value

  local ws_r = self:read_workspace(workspace_id)
  if not ws_r.ok then
    return ws_r
  end

  local workspace = ws_r.value
  local sec = workspace[self.section]
  local entries = sec[self.entries_key]
  local entry = entries[name]

  if not entry then
    return result.err(self.item_label .. " not found: " .. name, "not_found", {
      workspace_id = workspace.workspace_id,
    })
  end

  if name == self.default_name and not self.allow_delete_default and opts.allow_delete_main ~= true then
    return result.err("Cannot delete " .. self.default_name .. " " .. self.item_label, "conflict", {
      workspace_id = workspace.workspace_id,
    })
  end

  if count_entries(entries) <= 1 and not self.allow_delete_last then
    return result.err("Cannot delete last " .. self.item_label, "conflict", {
      workspace_id = workspace.workspace_id,
    })
  end

  local is_active = sec[self.active_key] == name
  if is_active and not opts.switch_to then
    return result.err("Cannot delete active " .. self.item_label .. " without switch_to", "conflict", {
      workspace_id = workspace.workspace_id,
    })
  end

  if opts.switch_to then
    if opts.switch_to == name then
      return result.err("switch_to cannot be the " .. self.item_label .. " being deleted", "invalid_input", {
        workspace_id = workspace.workspace_id,
      })
    end
    if not entries[opts.switch_to] then
      return result.err("switch_to " .. self.item_label .. " not found: " .. opts.switch_to, "not_found", {
        workspace_id = workspace.workspace_id,
      })
    end
  end

  entries[name] = nil

  if is_active and opts.switch_to then
    sec[self.active_key] = opts.switch_to
  end

  return result.ok({
    workspace = workspace,
    name = name,
    entry = entry,
    active = sec[self.active_key],
    changed = true,
  })
end

return M
