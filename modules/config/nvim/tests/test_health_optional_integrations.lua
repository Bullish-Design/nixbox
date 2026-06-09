-- Test health checks for optional integrations

local H = require('tests.helpers')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()

local function before_test()
  H.reset_modules()
  require('loci.config').reset()
end

T['Health: Disabled integration shows as disabled'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    -- Disable haunt integration
    require('loci.config').setup({
      integrations = {
        haunt = { enabled = false },
      }
    })

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Should have info status for disabled integration
    local haunt_item = H.find_health_item(report, "haunt_disabled")
    expect.no_equality(haunt_item, nil)
    expect.equality(haunt_item.status, "info")
  end)
end)

T['Health: Multiple disabled integrations each reported'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    -- Disable multiple integrations
    require('loci.config').setup({
      integrations = {
        haunt     = { enabled = false },
        wayfinder = { enabled = false },
        obsidian  = { enabled = false },
      }
    })

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Check each disabled integration
    expect.no_equality(H.find_health_item(report, "haunt_disabled"), nil)
    expect.no_equality(H.find_health_item(report, "wayfinder_disabled"), nil)
    expect.no_equality(H.find_health_item(report, "obsidian_disabled"), nil)
  end)
end)

T['Health: Integration checks are performed'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    require('loci.config').setup({
      integrations = {
        haunt = { enabled = true },
        tabby = { enabled = true },
      }
    })

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Check that report has sections
    expect.no_equality(report.sections, nil)
    expect.equality(type(report.sections), "table")
    expect.equality(#report.sections > 0, true)
  end)
end)

T['Health: Health check returns proper result type'] = function()
  before_test()

  local tmpdir = H.create_tmpdir()
  local restore = H.patch_project_root(tmpdir)
  H.init_loci_dir(tmpdir)

  local health = require('loci.health')
  local result_r = health.collect({ root = tmpdir })

  -- Result should be a Result type with ok and value
  expect.equality(result_r.ok, true)
  expect.no_equality(result_r.value, nil)
  expect.equality(type(result_r.value), "table")

  restore()
  H.remove_tmpdir(tmpdir)
end

return T
