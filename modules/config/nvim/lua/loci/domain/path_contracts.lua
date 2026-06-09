local result = require("loci.result")

local M = {}

local function invalid(msg)
  return result.err(msg, "invalid_content_path")
end

function M.validate_content_path(path)
  if type(path) ~= "string" or path == "" then
    return invalid("content_path must be a non-empty string")
  end
  if path:sub(1, 1) == "/" then
    return invalid("content_path must be relative")
  end
  if path:match("\\") then
    return invalid("content_path must use forward slashes")
  end
  if path:match("^content/") then
    return invalid("content_path must not include content/ prefix")
  end
  if path:match("^%.loci/") then
    return invalid("content_path must be relative to .loci/content")
  end
  if path == ".." or path:match("^%.%./") or path:match("/%.%./") or path:match("/%.%.$") then
    return invalid("content_path must not contain traversal")
  end
  return result.ok(path)
end

local function invalid_repo_path(msg)
  return result.err(msg, "invalid_repo_relative_path")
end

function M.validate_repo_relative_path(path)
  if type(path) ~= "string" or path == "" then
    return invalid_repo_path("path must be a non-empty string")
  end
  if path:sub(1, 1) == "/" then
    return invalid_repo_path("path must be repository-relative")
  end
  if path:match("\\") then
    return invalid_repo_path("path must use forward slashes")
  end
  if path == ".." or path:match("^%.%./") or path:match("/%.%./") or path:match("/%.%.$") then
    return invalid_repo_path("path must not contain traversal")
  end
  return result.ok(path)
end

function M.validate_linked_file_path(path)
  local base = M.validate_repo_relative_path(path)
  if not base.ok then
    return result.err(base.err, "invalid_linked_file_path")
  end
  if path:match("^%.loci/") then
    return result.err("linked files cannot target .loci paths", "invalid_linked_file_path")
  end
  return result.ok(path)
end

function M.validate_haunt_data_dir(path)
  if type(path) ~= "string" or path == "" then
    return result.err("haunt data_dir must be a non-empty string", "invalid_haunt_data_dir")
  end
  if path:sub(1, 1) == "/" or path:match("\\") then
    return result.err("haunt data_dir must be a canonical relative path", "invalid_haunt_data_dir")
  end
  if path == ".." or path:match("^%.%./") or path:match("/%.%./") or path:match("/%.%.$") then
    return result.err("haunt data_dir must not contain traversal", "invalid_haunt_data_dir")
  end
  if not path:match("^%.loci/integrations/haunt/workspaces/[a-z0-9][a-z0-9%-]*%-[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]/[^/]+$") then
    return result.err("haunt data_dir is not canonical", "invalid_haunt_data_dir")
  end
  return result.ok(path)
end

return M
