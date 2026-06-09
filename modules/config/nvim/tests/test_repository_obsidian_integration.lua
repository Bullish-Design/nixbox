local helpers = require("tests.helpers")
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

T["repository init delegates to obsidian adapter"] = helpers.async_test(function()
  local repo = helpers.create_tmpdir()
  local vault = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(repo)
  helpers.reset_modules()

  require("loci").setup({
    integrations = {
      obsidian = {
        enabled = true,
        vault_path = vault,
        project_path = "Projects/TestRepo",
        symlink_name = "loci",
      },
    },
  })

  local r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  local value = helpers.expect_ok(r)

  expect.equality(value.created, true)
  expect.no_equality(value.vault_symlink, nil)

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["repository init succeeds when vault not configured"] = helpers.async_test(function()
  local repo = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(repo)
  helpers.reset_modules()

  require("loci").setup({
    integrations = {
      obsidian = { enabled = false },
    },
  })

  local r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  local value = helpers.expect_ok(r)

  expect.equality(value.created, true)

  restore()
  helpers.remove_tmpdir(repo)
end)

T["repository init returns conflict when intended link path occupied"] = helpers.async_test(function()
  local repo = helpers.create_tmpdir()
  local vault = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(repo)
  helpers.reset_modules()

  -- Create conflicting file before init
  local conflict_path = vault .. "/Projects/TestRepo/loci"
  vim.fn.mkdir(vault .. "/Projects/TestRepo", "p")
  local f = io.open(conflict_path, "w")
  f:write("conflict")
  f:close()

  require("loci").setup({
    integrations = {
      obsidian = {
        enabled = true,
        vault_path = vault,
        project_path = "Projects/TestRepo",
        symlink_name = "loci",
      },
    },
  })

  local r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  expect.equality(r.ok, false)
  expect.equality(r.code, "conflict")

  -- Verify the conflicting file wasn't deleted
  expect.equality(vim.fn.filereadable(conflict_path), 1)

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["repository re-init with existing correct symlink succeeds"] = helpers.async_test(function()
  local repo = helpers.create_tmpdir()
  local vault = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(repo)
  helpers.reset_modules()

  require("loci").setup({
    integrations = {
      obsidian = {
        enabled = true,
        vault_path = vault,
        project_path = "Projects/TestRepo",
        symlink_name = "loci",
      },
    },
  })

  -- First init
  local r1 = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(r1)

  -- Reset modules for second init
  helpers.reset_modules()
  helpers.ensure_main()
  require("loci").setup({
    integrations = {
      obsidian = {
        enabled = true,
        vault_path = vault,
        project_path = "Projects/TestRepo",
        symlink_name = "loci",
      },
    },
  })

  -- Second init should succeed (not a conflict)
  local r2 = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(r2)

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["repository re-init recreates missing symlink"] = helpers.async_test(function()
  local repo = helpers.create_tmpdir()
  local vault = helpers.create_tmpdir()
  local restore = helpers.patch_project_root(repo)
  helpers.reset_modules()

  require("loci").setup({
    integrations = {
      obsidian = {
        enabled = true,
        vault_path = vault,
        project_path = "Projects/TestRepo",
        symlink_name = "loci",
      },
    },
  })

  -- First init creates symlink
  local r1 = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(r1)
  local symlink_path = vault .. "/Projects/TestRepo/loci"
  expect.equality(vim.fn.resolve(symlink_path) ~= symlink_path, true) -- Verify symlink exists

  -- Delete the symlink
  helpers.expect_ok(require("loci.store.fs").unlink(symlink_path))
  expect.equality(vim.fn.isdirectory(symlink_path), 0) -- Verify symlink is deleted

  -- Reset modules and reinit
  helpers.reset_modules()
  helpers.ensure_main()
  require("loci").setup({
    integrations = {
      obsidian = {
        enabled = true,
        vault_path = vault,
        project_path = "Projects/TestRepo",
        symlink_name = "loci",
      },
    },
  })

  -- Reinit should recreate the symlink
  local r2 = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  local v2 = helpers.expect_ok(r2)
  expect.equality(v2.created, false) -- It's a reinit, not a fresh create

  -- Verify symlink was recreated and points to correct target
  expect.equality(vim.fn.resolve(symlink_path) ~= symlink_path, true) -- Verify symlink exists
  local target = vim.fn.resolve(symlink_path)
  local content_path = repo .. "/.loci/content"
  expect.equality(vim.fs.normalize(target), vim.fs.normalize(content_path))

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

return T
