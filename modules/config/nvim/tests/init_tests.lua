local MiniTest = require("mini.test")

local M = {}

local function all_test_files()
  local tests = {}
  vim.list_extend(tests, vim.fn.globpath("tests", "test_*.lua", false, true))
  vim.list_extend(tests, vim.fn.globpath("tests/unit", "**/test_*.lua", false, true))
  table.sort(tests)
  return tests
end

local function case_failed(case)
  return case.exec and type(case.exec.fails) == "table" and #case.exec.fails > 0
end

local function run_cases(cases)
  local failed = false
  local fail_count = 0

  io.stdout:write(string.format("LOCI serial test run: %d case(s)\n", #cases))
  io.stdout:flush()

  for _, case in ipairs(cases) do
    local done = false
    MiniTest.execute({ case }, {
      reporter = require("tests.loci_reporter").new({
        no_base = true,
        quit_on_finish = false,
        on_finish = function()
          done = true
        end,
      }),
    })
    vim.wait(tonumber(vim.env.LOCI_TEST_TIMEOUT_MS) or 15000, function()
      return done
    end, 10, false)

    if case_failed(case) then
      failed = true
      fail_count = fail_count + 1
    end
  end

  io.stdout:write(string.format("\nLOCI serial test summary: %d case(s), %d fail(s)\n", #cases, fail_count))
  io.stdout:flush()
  vim.cmd(string.format("silent! %scquit", failed and 1 or 0))
end

function M.collect_files(files)
  local file_set = {}
  for _, file in ipairs(files) do
    file_set[file] = true
  end

  return MiniTest.collect({
    find_files = function()
      return vim.deepcopy(files)
    end,
    filter_cases = function(case)
      return file_set[case.desc[1]] == true
    end,
  })
end

function M.run_all()
  run_cases(M.collect_files(all_test_files()))
end

function M.run_file(file)
  run_cases(M.collect_files({ file }))
end

return M
