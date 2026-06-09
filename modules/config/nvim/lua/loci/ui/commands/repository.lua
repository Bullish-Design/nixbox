local result = require("loci.result")
local repository = require("loci.service.repository")
local util = require("loci.ui.commands.util")

local M = {}

function M.register()
  vim.api.nvim_create_user_command("LociInit", function()
    util.run_async(function()
      return repository.ensure()
    end, function(r)
      local message = "LOCI: Repository initialized"
      if r.ok and r.value and r.value.created == false then
        message = "LOCI: Repository already initialized"
      end
      util.notify_result(message, r)
    end)
  end, {
    desc = "Initialize LOCI repository state",
    force = true,
  })

  vim.api.nvim_create_user_command("LociHealth", function()
    vim.cmd("checkhealth loci")
  end, {
    desc = "Run LOCI health checks",
    force = true,
  })

  vim.api.nvim_create_user_command("LociDoctor", function(args)
    require("loci.health.doctor").open({
      include_ok = args.bang or false,
    })
  end, {
    desc = "Open LOCI health diagnostics with remediation hints",
    bang = true,
    force = true,
  })

  vim.api.nvim_create_user_command("LociOpenRoot", function()
    util.notify_result("LOCI: Opened repository index", repository.open_root())
  end, {
    desc = "Open .loci/content/index.md",
    force = true,
  })

  vim.api.nvim_create_user_command("LociRepairFrontmatter", function(cmd)
    util.run_async(function()
      local repair = require("loci.health.repair")
      return repair.repair_frontmatter({ dry_run = cmd.bang })
    end, function(r)
      util.notify_result("LOCI Repair Frontmatter", r)
    end)
  end, {
    desc = "Repair frontmatter issues in all content files",
    bang = true,
    force = true,
  })

  vim.api.nvim_create_user_command("LociRepairProjectRefs", function(cmd)
    util.run_async(function()
      local repair = require("loci.health.repair")
      return repair.repair_project_refs({ dry_run = cmd.bang })
    end, function(r)
      util.notify_result("LOCI Repair Project Refs", r)
    end)
  end, {
    desc = "Convert legacy project references to project IDs",
    bang = true,
    force = true,
  })
end

return M
