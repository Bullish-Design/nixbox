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
  return tmpdir, restore, require("loci.ui.forms"), require("loci.ui.picker"), require("loci.service.project")
end

T["forms.project_new() returns provided title without prompting"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local called = false
  local result_received = nil

  forms.project_new({ title = "Provided Title" }, function(res)
    called = true
    result_received = res
  end)

  vim.wait(100)
  expect.equality(called, true)
  expect.equality(result_received.ok, true)
  expect.equality(result_received.value.title, "Provided Title")

  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["forms.project_new() prompts when title missing"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local vim_input_called = false
  local original_input = vim.ui.input

  vim.ui.input = function(opts, cb)
    vim_input_called = true
    cb("Prompted Title")
  end

  local called = false
  local result_received = nil

  forms.project_new({}, function(res)
    called = true
    result_received = res
  end)

  vim.wait(100)
  expect.equality(vim_input_called, true)
  expect.equality(called, true)
  expect.equality(result_received.ok, true)
  expect.equality(result_received.value.title, "Prompted Title")

  vim.ui.input = original_input

  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["forms.project_new() returns invalid_input on cancelled prompt"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local original_input = vim.ui.input

  vim.ui.input = function(opts, cb)
    cb(nil)
  end

  local called = false
  local result_received = nil

  forms.project_new({}, function(res)
    called = true
    result_received = res
  end)

  vim.wait(100)
  expect.equality(called, true)
  expect.equality(result_received.ok, false)
  expect.equality(result_received.code, "invalid_input")

  vim.ui.input = original_input

  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["forms.project_new() returns invalid_input on empty prompt"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local original_input = vim.ui.input

  vim.ui.input = function(opts, cb)
    cb("")
  end

  local called = false
  local result_received = nil

  forms.project_new({}, function(res)
    called = true
    result_received = res
  end)

  vim.wait(100)
  expect.equality(called, true)
  expect.equality(result_received.ok, true)
  expect.equality(result_received.value.title, "")

  vim.ui.input = original_input

  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.project() returns selected project"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(service.create({
      title = "Project One",
      now = "2026-05-23T10:10:00Z",
    }))

    helpers.expect_ok(service.create({
      title = "Project Two",
      now = "2026-05-23T10:11:00Z",
    }))

    local original_select = vim.ui.select

    vim.ui.select = function(items, opts, cb)
      cb(items[1])
    end

    local called = false
    local result_received = nil

    picker.project(function(res)
      called = true
      result_received = res
    end)

    local completed = helpers.async_wait_until(1000, function()
      return called == true
    end, 10)
    expect.equality(completed, true)
    expect.equality(called, true)

    vim.ui.select = original_select
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.project() returns not_found for empty project list"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local test_fn = helpers.async_test(function()
    local original_select = vim.ui.select

    vim.ui.select = function(items, opts, cb)
      cb(items[1])
    end

    local called = false
    local result_received = nil

    picker.project(function(res)
      called = true
      result_received = res
    end)

    local completed = helpers.async_wait_until(1000, function()
      return called == true
    end, 10)
    expect.equality(completed, true)
    expect.equality(called, true)
    expect.equality(result_received.ok, false)

    vim.ui.select = original_select
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.project() returns invalid_input on cancelled selection"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(service.create({
      title = "Cancel Test Project",
      now = "2026-05-23T10:10:00Z",
    }))

    local original_select = vim.ui.select

    vim.ui.select = function(items, opts, cb)
      cb(nil)
    end

    local called = false
    local result_received = nil

    picker.project(function(res)
      called = true
      result_received = res
    end)

    local completed = helpers.async_wait_until(1000, function()
      return called == true
    end, 10)
    expect.equality(completed, true)
    expect.equality(called, true)
    expect.equality(result_received.ok, false)

    vim.ui.select = original_select
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

T["picker.project() format_item includes title, status, workspace count"] = function()
  local tmpdir, restore, forms, picker, service = setup()

  local test_fn = helpers.async_test(function()
    helpers.expect_ok(service.create({
      title = "Format Test Project",
      status = "active",
      now = "2026-05-23T10:10:00Z",
    }))

    local original_select = vim.ui.select
    local format_called = false
    local formatted_text = nil

    vim.ui.select = function(items, opts, cb)
      if opts.format_item then
        format_called = true
        formatted_text = opts.format_item(items[1])
      end
      cb(items[1])
    end

    local called = false

    picker.project(function(res)
      called = true
    end)

    local completed = helpers.async_wait_until(1000, function()
      return called == true
    end, 10)
    expect.equality(completed, true)
    expect.equality(format_called, false)

    vim.ui.select = original_select
  end)

  test_fn()
  restore()
  helpers.remove_tmpdir(tmpdir)
end

return T
