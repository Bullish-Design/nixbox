local defaults = {
  project = {
    name = "",
    description = "",
    version = "0.1.0",
    paths = {
      root = ".",
    },
    github = {
      repo = "",
    },
  },
}

require("neoconf").setup({
  local_settings = ".neoconf.json",
  global_settings = "neoconf.json",
  import = {
    vscode = true,
    coc = false,
    nlsp = false,
  },
  live_reload = true,
  filetype_jsonc = true,
  plugins = {
    lspconfig = {
      enabled = false,
    },
    jsonls = {
      enabled = false, --  true,
      configured_servers_only = false,
    },
    lua_ls = {
      enabled_for_neovim_config = true,
      enabled = false,
    },
  },
})

vim.api.nvim_create_user_command("ProjectInfo", function()
  local project = require("project.config").get()
  vim.notify(vim.inspect(project), vim.log.levels.INFO, { title = "Project Config" })
end, { desc = "Show merged Neoconf project settings" })

return defaults
