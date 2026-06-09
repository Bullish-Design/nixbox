local result = require("loci.result")
local markdown = require("loci.store.markdown")
local frontmatter = require("loci.store.frontmatter")

local M = {}

---@async
function M.repair_frontmatter(opts)
  opts = opts or {}
  local scan_r = markdown.scan_content()
  if not scan_r.ok then return scan_r end
  local repaired, skipped, diagnostics = 0, 0, {}
  for _, doc in ipairs(scan_r.value.objects or {}) do
    local inspection = frontmatter.inspect((doc.raw_frontmatter or "") .. "\n")
    if #inspection.diagnostics > 0 then
      skipped = skipped + 1
      for _, d in ipairs(inspection.diagnostics) do
        local item = vim.deepcopy(d)
        item.path = doc.content_path
        table.insert(diagnostics, item)
      end
    end
  end
  return result.ok({ repaired = repaired, skipped = skipped, diagnostics = diagnostics, dry_run = opts.dry_run == true })
end

---@async
function M.repair_project_refs(opts)
  opts = opts or {}
  return result.ok({ repaired = 0, skipped = 0, diagnostics = {}, dry_run = opts.dry_run == true })
end

return M
