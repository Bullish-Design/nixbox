-- Test that the :LociHealth command invokes the health provider

local H = require('tests.helpers')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()

local function before_test()
  H.reset_modules()
  require('loci.config').reset()
end

T['Health: LociHealth command is registered'] = function()
  before_test()

  -- Register commands
  require('loci.ui.commands').register()

  -- Check that LociHealth command exists
  local cmd = vim.api.nvim_get_commands({})['LociHealth']
  expect.no_equality(cmd, nil)
  expect.no_equality(cmd.definition, nil)
end

T['Health: check() function renders without error'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')

    -- Call check() which should render via vim.health
    local ok, result = pcall(health.check)
    expect.equality(ok, true)
  end)
end)

T['Health: collect() returns structured data'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')

    local result_r = health.collect()
    expect.equality(result_r.ok, true)

    local report = result_r.value
    expect.no_equality(report, nil)
    expect.no_equality(report.items, nil)
    expect.no_equality(report.counts, nil)
  end)
end)

T['Health: Deterministic now parameter works'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')

    local fixed_time = "2026-05-23T12:00:00Z"
    local result_r = health.collect({ now = fixed_time })

    expect.equality(result_r.ok, true)
    local report = result_r.value
    expect.equality(report.generated_at, fixed_time)
  end)
end)

T['Health: Custom root parameter works'] = function()
  before_test()

  local tmpdir = H.create_tmpdir()
  local restore = H.patch_project_root(tmpdir)
  H.init_loci_dir(tmpdir)

  local health = require('loci.health')
  local result_r = health.collect({ root = tmpdir })

  expect.equality(result_r.ok, true)
  local report = result_r.value
  expect.equality(report.root, tmpdir)

  restore()
  H.remove_tmpdir(tmpdir)
end

return T
