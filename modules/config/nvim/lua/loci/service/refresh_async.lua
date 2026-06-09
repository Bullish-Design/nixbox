local result = require("loci.result")
local jobs = require("loci.service.jobs")
local refresh = require("loci.store.refresh")

local M = {}

--- @async
--- @param opts? { on_progress?: fun(progress: table) }
--- @return loci.Result
function M.refresh_all(opts)
  opts = opts or {}

  local job_r = jobs.start({ kind = "refresh", name = "full refresh" })
  if not result.is_ok(job_r) then
    return job_r
  end
  local job = job_r.value

  local function finish(r)
    jobs.complete(job.id)
    return r
  end

  if opts.on_progress then opts.on_progress({ phase = "refresh", message = "Running refresh pipeline..." }) end
  jobs.update_progress(job.id, { current = 1, total = 1, message = "Refreshing..." })
  local run_r = refresh.run(opts)
  if not run_r.ok then return finish(run_r) end

  local r = result.ok({
    job_id = job.id,
    refresh = run_r.value,
    diagnostics = run_r.value.diagnostics or {},
    markdown_count = run_r.value.scan and run_r.value.scan.content_entries or 0,
    project_count = run_r.value.scan and run_r.value.scan.projects or 0,
    workspace_count = run_r.value.scan and run_r.value.scan.workspaces or 0,
  })
  return finish(r)
end

--- @async
--- @param project_id string
--- @param opts? table
--- @return loci.Result
function M.refresh_project(project_id, opts)
  return refresh.run(opts)
end

--- @async
--- @param workspace_id string
--- @param opts? table
--- @return loci.Result
function M.refresh_workspace(workspace_id, opts)
  return refresh.run(opts)
end

return M
