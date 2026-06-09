local result = require("loci.result")
local config = require("loci.config")
local path = require("loci.store.path")
local frontmatter = require("loci.store.frontmatter")
local repository_domain = require("loci.domain.repository")
local project_domain = require("loci.domain.project")
local workspace_domain = require("loci.domain.workspace")
local async = require("loci.async")

local M = {}
local add_item

---@class HealthItem
---@field section string
---@field status "ok"|"warn"|"error"|"info"
---@field code string
---@field message string
---@field path? string
---@field entity? string
---@field id? string
---@field details? table

---@class HealthReport
---@field root string
---@field loci_root string
---@field generated_at string|nil
---@field ok boolean
---@field counts { ok: integer, warn: integer, error: integer, info: integer }
---@field items HealthItem[]
---@field sections string[]

-- ============================================================================
-- Synchronous Helper Functions
-- ============================================================================

---@param path string
---@return "file"|"dir"|"link"|"unknown"
local function stat_kind(file_path)
  local stat = vim.uv.fs_lstat(file_path)
  if not stat then
    stat = vim.uv.fs_stat(file_path)
  end
  if not stat then
    return "unknown"
  end
  if stat.type == "file" then
    return "file"
  elseif stat.type == "directory" then
    return "dir"
  elseif stat.type == "link" then
    return "link"
  end
  return "unknown"
end

