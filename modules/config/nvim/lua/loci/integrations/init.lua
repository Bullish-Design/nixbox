local result = require("loci.result")
local config = require("loci.config")

local M = {}
local last_setup_result = nil

-- Note: obsidian is intentionally excluded — its symlink setup is repo-dependent
-- and runs during service.repository.ensure()/init_new() after content dir exists.
local INTEGRATIONS = {
  { name = "tasknotes", module = "loci.integrations.tasknotes" },
  { name = "haunt", module = "loci.integrations.haunt" },
  { name = "wayfinder", module = "loci.integrations.wayfinder" },
  { name = "tabby", module = "loci.integrations.tabby" },
  { name = "resession", module = "loci.integrations.resession" },
}

function M.setup(opts)
  local cfg = config.get()
  local loaded = {}
  local skipped = {}
  local diagnostics = {}

  for _, integration in ipairs(INTEGRATIONS) do
    local integ_cfg = cfg.integrations and cfg.integrations[integration.name]
    if type(integ_cfg) == "table" and integ_cfg.enabled ~= false then
      local ok, mod = pcall(require, integration.module)
      if ok and type(mod.setup) == "function" then
        local r = mod.setup(opts)
        if r and not result.is_ok(r) then
          table.insert(diagnostics, {
            integration = integration.name,
            error = r.err,
          })
        end
        table.insert(loaded, integration.name)
      elseif ok then
        table.insert(loaded, integration.name)
      else
        table.insert(skipped, integration.name)
        table.insert(diagnostics, {
          integration = integration.name,
          error = "module not found",
        })
      end
    else
      table.insert(skipped, integration.name)
    end
  end

  local setup_result = result.ok({
    loaded = loaded,
    skipped = skipped,
    diagnostics = diagnostics,
  })
  last_setup_result = setup_result
  return setup_result
end

function M.last_setup_result()
  return last_setup_result
end

return M
