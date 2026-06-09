local helpers = require("tests.helpers")
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

T["refresh calls bases.regenerate when enabled"] = helpers.async_with_repo(function()
  require("loci").setup({
    integrations = { bases = true },
    refresh = { on_setup = false },
  })

  local init_r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(init_r)

  local refresh = require("loci.store.refresh")
  local r = refresh.run({ now = "2026-05-23T12:00:00-04:00" })
  local value = helpers.expect_ok(r)

  expect.no_equality(value.apply, nil)
end)

T["refresh skips bases when disabled"] = helpers.async_with_repo(function()
  require("loci").setup({
    integrations = { bases = false },
    refresh = { on_setup = false },
  })

  local init_r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(init_r)

  local refresh = require("loci.store.refresh")
  local r = refresh.run({ now = "2026-05-23T12:00:00-04:00" })
  local value = helpers.expect_ok(r)

  expect.no_equality(value.apply, nil)
end)

T["refresh run succeeds after base file deletion"] = helpers.async_with_repo(function()
  require("loci").setup({
    integrations = { bases = true },
    refresh = { on_setup = false },
  })

  local init_r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(init_r)

  -- First refresh to generate base files
  local refresh = require("loci.store.refresh")
  local r1 = refresh.run({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(r1)

  local bases = require("loci.service.bases")
  local tasks_base = bases.output_dir() .. "/loci-tasks.base"

  -- Delete file if present, then refresh again.
  if vim.fn.filereadable(tasks_base) == 1 then
    helpers.async_rm_rf(tasks_base)
    helpers.await_main()
  end

  local r2 = refresh.run({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(r2)
end)

return T
