local result = require("loci.result")
local id_module = require("loci.domain.id")

local M = {}

---@class LociJob
---@field id string
---@field kind string
---@field name string
---@field started_at string
---@field progress? { current: number, total: number, message?: string }
---@field cancelled boolean
---@field _cancel_fn? fun()

--- Singleton kinds -- only one job of this kind may run at a time.
local SINGLETON_KINDS = {
  refresh = true,
  repair = true,
  migration = true,
}

local _active_jobs = {} --- @type table<string, LociJob>

--- Start a new job. Returns err if a singleton kind is already running.
--- @param opts { kind: string, name: string }
--- @return loci.Result<LociJob>
function M.start(opts)
  if SINGLETON_KINDS[opts.kind] then
    for _, job in pairs(_active_jobs) do
      if job.kind == opts.kind and not job.cancelled then
        return result.err(
          opts.kind .. " is already running: " .. job.name,
          "job_conflict",
          { existing_job_id = job.id }
        )
      end
    end
  end

  local job = {
    id = id_module.short_id(8),
    kind = opts.kind,
    name = opts.name,
    started_at = id_module.now_iso(),
    cancelled = false,
    progress = nil,
  }
  _active_jobs[job.id] = job
  return result.ok(job)
end

--- Update job progress.
--- @param job_id string
--- @param progress { current: number, total: number, message?: string }
function M.update_progress(job_id, progress)
  local job = _active_jobs[job_id]
  if job then
    job.progress = progress
  end
end

--- Check if a job has been cancelled (cooperative cancellation checkpoint).
--- @param job_id string
--- @return boolean
function M.is_cancelled(job_id)
  local job = _active_jobs[job_id]
  return job and job.cancelled or false
end

--- Request cancellation of a job. Does not interrupt; the job must check.
--- @param job_id string
--- @return loci.Result
function M.cancel(job_id)
  local job = _active_jobs[job_id]
  if not job then
    return result.err("job not found: " .. job_id, "not_found")
  end
  job.cancelled = true
  if job._cancel_fn then
    job._cancel_fn()
  end
  return result.ok(job)
end

--- Complete a job (remove from active).
--- @param job_id string
function M.complete(job_id)
  _active_jobs[job_id] = nil
end

--- List active jobs.
--- @return LociJob[]
function M.list()
  local jobs = {}
  for _, job in pairs(_active_jobs) do
    table.insert(jobs, job)
  end
  table.sort(jobs, function(a, b)
    return a.started_at < b.started_at
  end)
  return jobs
end

--- Reset (for testing).
function M.reset()
  _active_jobs = {}
end

return M
