local result = require("loci.result")
local async = require("loci.async")
local id = require("loci.domain.id")
local path = require("loci.store.path")
local json = require("loci.store.json")
local markdown = require("loci.store.markdown")
local project_domain = require("loci.domain.project")
local graph = require("loci.store.graph")

local M = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function get_now(opts)
  if opts and type(opts.clock) == "function" then
    return opts.clock()
  end
  if opts and type(opts.now) == "string" and opts.now ~= "" then
    return opts.now
  end
  return id.now_iso()
end

local function ensure_initialized()
  if not path.is_initialized() then
    return result.err("LOCI repository is not initialized", "not_initialized")
  end
  return result.ok()
end

local function project_abs_content_path(content_path)
  return path.must_content_path(content_path)
end

local open_file = function(abs_path)
  async.schedule()
  vim.cmd.edit(vim.fn.fnameescape(abs_path))
end

function M._set_open_file_for_test(fn)
  open_file = fn
end

-- ============================================================================
-- Existing helpers from phase 3
-- ============================================================================

---Generate wikilink for project from graph or content path.
---@param graph_or_path string|table
---@param opts? table
---@return loci.Result<string>
function M.markdown_wikilink(graph_or_path, opts)
  opts = opts or {}

  local content_path
  if type(graph_or_path) == "string" then
    content_path = graph_or_path
  elseif type(graph_or_path) == "table" and graph_or_path.content_path then
    content_path = graph_or_path.content_path
  else
    return result.err("Invalid input for markdown_wikilink", "invalid_input")
  end

  return markdown.wikilink_for_content_path(content_path, opts)
end

---Ensure the current buffer has a loci_id.
---@param opts? table
---@return loci.Result<loci.MarkdownObject>
function M.ensure_current_markdown_id(opts)
  opts = opts or {}

  local buf = 0
  local abs_path = vim.api.nvim_buf_get_name(buf)

  if not abs_path or abs_path == "" then
    return result.err("No file in current buffer", "invalid_input")
  end

  -- Check if under content
  local is_under_res = markdown.is_under_content(abs_path)
  if not is_under_res.ok then
    return is_under_res
  end
  if not is_under_res.value then
    return result.err("File is not under .loci/content/", "outside_content")
  end

  -- Delegate to store
  return markdown.ensure_loci_id(abs_path, opts)
end

---Get markdown summary for a path.
---@param abs_path string
---@return loci.Result<loci.MarkdownObject>
function M.markdown_summary_for_path(abs_path)
  if not abs_path or abs_path == "" then
    return result.err("abs_path is required", "invalid_input")
  end

  local read_res = markdown.read_frontmatter(abs_path)
  if not read_res.ok then
    return read_res
  end

  return result.ok(read_res.value.object)
end

-- ============================================================================
-- Main API
-- ============================================================================

function M.get(project_id)
  if not id.is_valid(project_id) then
    return result.err("invalid project_id", "invalid_input")
  end

  return graph.read_project(project_id)
end

function M.list()
  return graph.list_projects()
end

---@async
---@return loci.Result<table[]>
function M.picker_entries()
  local index_path = path.must_index_path("projects.json")
  local index_res = json.read(index_path)
  if not index_res.ok then
    return index_res
  end
  local index = index_res.value
  if type(index) ~= "table" or index.kind ~= "projects_index" or type(index.projects) ~= "table" then
    return result.err("invalid projects index", "invalid_index")
  end
  return result.ok(index.projects)
end

---@async
---@return loci.Result<table[]>
function M.index_entries(opts)
  return M.picker_entries()
end

function M.open(project_id_or_opts)
  local project_id

  if not project_id_or_opts then
    return result.err("project_id is required", "invalid_input")
  end

  if type(project_id_or_opts) == "string" then
    project_id = project_id_or_opts
    if not id.is_valid(project_id) then
      return result.err("invalid project_id: " .. tostring(project_id), "invalid_input", {
        project_id = project_id,
      })
    end
  elseif type(project_id_or_opts) == "table" then
    project_id = project_id_or_opts.project_id
  end

  if not project_id then
    return result.err("project_id is required", "invalid_input")
  end
  if not id.is_valid(project_id) then
    return result.err("invalid project_id: " .. tostring(project_id), "invalid_input", {
      project_id = project_id,
    })
  end

  local get_res = M.get(project_id)
  if not get_res.ok then
    return get_res
  end
  local proj = get_res.value
  local abs_path = project_abs_content_path(proj.content_path)

  open_file(abs_path)

  return result.ok(proj)
end