---@param file_path string
---@return string|nil
local function read_file_sync(file_path)
  local f = io.open(file_path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

---@param file_path string
---@return table|nil value
---@return string|nil err_code
---@return string|nil err_message
local function read_json_value(file_path)
  local content = read_file_sync(file_path)
  if not content then
    return nil, "missing", "File not found"
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    return nil, "decode_failed", "Failed to decode JSON: " .. tostring(decoded)
  end

  return decoded, nil, nil
end

---@param file_path string
---@param section string
---@param code_prefix string
---@return table|nil value
local function read_json_or_report(report, file_path, section, code_prefix)
  local value, err_code, err_message = read_json_value(file_path)
  if err_code then
    add_item(report, {
      section = section,
      status = "error",
      code = code_prefix .. "_" .. err_code,
      message = err_message,
      path = file_path,
    })
    return nil
  end
  return value
end

---@param dir string
---@return string[]
local function scan_json_files(dir)
  local files = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return files
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if type == "file" and name:match("%.json$") then
      table.insert(files, dir .. "/" .. name)
    end
  end

  table.sort(files)
  return files
end

---@param value string|nil
---@return boolean
local function is_safe_relative_path(value)
  if not value or type(value) ~= "string" then
    return false
  end
  if value:match("%z") or value:match("^/") or value:match("\\") then
    return false
  end
  if value:match("^%a:[/\\]") then
    return false
  end
  for part in value:gmatch("[^/]+") do
    if part == ".." then
      return false
    end
  end
  return true
end

-- ============================================================================
-- Health Checks Implementation
-- ============================================================================

---@param report HealthReport
---@param item HealthItem
add_item = function(report, item)
  if not item.section or not item.status or not item.code then
    return
  end

  table.insert(report.items, item)

  if not vim.tbl_contains(report.sections, item.section) then
    table.insert(report.sections, item.section)
  end

  local count_key = item.status
  report.counts[count_key] = (report.counts[count_key] or 0) + 1

  if item.status == "error" then
    report.ok = false
  end
end

---Check repository root and core files
---@param report HealthReport
local function check_repository(report)
  local root = report.root
  local loci_root = report.loci_root

  -- Repository root resolved
  add_item(report, {
    section = "Repository",
    status = "ok",
    code = "repository_root_resolved",
    message = "Repository root resolved",
    path = root,
  })

  -- LOCI root exists
  local loci_kind = stat_kind(loci_root)
  if loci_kind == "dir" then
    add_item(report, {
      section = "Repository",
      status = "ok",
      code = "loci_root_exists",
      message = ".loci directory exists",
      path = loci_root,
    })
  else
    add_item(report, {
      section = "Repository",
      status = "error",
      code = "loci_root_missing",
      message = ".loci directory not found",
      path = loci_root,
    })
    return
  end

  -- loci.json exists and valid
  local loci_json_path = loci_root .. "/loci.json"
  local loci_json = read_json_or_report(report, loci_json_path, "Repository", "loci_json")
  if not loci_json then
    return
  else
    add_item(report, {
      section = "Repository",
      status = "ok",
      code = "loci_json_valid",
      message = "loci.json is valid",
      path = loci_json_path,
    })
  end

  -- repository.json exists and valid
  local repo_json_path = loci_root .. "/repository.json"
  local repository = read_json_or_report(report, repo_json_path, "Repository", "repository_json")
  if not repository then
    return
  end

  local validation_r = repository_domain.validate(repository)
  if not validation_r.ok then
    add_item(report, {
      section = "Repository",
      status = "error",
      code = "repository_json_invalid",
      message = validation_r.err,
      path = repo_json_path,
    })
  else
    add_item(report, {
      section = "Repository",
      status = "ok",
      code = "repository_json_valid",
      message = "repository.json is valid",
      path = repo_json_path,
    })
  end

  -- Check required directories
  local required_dirs = {
    { name = "content", code = "content_dir" },
    { name = "graph", code = "graph_dir" },
    { name = "indexes", code = "indexes_dir" },
  }

  for _, dir_info in ipairs(required_dirs) do
    local dir_path = loci_root .. "/" .. dir_info.name
    local dir_kind = stat_kind(dir_path)
    if dir_kind == "dir" then
      add_item(report, {
        section = "Repository",
        status = "ok",
        code = dir_info.code .. "_exists",
        message = dir_info.name .. "/ directory exists",
        path = dir_path,
      })
    else
      add_item(report, {
        section = "Repository",
        status = "error",
        code = dir_info.code .. "_missing",
        message = dir_info.name .. "/ directory not found",
        path = dir_path,
      })
    end
  end
end

---Check graph consistency
---@param report HealthReport
local function check_graph(report)
  local loci_root = report.loci_root

  local repository = read_json_value(loci_root .. "/repository.json")
  if type(repository) ~= "table" then
    return
  end

  local current_json_path = loci_root .. "/graph/current.json"
  local current = read_json_or_report(report, current_json_path, "Graph", "current_json")
  if not current then
    return
  end

  add_item(report, {
    section = "Graph",
    status = "ok",
    code = "current_json_valid",
    message = "graph/current.json is valid",
    path = current_json_path,
  })

  for _, field in ipairs({ "repository_id", "workspace_id", "project_id", "activated_at" }) do
    if current[field] == nil then
      add_item(report, {
        section = "Graph",
        status = "error",
        code = "current_" .. field .. "_missing",
        message = "graph/current.json is missing " .. field,
        path = current_json_path,
      })
    end
  end

  if current.repository_id and current.repository_id ~= repository.repository_id then
    add_item(report, {
      section = "Graph",
      status = "error",
      code = "current_repository_mismatch",
      message = "current.json repository_id does not match repository.json",
      id = current.repository_id,
      details = { expected = repository.repository_id },
    })
  end

  local fallback_id = repository.default_workspace_id
  local fallback_path = loci_root .. "/graph/workspaces/" .. fallback_id .. ".json"
  local fallback_workspace, fallback_err = read_json_value(fallback_path)
  if fallback_err == "missing" then
    add_item(report, {
      section = "Graph",
      status = "error",
      code = "fallback_workspace_missing",
      message = "Default workspace file not found",
      path = fallback_path,
      id = fallback_id,
    })
  elseif fallback_err then
    add_item(report, {
      section = "Graph",
      status = "error",
      code = "fallback_workspace_invalid",
      message = "Default workspace JSON is invalid",
      path = fallback_path,
      id = fallback_id,
    })
  else
    local validation_r = workspace_domain.validate(fallback_workspace)
    if not validation_r.ok then
      add_item(report, {
        section = "Graph",
        status = "error",
        code = "fallback_workspace_invalid",
        message = validation_r.err,
        path = fallback_path,
        id = fallback_id,
      })
    else
      add_item(report, {
        section = "Graph",
        status = "ok",
        code = "fallback_workspace_exists",
        message = "Default workspace exists",
        path = fallback_path,
        id = fallback_id,
      })
    end
  end

  local current_ws_id = current.workspace_id or fallback_id
  local current_ws_path = loci_root .. "/graph/workspaces/" .. current_ws_id .. ".json"
  local current_workspace, current_err = read_json_value(current_ws_path)
  if current_err == "missing" then
    add_item(report, {
      section = "Graph",
      status = "warn",
      code = "current_workspace_missing",
      message = "Current workspace file not found; activation should fall back to default workspace",
      path = current_ws_path,
      id = current_ws_id,
    })
  elseif current_err then
    add_item(report, {
      section = "Graph",
      status = "warn",
      code = "current_workspace_invalid",
      message = "Current workspace JSON is invalid",
      path = current_ws_path,
      id = current_ws_id,
    })
  else
    local validation_r = workspace_domain.validate(current_workspace)
    if not validation_r.ok then
      add_item(report, {
        section = "Graph",
        status = "warn",
        code = "current_workspace_invalid",
        message = validation_r.err,
        path = current_ws_path,
        id = current_ws_id,
      })
    else
      add_item(report, {
        section = "Graph",
        status = "ok",
        code = "current_workspace_valid",
        message = "Current workspace resolves",
        path = current_ws_path,
        id = current_ws_id,
      })
    end
  end

  local projects_dir = loci_root .. "/graph/projects"
  local project_files = scan_json_files(projects_dir)
  local project_count = #project_files
  for _, project_path in ipairs(project_files) do
    local project, err_code, err_message = read_json_value(project_path)
    if err_code then
      add_item(report, {
        section = "Graph",
        status = "error",
        code = "project_graph_invalid",
        message = err_message,
        path = project_path,
      })
    else
      local validation_r = project_domain.validate(project)
      if not validation_r.ok then
        add_item(report, {
          section = "Graph",
          status = "error",
          code = "project_graph_invalid",
          message = validation_r.err,
          path = project_path,
          id = project.project_id,
        })
      end
    end
  end

  if project_count > 0 then
    add_item(report, {
      section = "Graph",
      status = "ok",
      code = "project_graph_valid",
      message = project_count .. " project(s) in graph",
      path = projects_dir,
    })
  else
    add_item(report, {
      section = "Graph",
      status = "info",
      code = "project_graph_empty",
      message = "No projects in graph yet",
      path = projects_dir,
    })
  end

  local workspace_files = scan_json_files(loci_root .. "/graph/workspaces")
  for _, workspace_path in ipairs(workspace_files) do
    local workspace, err_code, err_message = read_json_value(workspace_path)
    if err_code then
      add_item(report, {
        section = "Graph",
        status = "error",
        code = "workspace_graph_invalid",
        message = err_message,
        path = workspace_path,
      })
    else
      local validation_r = workspace_domain.validate(workspace)
      if not validation_r.ok then
        add_item(report, {
          section = "Graph",
          status = "error",
          code = "workspace_graph_invalid",
          message = validation_r.err,
          path = workspace_path,
          id = workspace.workspace_id,
        })
      end
    end
  end
end

---Check markdown knowledge associations
---@param report HealthReport
local function check_markdown_associations(report)
  local loci_root = report.loci_root
  local cfg = config.get()
  local max_checks = cfg.max_markdown_checks or 500
  local checked = 0

  -- Check projects
  local projects_dir = loci_root .. "/graph/projects"
  local project_files = scan_json_files(projects_dir)

  for _, project_path in ipairs(project_files) do
    if checked >= max_checks then
      break
    end

    local project = read_json_value(project_path)
    if project and project.content_path and is_safe_relative_path(project.content_path) then
      checked = checked + 1
      local abs_path = path.must_content_path(project.content_path)
      local kind = stat_kind(abs_path)

      if kind ~= "file" then
        add_item(report, {
          section = "Markdown",
          status = "warn",
          code = "project_markdown_missing",
          message = "Project markdown file not found",
          path = abs_path,
          entity = "project",
          id = project.project_id,
        })
      else
        -- Check loci_id
        local content = read_file_sync(abs_path)
        if content then
          local inspection = frontmatter.inspect(content)
          local found_id = inspection and inspection.fields and inspection.fields.loci_id or nil
          if found_id and found_id ~= project.project_id then
            add_item(report, {
              section = "Markdown",
              status = "error",
              code = "project_markdown_loci_id_mismatch",
              message = "Project markdown loci_id mismatch",
              path = abs_path,
              entity = "project",
              id = project.project_id,
              details = { found_id = found_id },
            })
          end
        end
      end
    end
  end

  -- Check workspace knowledge objects
  local workspaces_dir = loci_root .. "/graph/workspaces"
  local workspace_files = scan_json_files(workspaces_dir)

  for _, workspace_path in ipairs(workspace_files) do
    if checked >= max_checks then
      break
    end

    local workspace = read_json_value(workspace_path)
    if workspace and workspace.knowledge and type(workspace.knowledge) == "table" then
      local objects = workspace.knowledge.objects or {}
      for _, knowledge in ipairs(objects) do
        if checked >= max_checks then
          break
        end

        if knowledge.content_path and is_safe_relative_path(knowledge.content_path) then
          checked = checked + 1
          local abs_path = path.must_content_path(knowledge.content_path)
          local kind = stat_kind(abs_path)

          if kind ~= "file" then
            add_item(report, {
              section = "Markdown",
              status = "warn",
              code = "workspace_knowledge_missing",
              message = "Workspace knowledge file not found",
              path = abs_path,
              entity = "workspace",
              id = workspace.workspace_id,
              details = { object_id = knowledge.loci_id },
            })
          else
            local content = read_file_sync(abs_path)
            if content then
              local inspection = frontmatter.inspect(content)
              local found_id = inspection and inspection.fields and inspection.fields.loci_id or nil
              if found_id and found_id ~= knowledge.loci_id then
                add_item(report, {
                  section = "Markdown",
                  status = "error",
                  code = "workspace_knowledge_loci_id_mismatch",
                  message = "Knowledge object loci_id mismatch",
                  path = abs_path,
                  entity = "workspace",
                  id = workspace.workspace_id,
                  details = { object_id = knowledge.loci_id, found_id = found_id },
                })
              end
            end
          end
        end
      end
    end
  end

  if checked == 0 then
    add_item(report, {
      section = "Markdown",
      status = "info",
      code = "no_markdown_to_check",
      message = "No markdown associations to check",
    })
  end
end

---@param report HealthReport
local function check_duplicate_loci_ids(report)
  local markdown_index = read_json_value(report.loci_root .. "/indexes/markdown.json")
  if type(markdown_index) ~= "table" then
    return
  end
  local duplicates = markdown_index.duplicates or {}
  for _, dup in ipairs(duplicates) do
    add_item(report, {
      section = "Markdown",
      status = "error",
      code = "duplicate_loci_id",
      message = "Duplicate loci_id found: " .. tostring(dup.loci_id),
      details = { content_paths = dup.content_paths or {} },
      id = dup.loci_id,
    })
  end
end

---Check integrations health
---@param report HealthReport
local function check_integrations(report)
  if async.available() then
    add_item(report, {
      section = "Integrations",
      status = "ok",
      code = "nio_available",
      message = "nio is available",
    })
  else
    add_item(report, {
      section = "Integrations",
      status = "error",
      code = "nio_required",
      message = "nio is required but not available",
    })
  end

  local integrations = require("loci.integrations")
  local setup_r = integrations.last_setup_result and integrations.last_setup_result() or nil
  if setup_r and setup_r.ok and setup_r.value and setup_r.value.diagnostics then
    for _, diag in ipairs(setup_r.value.diagnostics) do
      add_item(report, {
        section = "Integrations",
        status = "warn",
        code = "integration_setup_diagnostic",
        message = string.format("%s setup diagnostic: %s", tostring(diag.integration), tostring(diag.error)),
      })
    end
  end

  local cfg = config.get()
  local integrations_to_check = {
    { name = "git", check_fn = function() return check_git(report) end },
    { name = "tabby", check_fn = function() return check_tabby(report) end },
    { name = "resession", check_fn = function() return check_resession(report) end },
    { name = "haunt", check_fn = function() return check_haunt(report) end },
    { name = "wayfinder", check_fn = function() return check_wayfinder(report) end },
    { name = "tasknotes", check_fn = function() return check_tasknotes(report) end },
    { name = "obsidian", check_fn = function() return check_obsidian(report) end },
    { name = "bases", check_fn = function() return check_bases(report) end },
  }

  for _, integ in ipairs(integrations_to_check) do
    local integ_cfg = cfg.integrations and cfg.integrations[integ.name]
    local enabled = type(integ_cfg) == "table" and integ_cfg.enabled ~= false

    if not enabled then
      add_item(report, {
        section = "Integrations",
        status = "info",
        code = integ.name .. "_disabled",
        message = integ.name .. " integration is disabled",
      })
    else
      pcall(integ.check_fn)
    end
  end
end

---Check git integration
---@param report HealthReport
local function check_git(report)
  local has_git = vim.fn.executable("git") == 1
  if not has_git then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "git_unavailable",
      message = "git executable not found",
    })
    return
  end

  add_item(report, {
    section = "Integrations",
    status = "ok",
    code = "git_available",
    message = "git executable found",
  })
