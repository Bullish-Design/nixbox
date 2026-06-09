local id = require("loci.domain.id")
local result = require("loci.result")

local M = {}
local SCHEMA_VERSION = 1

local function basename(root)
  local trimmed = tostring(root or ""):gsub("/+$", "")
  return trimmed:match("([^/]+)$") or "repository"
end

local function is_nonempty_string(value)
  return type(value) == "string" and value ~= ""
end

local function is_absolute_path(value)
  return type(value) == "string" and value:match("^/") ~= nil
end

function M.new(opts)
  opts = opts or {}
  if type(opts.root) ~= "string" or opts.root == "" then
    return result.err("Repository root is required", "invalid_repository")
  end

  local name = opts.name or basename(opts.root)
  local created_at = opts.created_at or opts.now
  local repository = {
    schema_version = SCHEMA_VERSION,
    repository_id = opts.repository_id or id.new(name),
    name = name,
    root = opts.root,
    default_workspace_id = opts.default_workspace_id or id.new("repo-default"),
    default_content_path = opts.default_content_path or "index.md",
    provenance = {
      created_at = created_at,
      last_refreshed_at = opts.last_refreshed_at or created_at,
    },
  }
  return M.validate(repository)
end

function M.validate(repository)
  if type(repository) ~= "table" then
    return result.err("repository must be a table", "validation_failed")
  end
  if repository.schema_version ~= SCHEMA_VERSION then
    return result.err("unsupported repository schema_version", "validation_failed")
  end
  if not id.is_valid(repository.repository_id) then
    return result.err("invalid repository_id", "validation_failed")
  end
  if not is_nonempty_string(repository.name) then
    return result.err("repository name is required", "validation_failed")
  end
  if not is_absolute_path(repository.root) then
    return result.err("repository root must be absolute", "validation_failed")
  end
  if not id.is_valid(repository.default_workspace_id) then
    return result.err("invalid default_workspace_id", "validation_failed")
  end
  if repository.default_content_path ~= "index.md" then
    return result.err("default_content_path must be index.md", "validation_failed")
  end
  if type(repository.provenance) ~= "table" then
    return result.err("repository provenance is required", "validation_failed")
  end
  if not is_nonempty_string(repository.provenance.created_at) then
    return result.err("repository provenance.created_at is required", "validation_failed")
  end
  if not is_nonempty_string(repository.provenance.last_refreshed_at) then
    return result.err("repository provenance.last_refreshed_at is required", "validation_failed")
  end
  return result.ok(repository)
end

return M
