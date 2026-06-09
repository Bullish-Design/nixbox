local M = {}
local providers = {}

providers.cwd = function(ctx)
  ctx.cwd = vim.fn.getcwd()
end

providers.project_root = function(ctx)
  local git_root = vim.fs.root(0, ".git")
  ctx.root = git_root or ctx.cwd
  ctx.project_name = vim.fn.fnamemodify(ctx.root, ":t")
end

providers.git = function(ctx)
  local git_data = vim.b.minigit_summary or {}
  ctx.git = { branch = git_data.head_name or git_data.head or nil }
end

providers.lsp = function(ctx)
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  ctx.lsp = { active = #clients > 0, clients = vim.tbl_map(function(c) return c.name end, clients) }
end

providers.diagnostics = function(ctx)
  local diag = vim.diagnostic.get()
  local counts = { error = 0, warn = 0, info = 0, hint = 0 }
  for _, d in ipairs(diag) do
    if d.severity == vim.diagnostic.severity.ERROR then counts.error = counts.error + 1
    elseif d.severity == vim.diagnostic.severity.WARN then counts.warn = counts.warn + 1
    elseif d.severity == vim.diagnostic.severity.INFO then counts.info = counts.info + 1
    elseif d.severity == vim.diagnostic.severity.HINT then counts.hint = counts.hint + 1
    end
  end
  ctx.diagnostics = counts
end

providers.buffers = function(ctx)
  local bufs = vim.tbl_filter(function(b)
    return vim.bo[b].buflisted and vim.bo[b].filetype ~= ""
  end, vim.api.nvim_list_bufs())
  ctx.buffers = { count = #bufs }
end

providers.sessions = function(ctx)
  local ok, resession = pcall(require, "resession")
  if not ok then
    ctx.session = { available = false }
    return
  end
  ctx.session = { available = true, current = resession.get_current(), list = resession.list() }
end

function M.gather(provider_names)
  local ctx = {}
  for _, name in ipairs(provider_names or {}) do
    local provider = providers[name]
    if provider then
      local ok, err = pcall(provider, ctx)
      if not ok then
        ctx.errors = ctx.errors or {}
        table.insert(ctx.errors, { provider = name, error = tostring(err) })
      end
    end
  end
  return ctx
end

function M.register(name, fn)
  providers[name] = fn
end

return M
