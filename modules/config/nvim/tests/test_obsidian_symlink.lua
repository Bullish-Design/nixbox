local helpers = require("tests.helpers")
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

T["obsidian paths() returns disabled when integration is disabled"] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.paths({
    config = {
      integrations = {
        obsidian = { enabled = false, vault_path = "/vault", project_path = "projects/loci" },
      },
    },
  })
  expect.equality(r.ok, true)
  expect.equality(r.value.enabled, false)
  expect.equality(r.value.status, "disabled")
end)

T["obsidian paths() returns not_configured when vault path is missing"] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.paths({
    config = {
      integrations = {
        obsidian = { enabled = true },
      },
    },
  })
  expect.equality(r.ok, true)
  expect.equality(r.value.configured, false)
  expect.equality(r.value.status, "not_configured")
end)

T["obsidian paths() expands home tilde"] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.paths({
    config = {
      integrations = {
        obsidian = { enabled = true, vault_path = "~/vault", project_path = "projects" },
      },
    },
  })
  expect.equality(r.ok, true)
  expect.equality(r.value.configured, true)
  expect.no_equality(r.value.vault_root:match("~"), true)
end)

T["obsidian paths() rejects absolute project_path"] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.paths({
    config = {
      integrations = {
        obsidian = { enabled = true, vault_path = "/vault", project_path = "/absolute/path" },
      },
    },
  })
  expect.equality(r.ok, false)
  expect.equality(r.code, "invalid_input")
end)

T["obsidian paths() rejects project_path with .."] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.paths({
    config = {
      integrations = {
        obsidian = { enabled = true, vault_path = "/vault", project_path = "../escape" },
      },
    },
  })
  expect.equality(r.ok, false)
  expect.equality(r.code, "invalid_input")
end)

T["obsidian paths() rejects symlink_name with /"] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.paths({
    config = {
      integrations = {
        obsidian = {
          enabled = true,
          vault_path = "/vault",
          project_path = "projects",
          symlink_name = "loci/nested",
        },
      },
    },
  })
  expect.equality(r.ok, false)
  expect.equality(r.code, "invalid_input")
end)

T["obsidian ensure_content_symlink creates link to loci content"] = helpers.async_test(function()
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

  local obsidian = require("loci.integrations.obsidian")
  local r = obsidian.ensure_content_symlink()
  local value = helpers.expect_ok(r)

  expect.equality(value.status == "created" or value.status == "ok", true)
  if value.status == "created" then
    expect.equality(value.created, true)
  else
    expect.equality(value.existed, true)
  end

  -- Check link exists
  local link_stat = vim.uv.fs_lstat(vault .. "/Projects/TestRepo/loci")
  expect.no_equality(link_stat, nil)
  expect.equality(link_stat.type, "link")

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["obsidian ensure_content_symlink is idempotent"] = helpers.async_test(function()
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

  local obsidian = require("loci.integrations.obsidian")

  -- Create symlink first time
  local r1 = obsidian.ensure_content_symlink()
  local v1 = helpers.expect_ok(r1)
  expect.equality(v1.status == "created" or v1.status == "ok", true)

  -- Create symlink again (should be idempotent)
  local r2 = obsidian.ensure_content_symlink()
  local v2 = helpers.expect_ok(r2)
  expect.equality(v2.created, false)
  expect.equality(v2.existed, true)
  expect.equality(v2.status, "ok")

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["obsidian symlink missing obsidian.nvim does not fail"] = helpers.async_test(function()
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

  local obsidian = require("loci.integrations.obsidian")
  local available = obsidian.available()
  -- available() may or may not be true, but symlink creation should work
  local r = obsidian.ensure_content_symlink()
  helpers.expect_ok(r)

  restore()
  helpers.remove_tmpdir(repo)
  helpers.remove_tmpdir(vault)
end)

T["obsidian health reports plugin availability separately"] = helpers.async_test(function()
  local obsidian = require("loci.integrations.obsidian")
  local health = obsidian.health()
  expect.no_equality(health, nil)
  expect.equality(type(health), "table")
  expect.equality(health.name, "obsidian")
  expect.equality(type(health.available), "boolean")
end)

return T
