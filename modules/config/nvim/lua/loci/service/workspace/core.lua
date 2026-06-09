local result = require("loci.result")
local id = require("loci.domain.id")
local markdown = require("loci.store.markdown")
local graph = require("loci.store.graph")
local path = require("loci.store.path")
local fs = require("loci.store.fs")
local workspace_domain = require("loci.domain.workspace")
local activation_service = require("loci.service.activation")
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

local function resolve_content_path(content_path_or_buf)
  if type(content_path_or_buf) == "number" then
    -- Buffer ID - get the absolute path
    local abs_path = vim.api.nvim_buf_get_name(content_path_or_buf)
    if not abs_path or abs_path == "" then
      return nil, "buffer has no file path"
    end
    return abs_path
  end
  -- Assume it's a content path - convert to absolute
  local abs_r = markdown.abs_path_for_content(content_path_or_buf)
  if not abs_r.ok then
    return nil, abs_r.err
  end
  return abs_r.value
end

local function ensure_default_haunt_dir(workspace)
  local context = workspace.haunt.contexts[workspace.haunt.active]
  local abs_dir = path.loci_root() .. "/" .. context.data_dir:gsub("^%.loci/", "")
  return fs.mkdir_p(abs_dir)
end

-- ============================================================================
-- Markdown Object Helpers
-- ============================================================================

---Get markdown object for a path.
---@param abs_path string
---@param opts? table
---@return loci.Result<loci.MarkdownObject>
function M.markdown_object_for_path(abs_path, opts)
  opts = opts or {}

  if not abs_path or abs_path == "" then
    return result.err("abs_path is required", "invalid_input")
  end

  local read_res = markdown.read_frontmatter(abs_path)
  if not read_res.ok then
    return read_res
  end

  return result.ok(read_res.value.object)
end

---Generate knowledge entry for markdown object.
---@param abs_path string
---@param opts? table
---@return loci.Result<table>
function M.knowledge_entry_for_markdown(abs_path, opts)
  opts = opts or {}

  if not abs_path or abs_path == "" then
    return result.err("abs_path is required", "invalid_input")
  end

  -- Ensure loci_id exists
  local ensure_res = markdown.ensure_loci_id(abs_path, opts)
  if not ensure_res.ok then
    return ensure_res
  end

  local obj = ensure_res.value

  -- Build knowledge entry
  local entry = {
    type = obj.type or "note",
    loci_id = obj.loci_id,
    content_path = obj.content_path,
    title_cache = obj.title,
    role = opts.role or "supporting",
  }

  return result.ok(entry)
end

-- ============================================================================
-- Public API: create
-- ============================================================================

---@async
---@param opts table
---@return loci.Result<table>
function M.create(opts)
  opts = opts or {}

  -- Validate required fields
  if not opts.name or type(opts.name) ~= "string" or opts.name == "" then
    return result.err("name is required and must be a non-empty string", "invalid_input")
  end

  -- If project_id is provided, validate it exists
  if opts.project_id then
    local project_r = graph.read_project(opts.project_id)
    if not project_r.ok then
      return result.err("project not found: " .. opts.project_id, "not_found", {
        project_id = opts.project_id,
      })
    end
  end

  -- Validate worktree_path if provided
  if opts.worktree_path then
    if type(opts.worktree_path) ~= "string" or opts.worktree_path == "" then
      return result.err("worktree_path must be a non-empty string", "invalid_input")
    end
    if opts.worktree_path:match("%z") or opts.worktree_path:match("\\") then
      return result.err("worktree_path contains invalid characters", "invalid_input")
    end
  end

  local timestamp = now(opts)

  -- Build the workspace graph
  local workspace = workspace_domain.new({
    name = opts.name,
    workspace_id = opts.workspace_id,
    project_id = opts.project_id,
    label = opts.label,
    branch = opts.branch,
    worktree_path = opts.worktree_path,
    created_at = timestamp,
    last_refreshed_at = timestamp,
  })

  -- Handle primary knowledge if provided
  if opts.primary then
    local abs_path = resolve_content_path(opts.primary)
    if not abs_path then
      return result.err("could not resolve primary content path", "invalid_input")
    end

    -- Ensure the markdown object exists
    local entry_r = M.knowledge_entry_for_markdown(abs_path, opts)
    if not entry_r.ok then
      return entry_r
    end

    local entry = entry_r.value
    table.insert(workspace.knowledge.objects, entry)
    workspace.knowledge.primary_loci_id = entry.loci_id
  end

  -- Create default Haunt directory
  local mkdir_r = ensure_default_haunt_dir(workspace)
  if not mkdir_r.ok then
    return mkdir_r
  end

  -- Write workspace graph
  local write_r = tx.write(workspace)
  if not write_r.ok then
    return write_r
  end

  -- Add to project membership if attached
  local proj_r = tx.add_workspace_to_project(opts.project_id, workspace.workspace_id)
  if not proj_r.ok then
    return result.err(proj_r.err, proj_r.code, {
      workspace_id = workspace.workspace_id,
      meta = proj_r.meta,
    })
  end

  return result.ok(workspace)
end

-- ============================================================================
-- Public API: open
-- ============================================================================

---@async
---@param workspace_id? string
---@param opts? table
---@return loci.Result<table>
function M.open(workspace_id, opts)
  return activation_service.activate(workspace_id, opts)
end

-- ============================================================================
-- Public API: info
-- ============================================================================

---@async
---@param workspace_id string
---@return loci.Result<table>
function M.info(workspace_id)
  return tx.read(workspace_id)
end

return M
