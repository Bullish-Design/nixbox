local helpers = require("tests.helpers")
local MiniTest = require("mini.test")
local expect = MiniTest.expect
local fs = require("loci.store.fs")

local T = MiniTest.new_set()

T["obsidian conflict: existing file at link path"] = helpers.async_test(function()
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

  local init_r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(init_r)

  helpers.expect_ok(require("loci.store.fs").unlink(vault .. "/Projects/TestRepo/loci"))

  -- Create a file at the intended link path
  local project_path = vault .. "/Projects/TestRepo"
  helpers.expect_ok(fs.mkdir_p(project_path))
  local conflict_file = project_path .. "/loci"
  helpers.expect_ok(fs.write_file(conflict_file, "existing file"))

  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.ensure_content_symlink()
  expect.equality(r.ok, false)
  expect.equality(r.code, "conflict")

  -- Verify the existing file wasn't deleted
  expect.equality(vim.fn.filereadable(conflict_file), 1)

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["obsidian conflict: existing directory at link path"] = helpers.async_test(function()
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

  local init_r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(init_r)

  helpers.expect_ok(require("loci.store.fs").unlink(vault .. "/Projects/TestRepo/loci"))

  -- Create a directory at the intended link path
  local conflict_dir = vault .. "/Projects/TestRepo/loci"
  helpers.expect_ok(fs.mkdir_p(conflict_dir))

  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.ensure_content_symlink()
  expect.equality(r.ok, false)
  expect.equality(r.code, "conflict")

  -- Verify the existing directory wasn't deleted
  expect.equality(vim.fn.isdirectory(conflict_dir), 1)

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["obsidian conflict: existing symlink to wrong target"] = helpers.async_test(function()
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

  local init_r = require("loci.service.repository").init({ now = "2026-05-23T12:00:00-04:00" })
  helpers.expect_ok(init_r)

  helpers.expect_ok(require("loci.store.fs").unlink(vault .. "/Projects/TestRepo/loci"))

  -- Create a symlink to a different target
  local project_path = vault .. "/Projects/TestRepo"
  helpers.expect_ok(fs.mkdir_p(project_path))
  local wrong_target = vault .. "/other-place"
  helpers.expect_ok(fs.mkdir_p(wrong_target))
  vim.uv.fs_symlink(wrong_target, project_path .. "/loci")

  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.ensure_content_symlink()
  expect.equality(r.ok, false)
  expect.equality(r.code, "conflict")

  -- Verify the existing symlink wasn't deleted
  local stat = vim.uv.fs_lstat(project_path .. "/loci")
  expect.equality(stat.type, "link")

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

return T