end

---Check Tabby integration
---@param report HealthReport
local function check_tabby(report)
  local ok, tabby = pcall(require, "tabby")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "tabby_unavailable",
      message = "tabby plugin not installed",
    })
    return
  end

  if tabby.health then
    local ok_health, health_result = pcall(tabby.health)
    if ok_health and health_result then
      add_item(report, {
        section = "Integrations",
        status = health_result.status or "ok",
        code = "tabby_health",
        message = health_result.message or "tabby is available",
      })
    else
      add_item(report, {
        section = "Integrations",
        status = "ok",
        code = "tabby_available",
        message = "tabby plugin available",
      })
    end
  else
    add_item(report, {
      section = "Integrations",
      status = "ok",
      code = "tabby_available",
      message = "tabby plugin available",
    })
  end
end

---Check Resession integration
---@param report HealthReport
local function check_resession(report)
  local ok, resession = pcall(require, "resession")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "resession_unavailable",
      message = "resession plugin not installed",
    })
    return
  end

  add_item(report, {
    section = "Integrations",
    status = "ok",
    code = "resession_available",
    message = "resession plugin available",
  })
end

---Check Haunt integration
---@param report HealthReport
local function check_haunt(report)
  local ok, haunt = pcall(require, "haunt")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "haunt_unavailable",
      message = "haunt plugin not installed",
    })
    return
  end

  if haunt.health then
    local ok_health, health_result = pcall(haunt.health)
    if ok_health and health_result then
      add_item(report, {
        section = "Integrations",
        status = health_result.status or "ok",
        code = "haunt_health",
        message = health_result.message or "haunt is available",
      })
    else
      add_item(report, {
        section = "Integrations",
        status = "ok",
        code = "haunt_available",
        message = "haunt plugin available",
      })
    end
  else
    add_item(report, {
      section = "Integrations",
      status = "ok",
      code = "haunt_available",
      message = "haunt plugin available",
    })
  end
