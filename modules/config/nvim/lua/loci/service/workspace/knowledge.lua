local result = require("loci.result")
local markdown = require("loci.store.markdown")
local tx = require("loci.service.workspace.tx")
local workspace_domain = require("loci.domain.workspace")

local M = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function resolve_content_path(content_path_or_buf)
  if type(content_path_or_buf) ~= "string" or content_path_or_buf == "" then
    return nil, "content_path is required"
  end
  -- Assume it's a content path - convert to absolute
  local abs_r = markdown.abs_path_for_content(content_path_or_buf)
  if not abs_r.ok then
    return nil, abs_r.err
  end
  return abs_r.value
end

-- ============================================================================
-- Public API: knowledge operations
-- ============================================================================

---@async
---@param workspace_id string
---@param content_path_or_buf string|number
---@param opts? table
---@return loci.Result<table>
function M.add_knowledge(workspace_id, content_path_or_buf, opts)
  opts = opts or {}

  local ws_read_r = tx.resolve_and_read(workspace_id, { op = "knowledge.add" })
  if not ws_read_r.ok then
    return ws_read_r
  end
  local resolved_workspace_id = ws_read_r.value.workspace_id

  -- Resolve content path to absolute (input preparation, before transaction)
  local abs_path, resolve_err = resolve_content_path(content_path_or_buf)
  if not abs_path then
    return result.err(resolve_err or "could not resolve content path", "invalid_input")
  end

  -- Verify it's under .loci/content/
  local is_under_r = markdown.is_under_content(abs_path)
  if not is_under_r.ok then
    return is_under_r
  end
  if not is_under_r.value then
    return result.err("markdown must be under .loci/content/", "outside_content")
  end

  -- Ensure loci_id exists
  local ensure_r = markdown.ensure_loci_id(abs_path, opts)
  if not ensure_r.ok then
    return ensure_r
  end

  local markdown_obj = ensure_r.value

  local update_r = tx.update(resolved_workspace_id, function(workspace)
    -- Check if already present
    local existing_idx = nil
    for i, obj in ipairs(workspace.knowledge.objects) do
      if obj.loci_id == markdown_obj.loci_id then
        existing_idx = i
        break
      end
    end

    if existing_idx then
      -- Update existing entry
      local entry = workspace.knowledge.objects[existing_idx]
      entry.type = markdown_obj.type or "note"
      entry.title_cache = markdown_obj.title
      entry.content_path = markdown_obj.content_path
      if opts.role then
        entry.role = opts.role
      end
    else
      -- Add new entry
      local entry = workspace_domain.knowledge_entry(markdown_obj, opts.role)
      table.insert(workspace.knowledge.objects, entry)
    end

    -- Set primary if requested
    if opts.primary then
      workspace.knowledge.primary_loci_id = markdown_obj.loci_id
    end

    return result.ok(workspace)
  end)
  if not update_r.ok then
    return result.err(update_r.err, update_r.code, {
      partial = "markdown_updated_workspace_not_updated",
      loci_id = markdown_obj.loci_id,
      content_path = markdown_obj.content_path,
    })
  end
  return result.ok(update_r.value.workspace)
end

---@async
---@param workspace_id string
---@param loci_id string
---@param opts? table
---@return loci.Result<table>
function M.remove_knowledge(workspace_id, loci_id, opts)
  opts = opts or {}

  local update_r = tx.update(workspace_id, function(workspace)
    -- Find and remove the object
    local found_idx = nil
    for i, obj in ipairs(workspace.knowledge.objects) do
      if obj.loci_id == loci_id then
        found_idx = i
        break
      end
    end

    if not found_idx then
      return result.err("knowledge object not found: " .. loci_id, "not_found")
    end

    table.remove(workspace.knowledge.objects, found_idx)

    -- Handle primary_loci_id
    if workspace.knowledge.primary_loci_id == loci_id then
      if opts.promote_next and #workspace.knowledge.objects > 0 then
        workspace.knowledge.primary_loci_id = workspace.knowledge.objects[1].loci_id
      else
        workspace.knowledge.primary_loci_id = vim.NIL
      end
    end

    return result.ok(workspace)
  end)
  if not update_r.ok then
    return update_r
  end
  return result.ok(update_r.value.workspace)
end

---@async
---@param workspace_id string
---@param loci_id string
---@return loci.Result<table>
function M.set_primary(workspace_id, loci_id)
  local update_r = tx.update(workspace_id, function(workspace)
    -- Check that loci_id exists in knowledge.objects
    local found_idx = nil
    for i, obj in ipairs(workspace.knowledge.objects) do
      if obj.loci_id == loci_id then
        found_idx = i
        break
      end
    end

    if not found_idx then
      return result.err("knowledge object not found: " .. loci_id, "invalid_input")
    end

    -- Set primary_loci_id
    workspace.knowledge.primary_loci_id = loci_id

    -- Set role to "primary" if not already set
    if not workspace.knowledge.objects[found_idx].role or workspace.knowledge.objects[found_idx].role == "supporting" then
      workspace.knowledge.objects[found_idx].role = "primary"
    end

    return result.ok(workspace)
  end)
  if not update_r.ok then
    return update_r
  end
  return result.ok(update_r.value.workspace)
end

return M
