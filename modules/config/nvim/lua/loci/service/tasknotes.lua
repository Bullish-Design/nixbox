--- TaskNotes integration service
--- Thin delegation layer to tasknotes.nvim plugin
local result = require("loci.result")

local M = {}

--- Check if tasknotes.nvim is available
--- @return boolean
function M.available()
  local ok = pcall(require, "tasknotes")
  return ok
end

--- Helper: require tasknotes or return error result
--- @return table|nil tasknotes module, or nil
--- @return table|nil error result, or nil
local function require_tasknotes()
  local ok, tn = pcall(require, "tasknotes")
  if not ok then
    return nil, result.err("tasknotes.nvim not available", "integration_unavailable")
  end
  return tn, nil
end

--- Browse tasks with optional filter
--- @param opts? { filter?: table }
--- @return table result
function M.browse(opts)
  local tn, err = require_tasknotes()
  if not tn then
    return err
  end
  tn.browse_tasks(opts and opts.filter)
  return result.ok(true)
end

--- Create a new task via form
--- @return table result
function M.new()
  local tn, err = require_tasknotes()
  if not tn then
    return err
  end
  tn.new_task()
  return result.ok(true)
end

--- Edit the current buffer's task via form
--- @return table result
function M.edit()
  local tn, err = require_tasknotes()
  if not tn then
    return err
  end
  tn.edit_task()
  return result.ok(true)
end

--- Rescan the task vault
--- @return table result
function M.rescan()
  local tn, err = require_tasknotes()
  if not tn then
    return err
  end
  tn.rescan()
  return result.ok(true)
end

--- Browse tasks by view
--- @param view_id? string specific view to open
--- @param opts? table
--- @return table result
function M.view(view_id, opts)
  local tn, err = require_tasknotes()
  if not tn then
    return err
  end
  if view_id and view_id ~= "" then
    tn.browse_by_view(view_id)
  else
    tn.show_view_selector()
  end
  return result.ok(true)
end

return M