end

---Check Wayfinder integration
---@param report HealthReport
local function check_wayfinder(report)
  local ok, wayfinder = pcall(require, "wayfinder")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "wayfinder_unavailable",
      message = "wayfinder plugin not installed",
    })
    return
  end

  add_item(report, {
    section = "Integrations",
    status = "ok",
    code = "wayfinder_available",
    message = "wayfinder plugin available",
  })
end

---Check TaskNotes integration
---@param report HealthReport
local function check_tasknotes(report)
  local ok, tasknotes = pcall(require, "tasknotes")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "tasknotes_unavailable",
      message = "tasknotes plugin not installed",
    })
    return
  end

  add_item(report, {
    section = "Integrations",
    status = "ok",
    code = "tasknotes_available",
    message = "tasknotes plugin available",
  })
end

---Check Obsidian integration
---@param report HealthReport
local function check_obsidian(report)
  local ok, obsidian = pcall(require, "obsidian")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "obsidian_unavailable",
      message = "obsidian plugin not installed",
    })
    return
  end

  -- Check for configured vault
  local cfg_vault = config.get().vault
  if not cfg_vault or not cfg_vault.path then
    add_item(report, {
      section = "Obsidian",
      status = "info",
      code = "obsidian_not_configured",
      message = "Obsidian vault not configured",
    })
    return
  end

  add_item(report, {
    section = "Obsidian",
    status = "ok",
    code = "obsidian_available",
    message = "obsidian plugin available",
  })
