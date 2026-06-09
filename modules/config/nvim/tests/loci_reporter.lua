local M = {}

local function case_name(case)
  local desc = table.concat(case.desc or {}, " | ")
  if #(case.args or {}) == 0 then
    return desc
  end
  return ("%s + args %s"):format(desc, vim.inspect(case.args, { newline = "", indent = "" }))
end

local function write_line(text)
  local log_cases = vim.uv.os_getenv("LOCI_TEST_LOG_CASES")
  if log_cases == "0" then
    return
  end
  io.stdout:write("\n" .. text .. "\n")
  io.flush()
end

local function wait_for_async()
  local registry = _G.LOCI_TEST_ASYNC_PENDING
  if type(registry) ~= "table" or (registry.count or 0) == 0 then
    return
  end

  local timeout = tonumber(vim.env.LOCI_TEST_TIMEOUT_MS) or 15000
  local completed = vim.wait(timeout, function()
    return (registry.count or 0) == 0
  end, 10, false)

  if completed then
    return
  end

  for id, record in pairs(registry.records or {}) do
    local message = "async test timed out after " .. tostring(timeout) .. "ms"
    write_line("[loci-test] FAIL " .. tostring(record.name or ("async #" .. id)) .. " :: " .. message)
    if record.case and record.case.exec and type(record.case.exec.fails) == "table" then
      table.insert(record.case.exec.fails, message)
    end
  end
end

function M.new(opts)
  opts = opts or {}
  local MiniTest = require("mini.test")
  local base = MiniTest.gen_reporter.stdout({
    quit_on_finish = opts.quit_on_finish ~= false,
  })
  local cases = {}
  local seen_run = {}
  local seen_done = {}

  return {
    start = function(all_cases)
      cases = all_cases
      if not opts.no_base and base.start then
        base.start(all_cases)
      end
    end,

    update = function(case_num)
      local case = cases[case_num]
      if case then
        local state = case.exec and case.exec.state
        local name = case_name(case)

        if not seen_run[case_num] and type(state) == "string" and state:match("^Executing ") then
          seen_run[case_num] = true
          write_line("[loci-test] RUN " .. name .. " :: " .. state)
        end

        if not seen_done[case_num] and type(state) == "string"
            and (state:match("^Pass") or state:match("^Fail") or state:match("^Skip")) then
          seen_done[case_num] = true
          write_line("[loci-test] " .. state:upper() .. " " .. name)
        end
      end

      if not opts.no_base and base.update then
        base.update(case_num)
      end
    end,

    finish = function()
      wait_for_async()
      if not opts.no_base and base.finish then
        base.finish()
      end
      if type(opts.on_finish) == "function" then
        opts.on_finish()
      end
    end,
  }
end

return M
