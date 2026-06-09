-- Test health checks with missing critical files

local H = require('tests.helpers')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()

local function before_test()
  H.reset_modules()
  require('loci.config').reset()
end

T['Health: Missing .loci directory reports error'] = H.async_test(function()
  before_test()

  local tmpdir = H.create_tmpdir()
  local restore = H.patch_project_root(tmpdir)

  -- Don't initialize .loci
  local health = require('loci.health')
  local result_r = health.collect({ root = tmpdir })

  expect.equality(result_r.ok, true)
  local report = result_r.value

  -- Should have error for missing loci_root
  expect.no_equality(H.find_health_item(report, "loci_root_missing"), nil)
  H.expect_health_status(report, "loci_root_missing", "error")

  restore()
  H.remove_tmpdir(tmpdir)
end)

T['Health: Missing loci.json reports error'] = H.async_test(function()
  before_test()

  local tmpdir = H.create_tmpdir()
  local restore = H.patch_project_root(tmpdir)
  local loci_root = tmpdir .. "/.loci"
  vim.fn.mkdir(loci_root, "p")

  -- Create .loci but no loci.json
  local health = require('loci.health')
  local result_r = health.collect({ root = tmpdir })

  expect.equality(result_r.ok, true)
  local report = result_r.value

  -- Should have error for missing loci.json
  expect.no_equality(H.find_health_item(report, "loci_json_missing"), nil)
  H.expect_health_status(report, "loci_json_missing", "error")

  restore()
  H.remove_tmpdir(tmpdir)
end)

T['Health: Malformed loci.json reports error'] = H.async_test(function()
  before_test()

  local tmpdir = H.create_tmpdir()
  local restore = H.patch_project_root(tmpdir)
  local loci_root = H.init_loci_dir(tmpdir)

  -- Write invalid JSON to loci.json
  H.write_invalid_json(loci_root .. "/loci.json", "{ invalid json ]")

  local health = require('loci.health')
  local result_r = health.collect({ root = tmpdir })

  expect.equality(result_r.ok, true)
  local report = result_r.value

  -- Should have error for decode failure
  expect.no_equality(H.find_health_item(report, "loci_json_decode_failed"), nil)
  H.expect_health_status(report, "loci_json_decode_failed", "error")

  restore()
  H.remove_tmpdir(tmpdir)
end)

T['Health: Missing repository.json reports error'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    -- Remove repository.json
    H.remove_file(ctx.loci_root .. "/repository.json")

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Should have error for missing repository.json
    expect.no_equality(H.find_health_item(report, "repository_json_missing"), nil)
    H.expect_health_status(report, "repository_json_missing", "error")
  end)
end)

T['Health: Missing graph/current.json reports error'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    -- Remove graph/current.json
    H.remove_file(ctx.loci_root .. "/graph/current.json")

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Should have error for missing current.json
    expect.no_equality(H.find_health_item(report, "current_json_missing"), nil)
    H.expect_health_status(report, "current_json_missing", "error")
  end)
end)

T['Health: Missing fallback workspace reports error'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    -- Remove fallback workspace file
    H.remove_file(ctx.loci_root .. "/graph/workspaces/" .. ctx.fallback_workspace.workspace_id .. ".json")

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Should have error for missing fallback workspace
    expect.no_equality(H.find_health_item(report, "fallback_workspace_missing"), nil)
    H.expect_health_status(report, "fallback_workspace_missing", "error")
  end)
end)

T['Health: Missing required directories reported'] = H.async_test(function()
  before_test()

  H.with_health_repo(function(ctx)
    -- Remove content directory
    vim.fn.delete(ctx.loci_root .. "/content", "rf")

    local health = require('loci.health')
    local result_r = health.collect({ root = ctx.tmpdir })

    expect.equality(result_r.ok, true)
    local report = result_r.value

    -- Should have error for missing content dir
    expect.no_equality(H.find_health_item(report, "content_dir_missing"), nil)
    H.expect_health_status(report, "content_dir_missing", "error")

    -- Should still have other dirs
    expect.no_equality(H.find_health_item(report, "graph_dir_exists"), nil)
    expect.no_equality(H.find_health_item(report, "indexes_dir_exists"), nil)
  end)
end)

return T
