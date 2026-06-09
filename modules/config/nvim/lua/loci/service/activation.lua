local result = require("loci.result")
local id = require("loci.domain.id")
local graph = require("loci.store.graph")
local tx = require("loci.service.workspace.tx")
local path_store = require("loci.store.path")
local async = require("loci.async")
local git = require("loci.integrations.git")
local tabby = require("loci.integrations.tabby")
local resession = require("loci.integrations.resession")
local haunt = require("loci.integrations.haunt")
local wayfinder = require("loci.integrations.wayfinder")
local runtime = require("loci.service.runtime")

local M = {}
local _on_activate_callbacks = {}

function M.on_activate(fn)
  table.insert(_on_activate_callbacks, fn)
end

-- ============================================================================
-- Configuration & Helpers
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

local function json_null_to_nil(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

local function project_runtime_state(plan)
  if vim.in_fast_event() then async.schedule() end
  runtime.apply_activation(plan)
end

local function call_on_main(fn)
  if vim.in_fast_event() then
    async.schedule()
  end
  return pcall(fn)
end

---Check if session appears empty (no listed buffers or only empty scratch buffer).
local function session_appears_empty()
  if vim.in_fast_event() then async.schedule() end
  local listed = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      listed[buf] = true
    end
  end
  local tab_buffers = vim.tbl_keys(listed)

  if #tab_buffers == 0 then
    return true
  end

  if #tab_buffers == 1 then
    local name = vim.api.nvim_buf_get_name(tab_buffers[1])
    local modified = vim.bo[tab_buffers[1]].modified
    return name == "" and not modified
  end

  return false
end

---Open primary Markdown object if configured and session is empty.
local function open_primary_markdown(workspace)
  if not workspace.knowledge.primary_loci_id or workspace.knowledge.primary_loci_id == vim.NIL then
    return result.ok({ opened = false, reason = "no primary_loci_id" })
  end

  -- Find the object in workspace.knowledge.objects
  local primary_obj = nil
  for _, obj in ipairs(workspace.knowledge.objects or {}) do
    if obj.loci_id == workspace.knowledge.primary_loci_id then
      primary_obj = obj
      break
    end
  end

  if not primary_obj or not primary_obj.content_path then
    return result.ok({ opened = false, reason = "primary object not associated" })
  end

  -- Convert content_path to absolute
  local markdown = require("loci.store.markdown")
  local abs_r = markdown.abs_path_for_content(primary_obj.content_path)
  if not abs_r.ok then
    return result.ok({ opened = false, reason = "primary content_path not found" })
  end

  -- Open the file
  local ok, err = call_on_main(function()
    local buf = vim.fn.bufadd(abs_r.value)
    vim.bo[buf].swapfile = false
    vim.fn.bufload(buf)
    vim.api.nvim_set_current_buf(buf)
  end)
  if not ok then
    return result.ok({ opened = false, reason = "open failed" })
  end

  return result.ok({ opened = true, path = abs_r.value })
end

---Record soft failure in summary.
local function record_soft_failure(summary, integration_name, r)
  summary.integrations[integration_name] = {
    ok = r.ok,
    code = r.code,
    err = r.err,
    meta = r.meta,
    value = r.ok and r.value or nil,
  }
end

local function result_to_integration_summary(r)
  if r.ok then
    local value = r.value or {}
    value.ok = true
    return value
  end

  return {
    ok = false,
    code = r.code,
    err = r.err,
    meta = r.meta,
  }
end

local function add_warning(summary, integration, r)
  summary.warnings = summary.warnings or {}
  local warning = {
    integration = integration,
    code = r.code,
    err = r.err,
    meta = r.meta,
  }
  table.insert(summary.warnings, warning)
  summary.integration_warnings = summary.warnings
end

local function build_activation_plan(workspace_id, opts)
  local plan = {
    requested_workspace_id = workspace_id,
    resolved_workspace_id = nil,
    repository = nil,
    workspace = nil,
    target_dir = nil,
    current = nil,
    opts = opts or {},
  }

  local sentinel_r = graph.read_repository()
  if not sentinel_r.ok then
    return sentinel_r
  end
  plan.repository = sentinel_r.value

  if not workspace_id or workspace_id == "" then
    workspace_id = plan.repository.default_workspace_id
  end
  plan.resolved_workspace_id = workspace_id

  local ws_r = tx.read(workspace_id)
  if not ws_r.ok then
    return ws_r
  end
  plan.workspace = ws_r.value

  local worktree_r = git.resolve_worktree(plan.workspace, plan.repository)
  if not worktree_r.ok then
    return worktree_r
  end
  plan.target_dir = worktree_r.value

  plan.current = {
    repository_id = plan.repository.repository_id,
    project_id = plan.workspace.project_id,
    workspace_id = plan.workspace.workspace_id,
    activated_at = now(opts),
  }

  return result.ok(plan)
end

-- ============================================================================
-- Current Pointer Operations
-- ============================================================================

---@async
---@return loci.Result<table>
function M.current()
  return graph.read_current()
end

local function current_tab_workspace_id()
  local tab_id = runtime.get_tab_workspace_id()
  if tab_id then
    return tab_id
  end
  local current_r = graph.read_current()
  if current_r.ok and current_r.value then
    return current_r.value.workspace_id
  end
  return nil
end

-- ============================================================================
-- Deactivation
-- ============================================================================

---@async
---@param opts? table {save_resession = true, save_wayfinder = false}
---@return loci.Result
function M.deactivate_current(opts)
  opts = opts or {}
  if opts.save_resession == nil then
    opts.save_resession = true
  end
  if opts.save_wayfinder == nil then
    opts.save_wayfinder = false
  end

  -- Get workspace ID from tab-local var (preferred) or global current pointer
  local workspace_id = current_tab_workspace_id()

  local summary = {
    deactivated = false,
    workspace_id = workspace_id,
    integrations = {},
    warnings = {},
  }

  if not workspace_id then
    summary.reason = "no active workspace"
    return result.ok(summary)
  end

  -- Read current workspace
  local ws_r = tx.read(workspace_id)
  if not ws_r.ok then
    summary.reason = "workspace not found"
    summary.workspace_read = result_to_integration_summary(ws_r)
    return result.ok(summary)
  end

  local workspace = ws_r.value

  -- Save Resession if configured
  if opts.save_resession then
    local save_r = resession.save_session(workspace)
    summary.integrations.resession = result_to_integration_summary(save_r)
    if not save_r.ok then
      add_warning(summary, "resession", save_r)
      if opts.fail_on_save_error and save_r.code ~= "integration_unavailable" then
        return result.err(save_r.err, save_r.code, {
          failed_step = "save_resession",
          workspace_id = workspace_id,
          deactivation = summary,
          integration_meta = save_r.meta,
        })
      end
    end
  end

  -- Save Wayfinder if requested
  if opts.save_wayfinder then
    local save_r = wayfinder.save_active(workspace)
    summary.integrations.wayfinder = result_to_integration_summary(save_r)
    if not save_r.ok then
      add_warning(summary, "wayfinder", save_r)
      if opts.fail_on_save_error and save_r.code ~= "integration_unavailable" then
        return result.err(save_r.err, save_r.code, {
          failed_step = "save_wayfinder",
          workspace_id = workspace_id,
          deactivation = summary,
          integration_meta = save_r.meta,
        })
      end
    end
  end

  summary.deactivated = true
  if vim.in_fast_event() then async.schedule() end
  runtime.clear_runtime()
  return result.ok(summary)
end

-- ============================================================================
-- Activation (Main Orchestrator)
-- ============================================================================

---@async
---@param workspace_id? string
---@param opts? table
---@return loci.Result<table>
function M.activate(workspace_id, opts)
  opts = opts or {}
  if opts.save_current == nil then
    opts.save_current = true
  end
  if opts.open_primary == nil then
    opts.open_primary = true
  end
  if opts.notify == nil then
    opts.notify = false
  end

  local summary = {
    repository_id = nil,
    project_id = nil,
    workspace_id = nil,
    workspace_name = nil,
    cwd = nil,
    integrations = {
      git = { ok = false },
      tabby = { ok = false },
      resession = { ok = false },
      haunt = { ok = false },
      wayfinder = { ok = false },
    },
    opened_primary = false,
    warnings = {},
    integration_warnings = {},
    graph_persisted = false,
    runtime_projection_failed = false,
  }

  -- =========================================================================  -- =========================================================================

  local plan_r = build_activation_plan(workspace_id, opts)
  if not plan_r.ok then
    return plan_r
  end
  local plan = plan_r.value
  local repository = plan.repository
  local workspace = plan.workspace
  local target_dir = plan.target_dir

  summary.repository_id = repository.repository_id
  summary.workspace_id = workspace.workspace_id
  summary.workspace_name = workspace.name
  summary.project_id = json_null_to_nil(workspace.project_id)
  summary.cwd = target_dir

  -- =========================================================================  -- =========================================================================

  if opts.save_current then
    local deactivate_r = M.deactivate_current({
      save_resession = true,
      save_wayfinder = opts.save_wayfinder_on_deactivate == true,
      fail_on_save_error = opts.fail_on_deactivation_save_error == true,
    })
    if deactivate_r.ok then
      summary.deactivation = deactivate_r.value
      for _, warning in ipairs(deactivate_r.value.warnings or {}) do
        add_warning(summary, warning.integration or "deactivation", warning)
      end
    else
      summary.deactivation = {
        ok = false,
        code = deactivate_r.code,
        err = deactivate_r.err,
        meta = deactivate_r.meta,
      }
      if opts.fail_on_deactivation_save_error == true then
        return deactivate_r
      end
      warn_once("deactivation_save_failed", "LOCI deactivation save failed: " .. tostring(deactivate_r.err))
    end
  end

  -- =========================================================================  -- =========================================================================

  local current = plan.current

  -- Write current pointer
  local current_write_r = graph.write_current(current)
  if not current_write_r.ok then
    return result.err(
      "Failed to persist current.json: " .. current_write_r.err,
      current_write_r.code,
      {
        repository_id = repository.repository_id,
        project_id = json_null_to_nil(workspace.project_id),
        workspace_id = workspace.workspace_id,
        activated_at = current.activated_at,
        failed_step = "write_current",
        meta = current_write_r.meta,
      }
    )
  end

  -- Update workspace provenance
  workspace.provenance.last_activated_at = current.activated_at

  -- Write workspace
  local ws_write_r = tx.write(workspace)
  if not ws_write_r.ok then
    return result.err(
      "Failed to persist workspace: " .. ws_write_r.err,
      ws_write_r.code,
      {
        repository_id = repository.repository_id,
        project_id = json_null_to_nil(workspace.project_id),
        workspace_id = workspace.workspace_id,
        activated_at = current.activated_at,
        failed_step = "write_workspace",
        current = current,
        meta = ws_write_r.meta,
      }
    )
  end
  summary.graph_persisted = true

  for _, fn in ipairs(_on_activate_callbacks) do
    fn({
      repository = repository,
      project = nil,
      workspace = workspace,
    })
  end

  project_runtime_state(plan)

  -- =========================================================================  -- =========================================================================

  local tab_id_cache_dirty = false

  local tab_r = tabby.activate_workspace(workspace)
  if tab_r.ok then
    summary.integrations.tabby = {
      ok = true,
      mode = tab_r.value.mode,
      tab_id = tab_r.value.tab_id,
    }
    if tab_r.value.tab_id then
      workspace.tabby.tab_id_cache = tab_r.value.tab_id
      tab_id_cache_dirty = true
    end
    if vim.in_fast_event() then async.schedule() end
    runtime.set_tab_workspace_id(workspace.workspace_id)
  else
    record_soft_failure(summary, "tabby", tab_r)
    summary.runtime_projection_failed = true
    add_warning(summary, "tabby", tab_r)
  end

  local git_r = git.switch_worktree(target_dir)
  if git_r.ok then
    summary.integrations.git = { ok = true, changed_dir = true }
  else
    record_soft_failure(summary, "git", git_r)
    summary.runtime_projection_failed = true
    add_warning(summary, "git", git_r)
  end

  local res_r = resession.load_session(workspace)
  if res_r.ok then
    summary.integrations.resession = {
      ok = true,
      loaded = res_r.value.loaded or false,
    }
  else
    record_soft_failure(summary, "resession", res_r)
    summary.runtime_projection_failed = true
    if res_r.code ~= "integration_unavailable" then
      add_warning(summary, "resession", res_r)
    end
  end

  local haunt_r = haunt.activate_workspace(workspace)
  if haunt_r.ok then
    if haunt_r.value and haunt_r.value.reason == "haunt not available" then
      summary.integrations.haunt = {
        ok = false,
        code = "integration_unavailable",
        err = "Haunt is not available",
      }
    else
      summary.integrations.haunt = {
        ok = true,
        changed = haunt_r.value.changed or false,
      }
    end
  else
    record_soft_failure(summary, "haunt", haunt_r)
    summary.runtime_projection_failed = true
    if haunt_r.code ~= "integration_unavailable" then
      add_warning(summary, "haunt", haunt_r)
    end
  end

  local way_r
  local wf = workspace.wayfinder
  if type(wf) == "table" and type(wf.trails) == "table" then
    local active_name = wf.active or "main"
    local entry = wf.trails[active_name]
    local trail_name = entry and entry.trail_name
    if trail_name then
      way_r = wayfinder.load_named(trail_name)
    else
      way_r = result.ok({ action = "none", reason = "no_trail_config" })
    end
  else
    way_r = result.ok({ action = "none", reason = "no_trail_config" })
  end

  if way_r.ok then
    summary.integrations.wayfinder = {
      ok = true,
      action = way_r.value.action or "load",
      reason = way_r.value.reason,
    }
  else
    record_soft_failure(summary, "wayfinder", way_r)
    summary.runtime_projection_failed = true
    if way_r.code ~= "integration_unavailable" and way_r.code ~= "unsupported_capability"
      and way_r.code ~= "wayfinder_named_api_unavailable" then
      warn_once("wayfinder_failed", "Wayfinder activation failed: " .. way_r.err)
    end
  end

  if opts.open_primary and session_appears_empty() then
    local primary_r = open_primary_markdown(workspace)
    if primary_r.ok and primary_r.value.opened then
      summary.opened_primary = true
    end
  end

  if tab_id_cache_dirty then
    local ws_cache_r = tx.write(workspace)
    if not ws_cache_r.ok then
      summary.runtime_projection_failed = true
      add_warning(summary, "graph", result.err("failed to persist tab cache", ws_cache_r.code, ws_cache_r.meta))
    end
  end

  -- =========================================================================
  -- Return success
  -- =========================================================================

  return result.ok(summary)
end

return M
