local M = {}

local defaults = {
  name = "",
  description = "",
  version = "0.1.0",
  paths = {
    root = ".",
  },
  github = {
    repo = "",
  },
  loci = {
    enabled = true,
    root = ".loci",
    path = ".loci",
    obsidian = {
      enabled = true,
      vault_directory = "",
      vault_project_root = "Projects",
      vault_project_name = "",
      link_name = "project_files",
    },
  },
}

function M.get()
  return require("neoconf").get("project", defaults)
end

function M.value(key, fallback)
  return require("neoconf").get("project." .. key, fallback)
end

return M
