local result = require('loci.result')
local graph = require('loci.store.graph')
local workspace_tx = require('loci.service.workspace.tx')
local fs = require("loci.store.fs")
local path = require("loci.store.path")

local M = {}

local function is_tolerant(opts) return opts and (opts.tolerant == true or opts.mode == 'tolerant') end
local function record_failure(diagnostics, item, r)
  diagnostics[#diagnostics + 1] = { code = r.code or 'refresh_apply_failed', message = r.err or 'Refresh apply failed', severity = 'error', id = item.id, details = { item = item, cause = r.meta } }
end
local function apply_one(item)
  if item.kind == 'project' then return graph.write_project(item.value)
  elseif item.kind == 'workspace_tx' then return workspace_tx.write(item.value)
  elseif item.kind == 'repository' then return graph.write_repository(item.value)
  elseif item.kind == 'current' then return graph.write_current(item.value)
  elseif item.kind == "project_delete" then return fs.unlink(path.must_graph_path("projects/" .. item.id .. ".json"))
  elseif item.kind == "workspace_delete" then return fs.unlink(path.must_graph_path("workspaces/" .. item.id .. ".json"))
  elseif item.kind == "index_file" then return require("loci.store.json").write(path.must_index_path(item.name), item.value)
  elseif item.kind == 'generated_file' then return fs.write_file(item.abs_path, item.value)
  else return result.err('Unknown refresh plan item kind: ' .. tostring(item.kind), 'unknown_refresh_plan_item') end
end

function M.run(plan, opts)
  opts = opts or {}
  local tolerant = is_tolerant(opts)
  local diagnostics = vim.deepcopy(plan.diagnostics or {})
  local applied, skipped = {}, {}
  local lists = { plan.graph_writes or {}, plan.graph_deletes or {}, plan.index_writes or {}, plan.generated_writes or {} }
  for _, list in ipairs(lists) do
    for _, item in ipairs(list) do
      local r = apply_one(item)
      if not r.ok then
        record_failure(diagnostics, item, r)
        if not tolerant then return result.err('Refresh apply failed', 'refresh_apply_failed', { item = item, cause = r, diagnostics = diagnostics }) end
        skipped[#skipped + 1] = item
      else applied[#applied + 1] = item end
    end
  end
  return result.ok({ applied = applied, skipped = skipped, diagnostics = diagnostics, stats = { applied = #applied, skipped = #skipped, diagnostics = #diagnostics } })
end

return M
