-- Test health checks on a clean, properly initialized repository

local H = require('tests.helpers')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()

-- Before each test: reset modules and config
local function before_test()
  H.reset_modules()
  require('loci.config').reset()
end

T['Health: Clean repository has no errors'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')
    local result_r = health.collect()

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Should have no errors in a clean repo
    expect.equality(report.counts.error, 0)

    -- Should be marked as ok
    expect.equality(report.ok, true)

    -- Should have repository section
    expect.equality(vim.tbl_contains(report.sections, "Repository"), true)

    -- Should have graph section
    expect.equality(vim.tbl_contains(report.sections, "Graph"), true)
  end)
end)

T['Health: Clean repo has repository checks'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')
    local result_r = health.collect()
    local report = result_r.value

    -- Check repository items
    expect.no_equality(H.find_health_item(report, "repository_root_resolved"), nil)
    expect.no_equality(H.find_health_item(report, "loci_root_exists"), nil)
    expect.no_equality(H.find_health_item(report, "loci_json_valid"), nil)
    expect.no_equality(H.find_health_item(report, "repository_json_valid"), nil)
  end)
end)

T['Health: Clean repo has valid graph'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')
    local result_r = health.collect()
    local report = result_r.value

    -- Check graph items
    expect.no_equality(H.find_health_item(report, "current_json_valid"), nil)
    expect.no_equality(H.find_health_item(report, "fallback_workspace_exists"), nil)
    expect.no_equality(H.find_health_item(report, "current_workspace_valid"), nil)
  end)
end)

T['Health: Report has correct structure'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')
    local result_r = health.collect()
    local report = result_r.value

    -- Verify report structure
    expect.no_equality(report.root, nil)
    expect.no_equality(report.loci_root, nil)
    expect.no_equality(report.generated_at, nil)
    expect.no_equality(report.ok, nil)
    expect.no_equality(report.counts, nil)
    expect.no_equality(report.items, nil)
    expect.no_equality(report.sections, nil)

    -- Verify counts structure
    expect.equality(type(report.counts.ok), 'number')
    expect.equality(type(report.counts.warn), 'number')
    expect.equality(type(report.counts.error), 'number')
    expect.equality(type(report.counts.info), 'number')
  end)
end)

T['Health: All items have required fields'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    local health = require('loci.health')
    local result_r = health.collect()
    local report = result_r.value

    for _, item in ipairs(report.items) do
      expect.no_equality(item.section, nil)
      expect.no_equality(item.status, nil)
      expect.no_equality(item.code, nil)
      expect.no_equality(item.message, nil)

      -- Status should be one of the valid values
      local valid_status = item.status == "ok" or item.status == "warn" or
        item.status == "error" or item.status == "info"
      expect.equality(valid_status, true)
    end
  end)
end)

return T
