local result = require("loci.result")
local id = require("loci.domain.id")
local graph = require("loci.store.graph")
local workspace_domain = require("loci.domain.workspace")
local haunt_adapter = require("loci.integrations.haunt")
local tx = require("loci.service.workspace.tx")

local M = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function now(opts)
  if opts and type(opts.clock) == "function" then
    return opts.clock()
  end
  if opts and type(opts.now) == "string" and opts.now ~= "" then
    return opts.now
  end
  return id.now_iso()
end

local function abs_loci_relative_data_dir(data_dir)
  if type(data_dir) ~= "string" or data_dir == "" then
    return result.err("invalid haunt data_dir", "invalid_input", { data_dir = data_dir })
  end
  if data_dir:sub(1, 1) == "/" then
    return result.err("haunt data_dir must be .loci-relative", "invalid_input", { data_dir = data_dir })
  end
  if data_dir:match("%.%.") then
    return result.err("path traversal in haunt data_dir", "invalid_input", { data_dir = data_dir })
  end
  local expected = "^%.loci/integrations/haunt/workspaces/"
  if not data_dir:match(expected) then
    return result.err("haunt data_dir must be under .loci/integrations/haunt/workspaces/", "invalid_input", { data_dir = data_dir })
  end
  return result.ok(data_dir)
end

local function ensure_all_haunt_dirs(workspace)
  for _, context in pairs(workspace.haunt.contexts or {}) do
    local abs_r = abs_loci_relative_data_dir(context.data_dir)
    if not abs_r.ok then
      return abs_r
    end
    local ensure_r = haunt_adapter.ensure_context_dir(abs_r.value)
    if not ensure_r.ok then
      return ensure_r
    end
  end
  return result.ok(true)
end

-- ============================================================================
-- Public API: clone
-- ============================================================================

---@async
---@param workspace_id string
---@param opts? table
---@return loci.Result<table>
function M.clone(workspace_id, opts)
  opts = opts or {}

  -- Read source workspace
  local source_r = tx.read(workspace_id)
  if not source_r.ok then
    return source_r
  end

  local source = source_r.value
  local timestamp = now(opts)

  -- Resolve clone project
  local clone_project_id = source.project_id
  if opts.project_id == false then
    clone_project_id = vim.NIL
  elseif opts.project_id then
    -- Validate the provided project exists
    local project_r = graph.read_project(opts.project_id)
    if not project_r.ok then
      return result.err("project not found: " .. opts.project_id, "not_found")
    end
    clone_project_id = opts.project_id
  end

  -- Build fresh workspace with clone name
  local clone_name = opts.name or (source.name .. " copy")
  local clone = workspace_domain.new({
    name = clone_name,
    project_id = clone_project_id,
    label = opts.label or clone_name,
    branch = opts.branch or source.git.branch,
    worktree_path = opts.worktree_path or source.git.worktree_path,
    created_at = timestamp,
    last_refreshed_at = timestamp,
  })

  -- Copy knowledge unless opts.copy_knowledge == false
  if opts.copy_knowledge ~= false then
    for _, obj in ipairs(source.knowledge.objects) do
      table.insert(clone.knowledge.objects, vim.deepcopy(obj))
    end

    -- Copy primary_loci_id only if the object was copied
    if source.knowledge.primary_loci_id and source.knowledge.primary_loci_id ~= vim.NIL then
      local found = false
      for _, obj in ipairs(clone.knowledge.objects) do
        if obj.loci_id == source.knowledge.primary_loci_id then
          found = true
          break
        end
      end
      if found then
        clone.knowledge.primary_loci_id = source.knowledge.primary_loci_id
      end
    end
  end

  -- Copy linked files unless opts.copy_linked_files == false
  if opts.copy_linked_files ~= false then
    for _, entry in ipairs(source.linked_files) do
      table.insert(clone.linked_files, vim.deepcopy(entry))
    end
  end

  -- Preserve logical Haunt context names and regenerate data_dirs
  if source.haunt.contexts then
    clone.haunt.contexts = {}
    for logical_name, context in pairs(source.haunt.contexts) do
      clone.haunt.contexts[logical_name] = {
        data_dir = ".loci/integrations/haunt/workspaces/" .. clone.workspace_id .. "/" .. logical_name,
      }
    end
    clone.haunt.active = source.haunt.active

    -- Ensure all cloned haunt context directories exist
    for context_name, context in pairs(clone.haunt.contexts) do
      local ensure_r = haunt_adapter.ensure_context_dir(context.data_dir)
      if not ensure_r.ok then
        return ensure_r
      end
    end
  end

  -- Preserve logical Wayfinder Trail names and regenerate trail_names
  if source.wayfinder.trails then
    clone.wayfinder.trails = {}
    for logical_name, _ in pairs(source.wayfinder.trails) do
      clone.wayfinder.trails[logical_name] = {
        trail_name = "loci-" .. clone.workspace_id .. "-" .. logical_name,
      }
    end
    clone.wayfinder.active = source.wayfinder.active
  end

  -- Clear runtime cache
  clone.tabby.tab_id_cache = vim.NIL
  clone.provenance.last_activated_at = vim.NIL

  -- Do not copy archive
  clone.archive = nil

  local mkdir_r = ensure_all_haunt_dirs(clone)
  if not mkdir_r.ok then
    return mkdir_r
  end

  -- Write clone workspace
  local write_r = tx.write(clone)
  if not write_r.ok then
    return write_r
  end

  -- Add clone to project membership if attached
  local proj_r = tx.add_workspace_to_project(clone_project_id, clone.workspace_id)
  if not proj_r.ok then
    return result.err(proj_r.err, proj_r.code, {
      workspace_id = clone.workspace_id,
      meta = proj_r.meta,
    })
  end

  -- Open clone if requested - use local open delegation
  if opts.open_after_create then
    -- Import and delegate to core.open
    local core = require("loci.service.workspace.core")
    local open_r = core.open(clone.workspace_id, opts)
    if not open_r.ok then
      return open_r
    end
  end

  return result.ok(clone)
end

return M
