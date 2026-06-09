local result = require("loci.result")

local M = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function input_text(opts, callback)
  if type(opts.default) == "string" and opts.default ~= "" and opts.use_default == true then
    callback(result.ok(opts.default))
    return
  end
  vim.ui.input({ prompt = opts.prompt, default = opts.default }, function(value)
    if value == nil then
      callback(result.err("input cancelled", "invalid_input"))
      return
    end
    callback(result.ok(value))
  end)
end

local function select_items(items, opts, callback)
  vim.ui.select(items, {
    prompt = opts.prompt or "Select:",
    format_item = opts.format_item,
  }, function(choice)
    if not choice then
      callback(result.err("selection cancelled", "invalid_input"))
      return
    end
    callback(result.ok(choice))
  end)
end

-- ============================================================================
-- Public API
-- ============================================================================

---Project new form.
---@param opts table {title=nil, status=nil, tags=nil}
---@param callback function(result)
function M.project_new(opts, callback)
  opts = opts or {}
  if type(opts.title) == "string" and opts.title:gsub("%s+", "") ~= "" then
    callback(result.ok(opts))
    return
  end
  input_text({ prompt = "Project title: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.title = res.value
    callback(result.ok(opts))
  end)
end

---Workspace new form.
---@param opts table {name=nil, project_id=nil, label=nil, branch=nil, worktree_path=nil}
---@param callback function(result)
function M.workspace_new(opts, callback)
  opts = opts or {}

  if type(opts.name) == "string" and opts.name ~= "" then
    -- Name is provided, return immediately
    callback(result.ok(opts))
    return
  end

  -- Prompt for name
  input_text({ prompt = "Workspace name: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.name = res.value
    callback(result.ok(opts))
  end)
end

---Workspace clone form.
---@param opts table {workspace_id=nil, name=nil, project_id=nil, branch=nil, worktree_path=nil}
---@param callback function(result)
function M.workspace_clone(opts, callback)
  opts = opts or {}

  -- If source name is available, use it to default the clone name
  local clone_name_default = nil
  if opts.source_name then
    clone_name_default = opts.source_name .. " copy"
  end

  if type(opts.name) == "string" and opts.name ~= "" then
    callback(result.ok(opts))
    return
  end

  input_text({
    prompt = "Clone name: ",
    default = clone_name_default,
  }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.name = res.value
    callback(result.ok(opts))
  end)
end

---Workspace archive form.
---@param opts table {workspace_id=nil, reason=nil}
---@param callback function(result)
function M.workspace_archive(opts, callback)
  opts = opts or {}

  -- Optionally prompt for reason
  input_text({
    prompt = "Archive reason (optional): ",
    default = "",
  }, function(res)
    if res.ok and res.value ~= "" then
      opts.reason = res.value
    end
    callback(result.ok(opts))
  end)
end

---Add knowledge form (selection).
---@param opts table {workspace_id=nil}
---@param callback function(result)
function M.workspace_add_knowledge(opts, callback)
  opts = opts or {}
  -- Actual selection is done by picker, this is just placeholder
  callback(result.ok(opts))
end

---Remove knowledge form (selection via picker).
---@param opts table {workspace_id=nil}
---@param callback function(result)
function M.workspace_remove_knowledge(opts, callback)
  opts = opts or {}
  -- Actual selection is done by picker
  callback(result.ok(opts))
end

---Set primary knowledge form (selection via picker).
---@param opts table {workspace_id=nil}
---@param callback function(result)
function M.workspace_set_primary(opts, callback)
  opts = opts or {}
  -- Actual selection is done by picker
  callback(result.ok(opts))
end

---Linked file form (role selection).
---@param opts table {workspace_id=nil, path=nil, role=nil}
---@param callback function(result)
function M.linked_file(opts, callback)
  opts = opts or {}

  if type(opts.role) == "string" and opts.role ~= "" then
    callback(result.ok(opts))
    return
  end

  local roles = { "implementation", "reference", "related", "documentation", "test" }
  select_items(roles, {
    prompt = "File role: ",
    format_item = function(item)
      return item
    end,
  }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.role = res.value
    callback(result.ok(opts))
  end)
end

---Haunt context new form.
---@param opts table {workspace_id=nil, name=nil}
---@param callback function(result)
function M.haunt_context_new(opts, callback)
  opts = opts or {}

  if type(opts.name) == "string" and opts.name ~= "" then
    callback(result.ok(opts))
    return
  end

  input_text({ prompt = "Context name: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.name = res.value
    callback(result.ok(opts))
  end)
end

---Haunt context rename form.
---@param opts table {workspace_id=nil, old_name=nil, new_name=nil}
---@param callback function(result)
function M.haunt_context_rename(opts, callback)
  opts = opts or {}

  if type(opts.new_name) == "string" and opts.new_name ~= "" then
    callback(result.ok(opts))
    return
  end

  input_text({ prompt = "New context name: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.new_name = res.value
    callback(result.ok(opts))
  end)
end

---Haunt context delete form.
---@param opts table {workspace_id=nil, name=nil, confirm=nil}
---@param callback function(result)
function M.haunt_context_delete(opts, callback)
  opts = opts or {}
  select_items({ "Delete", "Cancel" }, {
    prompt = opts.prompt or ("Delete persisted Haunt data in context '" .. tostring(opts.name or "") .. "'?"),
    format_item = function(item)
      return item
    end,
  }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    callback(result.ok(res.value == "Delete"))
  end)
end

---Trail new form.
---@param opts table {workspace_id=nil, logical_name=nil}
---@param callback function(result)
function M.trail_new(opts, callback)
  opts = opts or {}

  if type(opts.logical_name) == "string" and opts.logical_name ~= "" then
    callback(result.ok(opts))
    return
  end

  input_text({ prompt = "Trail name: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.logical_name = res.value
    callback(result.ok(opts))
  end)
end

---Trail picker form.
---@param opts table {choices=nil, prompt=nil}
---@param callback function(result)
function M.trail_select(opts, callback)
  opts = opts or {}
  local choices = opts.choices or {}
  select_items(choices, {
    prompt = opts.prompt or "Select Trail:",
    format_item = function(item)
      return item
    end,
  }, callback)
end

---Trail rename form.
---@param opts table {workspace_id=nil, old_name=nil, new_name=nil}
---@param callback function(result)
function M.trail_rename(opts, callback)
  opts = opts or {}

  if type(opts.new_name) == "string" and opts.new_name ~= "" then
    callback(result.ok(opts))
    return
  end

  input_text({ prompt = "New trail name: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.new_name = res.value
    callback(result.ok(opts))
  end)
end

---Note new form.
---@param opts table {title=nil, type=nil, dir=nil, tags=nil, projects=nil}
---@param callback function(result)
function M.note_new(opts, callback)
  opts = opts or {}

  if type(opts.title) == "string" and opts.title ~= "" then
    callback(result.ok(opts))
    return
  end

  input_text({ prompt = "Note title: " }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.title = res.value
    opts.type = opts.type or "note"
    opts.dir = opts.dir or "notes"
    opts.tags = opts.tags or {}
    opts.projects = opts.projects or {}
    callback(result.ok(opts))
  end)
end

---Daily note form.
---@param opts table {date=nil}
---@param callback function(result)
function M.daily_note(opts, callback)
  opts = opts or {}

  -- Default to today's date
  local default_date = os.date("%Y-%m-%d")

  if type(opts.date) == "string" and opts.date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    callback(result.ok(opts))
    return
  end

  input_text({
    prompt = "Date (YYYY-MM-DD): ",
    default = default_date,
  }, function(res)
    if not res.ok then
      callback(res)
      return
    end

    -- Validate date format
    if not res.value:match("^%d%d%d%d%-%d%d%-%d%d$") then
      callback(result.err("Invalid date format (use YYYY-MM-DD)", "invalid_input"))
      return
    end

    opts.date = res.value
    callback(result.ok(opts))
  end)
end

---Scratch note form.
---@param opts table {title=nil, type=nil}
---@param callback function(result)
function M.scratch_note(opts, callback)
  opts = opts or {}

  if type(opts.title) == "string" and opts.title ~= "" then
    callback(result.ok(opts))
    return
  end

  -- Default scratch note title
  local default_title = "Scratch " .. os.date("%Y-%m-%d %H:%M")

  input_text({
    prompt = "Scratch note title: ",
    default = default_title,
  }, function(res)
    if not res.ok then
      callback(res)
      return
    end
    opts.title = res.value
    opts.type = "scratch"
    callback(result.ok(opts))
  end)
end

-- ============================================================================
-- Test seams
-- ============================================================================

function M._input(prompt_opts, callback)
  input_text(prompt_opts, callback)
end

function M._select(entries, opts, callback)
  select_items(entries, opts, callback)
end

return M
