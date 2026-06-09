local result = require('loci.result')
local scan = require('loci.store.refresh.scan')
local snapshot = require('loci.store.refresh.snapshot')
local plan = require('loci.store.refresh.plan')
local apply = require('loci.store.refresh.apply')

local M = {}
M.scan = scan.run
M.snapshot = snapshot.build
M.plan = plan.build
M.apply = apply.run

local function mode_from_opts(opts)
  opts = opts or {}
  if opts.tolerant == true or opts.mode == 'tolerant' then return 'tolerant' end
  return 'strict'
end

function M.run(opts)
  opts = opts or {}
  opts.mode = mode_from_opts(opts)
  local scan_r = M.scan(opts); if not scan_r.ok then return scan_r end
  local snapshot_r = M.snapshot(scan_r.value, opts); if not snapshot_r.ok then return snapshot_r end
  local plan_r = M.plan(snapshot_r.value, opts); if not plan_r.ok then return plan_r end
  local apply_r = M.apply(plan_r.value, opts); if not apply_r.ok then return apply_r end
  return result.ok({
    scan = scan_r.value.stats,
    snapshot = snapshot_r.value.stats,
    plan = plan_r.value.summary,
    apply = apply_r.value.stats,
    diagnostics = apply_r.value.diagnostics or {},
  })
end

return M