end

---Check Bases integration
---@param report HealthReport
local function check_bases(report)
  local ok, bases = pcall(require, "bases")
  if not ok then
    add_item(report, {
      section = "Integrations",
      status = "warn",
      code = "bases_unavailable",
      message = "bases plugin not installed",
    })
    return
  end

  add_item(report, {
    section = "Integrations",
    status = "ok",
    code = "bases_available",
    message = "bases plugin available",
  })
end

-- ============================================================================
-- Remediation Hints
-- ============================================================================

---Get remediation hint suffix from doctor (lazy-loaded)
---@param item HealthItem
---@return string
local function remediation_suffix(item)
  local ok, doctor = pcall(require, "loci.health.doctor")
  if not ok then
    return ""
  end
  local hints = doctor.hints_for_item(item)
  if not hints or #hints == 0 then
    return ""
  end
  return " | Fix: " .. hints[1].summary
end

-- ============================================================================
-- Public API
-- ============================================================================

---Collect health information and return as structured data
---@param opts? { now?: string|function, root?: string, include_optional?: boolean, max_markdown_checks?: integer, max_items?: integer }
---@return loci.Result
function M.collect(opts)
  opts = opts or {}

  local root = opts.root or path.repository_root()
  local loci_root = root .. "/.loci"

  local report = {
    root = root,
    loci_root = loci_root,
    generated_at = nil,
    ok = true,
    counts = { ok = 0, warn = 0, error = 0, info = 0 },
    items = {},
    sections = {},
  }

  -- Set generation time
  if type(opts.now) == "function" then
    report.generated_at = opts.now()
  elseif type(opts.now) == "string" then
    report.generated_at = opts.now
  else
    local offset = os.date("%z")
    offset = offset:sub(1, 3) .. ":" .. offset:sub(4, 5)
    report.generated_at = os.date("%Y-%m-%dT%H:%M:%S") .. offset
  end

  -- Run all checks
  check_repository(report)
  check_graph(report)
  check_markdown_associations(report)
  check_duplicate_loci_ids(report)
  check_integrations(report)

  return result.ok(report)