function M.create(opts)
  opts = opts or {}

  local init_check = ensure_initialized()
  if not init_check.ok then
    return init_check
  end

  local title = opts.title
  if type(title) ~= "string" or title:gsub("%s+", "") == "" then
    return result.err("project title is required", "invalid_input")
  end

  local status = opts.status or "active"
  local now = get_now(opts)

  -- Generate project_id if needed
  local project_id = opts.project_id or id.new(title)
  if not id.is_valid(project_id) then
    return result.err("invalid project_id", "invalid_input")
  end

  -- Compute content_path
  local content_path = opts.content_path
  if not content_path then
    local slug = id.slugify(title)
    local base_filename = "projects/" .. slug .. ".md"
    local check_path = base_filename
    local suffix = 1

    while suffix < 100 do
      local check_abs = project_abs_content_path(check_path)
      local check_exists = vim.fn.filereadable(check_abs)
      if check_exists == 0 then
        content_path = check_path
        break
      end

      -- If the file exists, check if it's the same project
      local read_res = markdown.read_frontmatter(check_abs)
      if read_res.ok then
        local obj = read_res.value.object
        if obj.loci_id == project_id then
          content_path = check_path
          break
        end
      end

      suffix = suffix + 1
      check_path = "projects/" .. slug .. "-" .. suffix .. ".md"
    end

    if not content_path then
      return result.err("cannot find available filename for project", "conflict")
    end
  end

  -- Create project graph
  local domain_res = project_domain.new({
    title = title,
    project_id = project_id,
    content_path = content_path,
    status = status,
    now = now,
  })
  if not domain_res.ok then
    return domain_res
  end
  local proj = domain_res.value

  -- Create markdown first (before graph)
  local filename = content_path:match("([^/]+)$")
  local md_res = markdown.write_new_object({
    dir = "projects",
    filename = filename,
    loci_id = project_id,
    title = title,
    type = "project",
    status = status,
    tags = { "project" },
    body = "# " .. title .. "\n",
    overwrite = false,
  })

  if not md_res.ok then
    return md_res
  end

  -- Write graph
  local graph_res = graph.write_project(proj)
  if not graph_res.ok then
    return result.err(graph_res.err, graph_res.code, {
      content_path = content_path,
    })
  end

  -- Refresh index
  M.refresh_index()

  -- Optionally open
  if opts.open then
    open_file(project_abs_content_path(content_path))
  end

  return result.ok(proj, {
    content_path = content_path,
    graph_path = ".loci/graph/projects/" .. project_id .. ".json",
  })
end

function M.link_current(opts)
  opts = opts or {}

  local buf = opts.buffer or 0
  local abs_path = vim.api.nvim_buf_get_name(buf)

  if not abs_path or abs_path == "" then
    return result.err("No file in current buffer", "invalid_input")
  end

  -- Check if under content
  local is_under_res = markdown.is_under_content(abs_path)
  if not is_under_res.ok then
    return is_under_res
  end
  if not is_under_res.value then
    return result.err("File is not under .loci/content/", "outside_content")
  end

  -- Resolve project
  local project_id = opts.project_id
  if not project_id then
    return result.err("project_id is required", "invalid_input")
  end
  if not id.is_valid(project_id) then
    return result.err("invalid project_id: " .. tostring(project_id), "invalid_input")
  end

  local proj_res = M.get(project_id)
  if not proj_res.ok then
    return proj_res
  end
  local proj = proj_res.value

  -- Check if it's the project's own markdown
  if abs_path == project_abs_content_path(proj.content_path) then
    return result.ok({
      project = proj,
      markdown_loci_id = nil,
      content_path = nil,
      project_link = nil,
      changed = false,
    })
  end

  -- Ensure current markdown has loci_id
  local ensure_res = markdown.ensure_loci_id(abs_path, opts)
  if not ensure_res.ok then
    return ensure_res
  end
  local markdown_obj = ensure_res.value

  -- Get project wikilink
  local wikilink_res = markdown.wikilink_for_content_path(proj.content_path)
  if not wikilink_res.ok then
    return wikilink_res
  end
  local project_link = wikilink_res.value

  -- Check if link already exists before mutation
  local pre_read = markdown.read_frontmatter(abs_path)
  local already_linked = false
  if pre_read.ok then
    for _, item in ipairs(pre_read.value.frontmatter.projects or {}) do
      if item == project_link then
        already_linked = true
        break
      end
    end
  end

  -- Add to projects frontmatter list
  local add_res = markdown.add_frontmatter_list_value(abs_path, "projects", project_link)
  if not add_res.ok then
    return add_res
  end
  local doc = add_res.value

  -- Refresh project cache
  local refresh_res = M.refresh(proj.project_id, { now = opts.now })
  if not refresh_res.ok then
    return refresh_res
  end
  local updated_proj = refresh_res.value

  return result.ok({
    project = updated_proj,
    markdown_loci_id = markdown_obj.loci_id,
    content_path = doc.content_path,
    project_link = project_link,
    changed = not already_linked,
  })
end

function M.refresh(project_id, opts)
  if not id.is_valid(project_id) then
    return result.err("invalid project_id", "invalid_input")
  end
  local refresh = require("loci.store.refresh")
  local run_r = refresh.run(opts)
  if not run_r.ok then
    return run_r
  end
  return graph.read_project(project_id)
end

function M.refresh_index(opts)
  local refresh = require("loci.store.refresh")
  return refresh.run(opts)
end

function M.info(project_id)
  local get_res = M.get(project_id)
  if not get_res.ok then
    return get_res
  end

  local proj = get_res.value

  return result.ok({
    project_id = proj.project_id,
    title = proj.title_cache,
    status = proj.status_cache,
    content_path = proj.content_path,
    workspace_count = #proj.workspace_ids,
    task_count = #proj.cache.task_loci_ids,
    issue_count = #proj.cache.issue_loci_ids,
    note_count = #proj.cache.note_loci_ids,
    linked_file_count = #proj.linked_files,
    last_refreshed_at = proj.provenance.last_refreshed_at,
  })
end

return M
