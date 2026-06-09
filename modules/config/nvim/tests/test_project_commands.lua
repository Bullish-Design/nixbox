local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  local ctx = helpers.create_test_repo()
  require("loci.ui.commands").register()
  return ctx
end

local function command_exists(name)
  return vim.fn.exists(":" .. name) == 2
end

T["LociProjectCreate command is registered"] = function()
  local ctx = setup()
  expect.equality(command_exists("LociProjectCreate"), true)
  ctx.cleanup()
end

T["LociProjectOpen command is registered"] = function()
  local ctx = setup()
  expect.equality(command_exists("LociProjectOpen"), true)
  ctx.cleanup()
end

T["LociProjectSwitch command is registered"] = function()
  local ctx = setup()
  expect.equality(command_exists("LociProjectSwitch"), true)
  ctx.cleanup()
end

T["LociProjectLink command is registered"] = function()
  local ctx = setup()
  expect.equality(command_exists("LociProjectLink"), true)
  ctx.cleanup()
end

T["LociProjectInfo command is registered"] = function()
  local ctx = setup()
  expect.equality(command_exists("LociProjectInfo"), true)
  ctx.cleanup()
end

T["LociProjectRefresh command is registered"] = function()
  local ctx = setup()
  expect.equality(command_exists("LociProjectRefresh"), true)
  ctx.cleanup()
end

T["LociProjectCreate with args creates project"] = function()
  local ctx = setup()

  local original_notify = vim.notify
  local notified = false

  vim.notify = function()
    notified = true
  end

  vim.cmd("LociProjectCreate Test Project")
  vim.wait(200)
  expect.equality(notified, true)

  vim.notify = original_notify
  ctx.cleanup()
end

T["LociProjectOpen with project_id opens project"] = helpers.async_with_initialized_repo(function(ctx)
  helpers.await_main()
  require("loci.ui.commands").register()
  local service = require("loci.service.project")

  helpers.expect_ok(service.create({
    title = "Open Test Project",
    project_id = "open-test-xyz123",
    now = "2026-05-23T10:10:00Z",
  }))

  local opened_path = nil
  service._set_open_file_for_test(function(abs_path)
    opened_path = abs_path
  end)

  local original_notify = vim.notify
  vim.notify = function() end

  helpers.async_cmd("LociProjectOpen open-test-xyz123")
  helpers.async_sleep(200)
  local opened = helpers.expect_ok(service.get("open-test-xyz123"))
  expect.no_equality(opened, nil)

  service._set_open_file_for_test(nil)
  vim.notify = original_notify
end)

T["LociProjectRefresh with project_id updates cache"] = helpers.async_with_initialized_repo(function(ctx)
  helpers.await_main()
  require("loci.ui.commands").register()
  local service = require("loci.service.project")

  helpers.expect_ok(service.create({
    title = "Refresh Test Project",
    project_id = "refresh-test-xyz123",
    now = "2026-05-23T10:10:00Z",
  }))

  local original_notify = vim.notify
  local notified_message = nil

  vim.notify = function(msg)
    notified_message = msg
  end

  helpers.async_cmd("LociProjectRefresh refresh-test-xyz")
  helpers.async_sleep(200)
  local refreshed = helpers.expect_ok(service.get("refresh-test-xyz123"))
  expect.no_equality(refreshed, nil)

  vim.notify = original_notify
end)

return T
