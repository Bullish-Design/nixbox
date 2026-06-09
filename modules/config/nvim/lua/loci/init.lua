local result = require("loci.result")

local M = {}

function M.setup(opts)
  require("loci.config").setup(opts)
  local activation = require("loci.service.activation")
  local status = require("loci.ui.status")
  activation.on_activate(function(snapshot)
    status.refresh_cache(snapshot)
  end)
  require("loci.ui.commands").register()
  local integrations_setup_r = require("loci.integrations").setup(opts)
  if integrations_setup_r and integrations_setup_r.ok and integrations_setup_r.value then
    for _, diag in ipairs(integrations_setup_r.value.diagnostics or {}) do
      vim.notify(
        string.format("LOCI integration setup diagnostic (%s): %s", tostring(diag.integration), tostring(diag.error)),
        vim.log.levels.WARN
      )
    end
  end

  local cfg = require("loci.config").get()
  if cfg.refresh and cfg.refresh.on_setup then
    local async = require("loci.async")
    if async.available() then
      async.run(function()
        return require("loci.service.refresh_async").refresh_all()
      end, function(r)
        if not r.ok and not (r.code == "not_initialized") then
          require("loci.ui.commands.util").notify_result("LOCI: scheduled refresh failed", r)
        end
      end)
    else
      require("loci.ui.commands.util").notify_result(
        "LOCI: nio not available, skipping setup refresh",
        result.err("nio unavailable", "integration_unavailable")
      )
    end
  end
end

return M
