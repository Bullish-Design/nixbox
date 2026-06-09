local result = require("loci.result")

local M = {}

local DEFAULTS = {
  version = 1,
  integrations = {
    tasknotes = {
      enabled = true,
      vault_path = nil,
      project_notes_pattern = nil,
    },
    obsidian = {
      enabled = true,
      vault_path = nil,
      project_path = nil,
      symlink_name = nil,
    },
    haunt = {
      enabled = true,
    },
    wayfinder = {
      enabled = true,
      require_named_api = true,
    },
    resession = {
      enabled = true,
    },
    tabby = {
      enabled = true,
    },
  },
  content = {
    root = ".loci/content",
    generated_marker = "loci_generated",
  },
  refresh = {
    default_mode = "strict",
  },
}

function M.canonical_defaults()
  return result.ok(vim.deepcopy(DEFAULTS))
end

local function validate_bool(value, path, errors)
  if type(value) ~= "boolean" then
    errors[#errors + 1] = path .. " must be boolean"
  end
end

local function validate_optional_string(value, path, errors)
  if value ~= nil and type(value) ~= "string" then
    errors[#errors + 1] = path .. " must be string or nil"
  end
end

function M.validate(config)
  if type(config) ~= "table" then
    return result.err("Config must be a table", "invalid_config")
  end

  local errors = {}
  if config.version ~= 1 then
    errors[#errors + 1] = "version must be 1"
  end

  local integrations = config.integrations
  if type(integrations) ~= "table" then
    errors[#errors + 1] = "integrations must be a table"
  else
    local tn = integrations.tasknotes
    if type(tn) ~= "table" then
      errors[#errors + 1] = "integrations.tasknotes must be a table"
    else
      validate_bool(tn.enabled, "integrations.tasknotes.enabled", errors)
      validate_optional_string(tn.vault_path, "integrations.tasknotes.vault_path", errors)
      validate_optional_string(tn.project_notes_pattern, "integrations.tasknotes.project_notes_pattern", errors)
    end

    local ob = integrations.obsidian
    if type(ob) ~= "table" then
      errors[#errors + 1] = "integrations.obsidian must be a table"
    else
      validate_bool(ob.enabled, "integrations.obsidian.enabled", errors)
      validate_optional_string(ob.vault_path, "integrations.obsidian.vault_path", errors)
      validate_optional_string(ob.project_path, "integrations.obsidian.project_path", errors)
      validate_optional_string(ob.symlink_name, "integrations.obsidian.symlink_name", errors)
    end

    local ha = integrations.haunt
    if type(ha) ~= "table" then
      errors[#errors + 1] = "integrations.haunt must be a table"
    else
      validate_bool(ha.enabled, "integrations.haunt.enabled", errors)
    end

    local wf = integrations.wayfinder
    if type(wf) ~= "table" then
      errors[#errors + 1] = "integrations.wayfinder must be a table"
    else
      validate_bool(wf.enabled, "integrations.wayfinder.enabled", errors)
      validate_bool(wf.require_named_api, "integrations.wayfinder.require_named_api", errors)
    end
  end

  if #errors > 0 then
    return result.err("Invalid Loci config", "invalid_config", { errors = errors })
  end

  return result.ok(config)
end

function M.serialize_repository_config(config)
  local validate_r = M.validate(config)
  if not validate_r.ok then
    return validate_r
  end
  return result.ok(vim.deepcopy(config))
end

return M
