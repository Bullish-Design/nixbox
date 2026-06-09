local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
  local tmpdir = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(tmpdir)
  require("loci.config").setup({ refresh = { on_setup = false } })
  helpers.init_loci_dir(tmpdir)
  return tmpdir, restore, require("loci.ui.picker"), require("loci.service.project")
end

T["picker backend is vim_ui_select"] = function()
  local tmpdir, restore, picker = setup()

  local test_fn = helpers.async_test(function()
    expect.equality(picker._backend_name(), "vim_ui_select")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.project() calls refresh when configured"] = function()
  local tmpdir, restore, picker, service = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(service.create({
      title = "Refresh Test Project",
      now = "2026-05-23T10:10:00Z",
    }))

    -- Stub refresh.run to verify it's called
    local refresh = require("loci.store.refresh")
    local original_run = refresh.run
    local refresh_called = false

    refresh.run = function(opts)
      refresh_called = true
      return original_run(opts)
    end

    local original_select = vim.ui.select

    vim.ui.select = function(items, opts, cb)
      cb(items[1])
    end

    local called = false

    -- Call with refresh enabled
    picker.project(function(res)
      called = true
    end, { refresh = true })

    helpers.async_sleep(100)
    expect.equality(refresh_called, true)
    expect.equality(called, true)

    vim.ui.select = original_select
    refresh.run = original_run
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.project() skips refresh when false"] = function()
  local tmpdir, restore, picker, service = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(service.create({
      title = "No Refresh Project",
      now = "2026-05-23T10:10:00Z",
    }))

    local refresh = require("loci.store.refresh")
    local original_run = refresh.run
    local refresh_called = false

    refresh.run = function(opts)
      refresh_called = true
      return original_run(opts)
    end

    local original_select = vim.ui.select

    vim.ui.select = function(items, opts, cb)
      cb(items[1])
    end

    local called = false

    -- Call with refresh disabled
    picker.project(function(res)
      called = true
    end, { refresh = false })

    helpers.async_sleep(100)
    expect.equality(refresh_called, false)
    expect.equality(called, true)

    vim.ui.select = original_select
    refresh.run = original_run
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.workspace() calls refresh when configured"] = function()
  local tmpdir, restore, picker, service = setup()

  local test_fn = helpers.async_test(function()
    local workspace_service = require("loci.service.workspace")
    helpers.expect_ok(workspace_service.create({ name = "Test Workspace" }))

    local refresh = require("loci.store.refresh")
    local original_run = refresh.run
    local refresh_called = false

    refresh.run = function(opts)
      refresh_called = true
      return original_run(opts)
    end

    local original_select = vim.ui.select

    vim.ui.select = function(items, opts, cb)
      if items and #items > 0 then
        cb(items[1])
      else
        cb(nil)
      end
    end

    local called = false

    picker.workspace(function(res)
      called = true
    end, { refresh = true })

    helpers.async_sleep(100)
    expect.equality(refresh_called, true)
    expect.equality(called, true)

    vim.ui.select = original_select
    refresh.run = original_run
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker._select() test seam exists"] = function()
  local tmpdir, restore, picker, service = setup()

  local test_fn = helpers.async_test(function()
    expect.equality(type(picker._select), "function")
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker._select() uses vim.ui.select canonical backend"] = function()
  local tmpdir, restore, picker, service = setup()

  local test_fn = helpers.async_test(function()
    local old_select = vim.ui.select

    local ui_select_called = false
    local selected
    vim.ui.select = function(items, opts, cb)
      ui_select_called = true
      if items and #items > 0 then
        cb(items[1])
      end
    end

    picker._select({
      { label = "one", id = "one" },
    }, {
      prompt = "Pick",
      format_item = function(item) return item.label end,
    }, function(r)
      selected = helpers.expect_ok(r)
    end)

    helpers.async_sleep(10)
    expect.equality(ui_select_called, true)
    expect.equality(selected.id, "one")

    vim.ui.select = old_select
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
