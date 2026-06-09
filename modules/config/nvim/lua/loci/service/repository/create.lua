local result = require("loci.result")
local graph = require("loci.store.graph")
local fs = require("loci.store.fs")
local path_store = require("loci.store.path")
local workspace_domain = require("loci.domain.workspace")
local repository_domain = require("loci.domain.repository")
local config_domain = require("loci.domain.config")
local id = require("loci.domain.id")
local config = require("loci.config")

local M = {}

local function now(opts)
  if opts and type(opts.now) == "string" and opts.now ~= "" then
    return opts.now
  end
  return id.now_iso()
end

local function is_missing(r)
  return r ~= nil and r.code == "not_found"
end

local function wrap_invalid(kind, entity_id, read_r)
  return result.err(kind .. " graph is invalid; run Loci doctor repair", "invalid_existing_" .. kind, { id = entity_id, cause = read_r })
end

local function ensure_repository_dirs()
  local dirs = {
    path_store.loci_root(),
    path_store.must_graph_path(),
    path_store.must_content_path(),
    path_store.must_index_path(),
    path_store.must_integration_path(),
  }

  local content_subdirs = { "notes", "daily", "scratch", "projects", "bases" }
  for _, subdir in ipairs(content_subdirs) do
    local path_r = path_store.content_path(subdir)
    if not path_r.ok then
      return path_r
    end
    dirs[#dirs + 1] = path_r.value
  end

  dirs[#dirs + 1] = path_store.must_graph_path("workspaces")
  dirs[#dirs + 1] = path_store.must_graph_path("projects")

  for _, dir in ipairs(dirs) do
    local r = fs.mkdir_p(dir)
    if not r.ok then
      return r
    end
  end

  return result.ok(true)
end

local function create_fallback_workspace(repo, opts)
  local workspace = workspace_domain.new({ workspace_id = repo.default_workspace_id, name = "Fallback", created_at = now(opts), last_refreshed_at = now(opts) })
  return graph.write_workspace(workspace)
end

local function ensure_fallback_workspace(repo)
  local fallback_r = graph.read_workspace(repo.default_workspace_id)

  if fallback_r.ok then
    return result.ok({ workspace = fallback_r.value, created = false })
  end

  if is_missing(fallback_r) then
    local create_r = create_fallback_workspace(repo, nil)
    if not create_r.ok then
      return create_r
    end
    return result.ok({ workspace = create_r.value, created = true })
  end

  return wrap_invalid("fallback_workspace", repo.default_workspace_id, fallback_r)
end

local function ensure_obsidian_symlink()
  local cfg = config.get()
  local ob = cfg.integrations and cfg.integrations.obsidian
  if type(ob) ~= "table" or ob.enabled == false then
    return result.ok({ skipped = true })
  end
  local obsidian = require("loci.integrations.obsidian")
  return obsidian.ensure_content_symlink()
end

local function ensure_current_pointer(repo, opts)
  local current_r = graph.read_current()
  if current_r.ok then
    return current_r
  end

  if is_missing(current_r) then
    return graph.write_current({
      current_workspace_id = repo.default_workspace_id,
      current_project_id = nil,
      workspace_id = repo.default_workspace_id,
      project_id = nil,
      repository_id = repo.repository_id,
      activated_at = now(opts),
      updated_at = now(opts),
    })
  end

  return result.err("Current pointer is invalid; run Loci doctor repair", "invalid_current_pointer", { cause = current_r })
end

function M.init_new(opts)
  opts = opts or {}

  local repo_r = graph.read_repository()
  if repo_r.ok then
    return result.err("Loci repository already exists", "repository_already_exists", { repository = repo_r.value })
  end
  if not is_missing(repo_r) then
    return result.err("Cannot initialize over invalid repository graph", "repository_init_blocked", { cause = repo_r })
  end

  local dirs_r = ensure_repository_dirs()
  if not dirs_r.ok then return dirs_r end

  local defaults_r = config_domain.canonical_defaults()
  if not defaults_r.ok then return defaults_r end

  local repo_config_r = config_domain.serialize_repository_config(defaults_r.value)
  if not repo_config_r.ok then return repo_config_r end

  local repo_new_r = repository_domain.new({
    root = path_store.repository_root(),
    config = repo_config_r.value,
    created_at = now(opts),
    last_refreshed_at = now(opts),
    repository_id = opts.repository_id,
    default_workspace_id = opts.default_workspace_id,
    name = opts.name,
  })
  if not repo_new_r.ok then return repo_new_r end
  repo_new_r.value.config = repo_config_r.value

  local write_repo_r = graph.write_repository(repo_new_r.value)
  if not write_repo_r.ok then return write_repo_r end

  local fallback_r = create_fallback_workspace(repo_new_r.value, opts)
  if not fallback_r.ok then
    return fallback_r
  end

  local current_r = graph.write_current({
    current_workspace_id = repo_new_r.value.default_workspace_id,
    current_project_id = nil,
    workspace_id = repo_new_r.value.default_workspace_id,
    project_id = nil,
    repository_id = repo_new_r.value.repository_id,
    activated_at = now(opts),
    updated_at = now(opts),
  })
  if not current_r.ok then
    return result.err("Repository initialized but current pointer could not be written; run Loci again to complete", "repository_init_partial", { cause = current_r, repository = repo_new_r.value })
  end

  local vault_symlink_r = ensure_obsidian_symlink()
  if not vault_symlink_r.ok then
    return vault_symlink_r
  end

  return result.ok({ repository = repo_new_r.value, fallback_workspace = fallback_r.value, created = true, vault_symlink = vault_symlink_r.value })
end

function M.ensure(opts)
  opts = opts or {}

  local repo_r = graph.read_repository()
  if repo_r.ok then
    local dirs_r = ensure_repository_dirs()
    if not dirs_r.ok then return dirs_r end

    local fallback_r = ensure_fallback_workspace(repo_r.value)
    if not fallback_r.ok then return fallback_r end

    local current_r = ensure_current_pointer(repo_r.value, opts)
    if not current_r.ok then return current_r end

    local vault_symlink_r = ensure_obsidian_symlink()
    if not vault_symlink_r.ok then return vault_symlink_r end

    return result.ok({
      repository = repo_r.value,
      fallback_workspace = fallback_r.value.workspace,
      created = false,
      repaired_fallback_workspace = fallback_r.value.created,
      vault_symlink = vault_symlink_r.value,
    })
  end

  if is_missing(repo_r) then
    return M.init_new(opts)
  end

  return result.err("Existing Loci repository graph is invalid; run Loci doctor repair", "invalid_existing_repository", { cause = repo_r })
end

M.ensure_repository_dirs_public = ensure_repository_dirs
M.create_fallback_workspace_public = create_fallback_workspace

return M
