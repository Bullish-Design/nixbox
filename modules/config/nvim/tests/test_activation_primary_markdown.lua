local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("tests.helpers")

local T = MiniTest.new_set()

local function setup()
  helpers.reset_modules()
end

T["activation opens primary Markdown when session appears empty"] = function()
  local ctx = helpers.create_phase6_fixture({
    now = function() return "2026-05-23T10:00:00Z" end,
    with_primary_markdown = true,
  })
  setup()

  local test_fn = helpers.async_test(function()
    -- Ensure no buffers
    vim.cmd.enew()

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, {
      notify = false,
      open_primary = true,
    })
    local value = helpers.expect_ok(r)

    -- Check that primary was opened
    expect.equality(value.opened_primary, true)

    -- Verify buffer is open with the primary markdown
    helpers.ensure_main()
    local buf_path = vim.api.nvim_buf_get_name(0)
    helpers.expect_match(buf_path, "primary%-task%.md")
  end)

  test_fn()
  ctx.cleanup()
end

T["activation does not open primary Markdown when open_primary = false"] = function()
  local ctx = helpers.create_phase6_fixture({
    now = function() return "2026-05-23T10:00:00Z" end,
    with_primary_markdown = true,
  })
  setup()

  local test_fn = helpers.async_test(function()
    vim.cmd.enew()

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, {
      notify = false,
      open_primary = false,
    })
    local value = helpers.expect_ok(r)

    expect.equality(value.opened_primary, false)
  end)

  test_fn()
  ctx.cleanup()
end

T["activation does not fail when primary Markdown is missing"] = function()
  local ctx = helpers.create_phase6_fixture({
    now = function() return "2026-05-23T10:00:00Z" end,
    with_primary_markdown = false,
  })
  setup()

  local test_fn = helpers.async_test(function()
    vim.cmd.enew()

    local activation = require("loci.service.activation")

    local r = activation.activate(ctx.workspace.workspace_id, {
      notify = false,
      open_primary = true,
    })
    local value = helpers.expect_ok(r)

    -- Should succeed even without primary markdown
    expect.equality(value.opened_primary, false)
  end)

  test_fn()
  ctx.cleanup()
end

return T