end

---Health check function for Neovim's :checkhealth system
function M.check()
  local result_r = M.collect()

  if not result_r.ok then
    vim.health.error("Failed to collect health information")
    return
  end

  local report = result_r.value

  if not report then
    vim.health.error("Health report is empty")
    return
  end

  -- Render each item by section
  local sections_rendered = {}

  for _, section in ipairs(report.sections) do
    if not sections_rendered[section] then
      vim.health.start(section)
      sections_rendered[section] = true
    end

    for _, item in ipairs(report.items) do
      if item.section == section then
        local msg = item.message
        if item.path then
          msg = msg .. " (" .. item.path .. ")"
        end
        if item.id then
          msg = msg .. " [" .. item.id .. "]"
        end
        msg = msg .. remediation_suffix(item)

        if item.status == "ok" then
          vim.health.ok(msg)
        elseif item.status == "warn" then
          vim.health.warn(msg)
        elseif item.status == "error" then
          vim.health.error(msg)
        else
          vim.health.info(msg)
        end
      end
    end
  end

  -- Summary
  vim.health.start("Summary")
  if report.ok then
    vim.health.ok(string.format("Health check passed (ok: %d, info: %d)", report.counts.ok, report.counts.info))
  else
    vim.health.error(string.format("Health check failed (ok: %d, warn: %d, error: %d, info: %d)",
      report.counts.ok, report.counts.warn, report.counts.error, report.counts.info))
  end
end

return M
