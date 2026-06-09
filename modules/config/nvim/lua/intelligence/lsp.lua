local capabilities = require("blink.cmp").get_lsp_capabilities()

local function path_join(...)
  return table.concat({ ... }, "/")
end

local function fs_type(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type or nil
end

local function is_file(path)
  return fs_type(path) == "file"
end

local function relative_to(root, path)
  if vim.startswith(path, root .. "/") then
    return path:sub(#root + 2)
  end
  return path
end

local function project_python(root_dir)
  if not root_dir or root_dir == "" then
    return nil
  end

  local candidates = {
    path_join(root_dir, ".devenv", "state", "venv"),
    path_join(root_dir, ".venv"),
  }

  for _, venv in ipairs(candidates) do
    local python = path_join(venv, "bin", "python")
    if is_file(python) then
      return venv, python
    end
  end

  return nil
end

local function with_project_python_env(config)
  local root_dir = config.root_dir
  local venv = project_python(root_dir)
  if not venv then
    return
  end

  config.cmd_env = vim.tbl_extend("force", config.cmd_env or {}, {
    VIRTUAL_ENV = venv,
    PATH = path_join(venv, "bin") .. ":" .. vim.env.PATH,
  })

  return venv
end

local function configure_ty_project_env(_, config)
  local venv = with_project_python_env(config)
  if not venv then
    return
  end

  config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
    ty = {
      configuration = {
        environment = {
          python = relative_to(config.root_dir, venv),
        },
      },
    },
  })
end

local function configure_python_project_env(_, config)
  with_project_python_env(config)
end

local servers = {
  lua_ls = {
    capabilities = capabilities,
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        completion = { callSnippet = "Replace" },
        hint = { enable = true },
      },
    },
  },
  nil_ls = { capabilities = capabilities },
  -- basedpyright = {
  --   capabilities = capabilities,
  --   settings = {
  --     basedpyright = {
  --       analysis = { autoSearchPaths = true, diagnosticMode = "openFilesOnly" },
  --     },
  --   },
  -- },
  ty = {
    capabilities = capabilities,
    settings = {
      ty = {
        diagnosticMode = "openFilesOnly",
      },
    },
    before_init = configure_ty_project_env,
  },
  ruff = {
    capabilities = capabilities,
    before_init = configure_python_project_env,
  },
  rust_analyzer = {
    capabilities = capabilities,
    settings = {
      ["rust-analyzer"] = {
        checkOnSave = { command = "clippy" },
        procMacro = { enable = true },
      },
    },
  },
  vtsls = { capabilities = capabilities },
  html = { capabilities = capabilities },
  jsonls = { capabilities = capabilities },
  yamlls = { capabilities = capabilities },
  markdown_oxide = { capabilities = capabilities },
}

for name, config in pairs(servers) do
  vim.lsp.config(name, config)
end

local server_cmds = {
  lua_ls = "lua-language-server",
  nil_ls = "nil",
  -- basedpyright = "basedpyright-langserver",
  ty = "ty",
  ruff = "ruff",
  rust_analyzer = "rust-analyzer",
  vtsls = "vtsls",
  html = "vscode-html-language-server",
  jsonls = "vscode-json-language-server",
  yamlls = "yaml-language-server",
  markdown_oxide = "markdown-oxide",
}

local to_enable = {}
for name, cmd in pairs(server_cmds) do
  if vim.fn.executable(cmd) == 1 then
    table.insert(to_enable, name)
  end
end

vim.lsp.enable(to_enable)

vim.diagnostic.config({
  virtual_text = { prefix = "●", spacing = 4 },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded" },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/formatting") then
      if vim.b[args.buf]._format_on_save then
        return
      end
      vim.b[args.buf]._format_on_save = true
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = args.buf,
        callback = function()
          vim.lsp.buf.format({
            bufnr = args.buf,
            timeout_ms = 500,
            filter = function(c)
              return true
            end,
          })
        end,
      })
    end
  end,
})
