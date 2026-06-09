local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      helpers.reset_modules()
    end,
  },
})

T['get() returns canonical defaults before setup'] = function()
  local config = require('loci.config')
  config.reset()
  local cfg = config.get()
  expect.equality(cfg.version, 1)
  expect.equality(cfg.integrations.tasknotes.enabled, true)
  expect.equality(cfg.integrations.obsidian.enabled, true)
  expect.equality(cfg.integrations.haunt.enabled, true)
  expect.equality(cfg.integrations.wayfinder.enabled, true)
  expect.equality(cfg.integrations.wayfinder.require_named_api, true)
  expect.equality(cfg.integrations.resession.enabled, true)
  expect.equality(cfg.integrations.tabby.enabled, true)
  expect.equality(cfg.refresh.default_mode, 'strict')
end

T['setup() merges overrides with defaults'] = function()
  local config = require('loci.config')
  config.reset()
  config.setup({
    integrations = {
      tasknotes = { enabled = false },
    },
  })
  local cfg = config.get()
  -- Overridden field.
  expect.equality(cfg.integrations.tasknotes.enabled, false)
  -- Non-overridden fields retain defaults.
  expect.equality(cfg.integrations.haunt.enabled, true)
  expect.equality(cfg.integrations.wayfinder.enabled, true)
  expect.equality(cfg.version, 1)
end

T['setup() with empty opts uses defaults'] = function()
  local config = require('loci.config')
  config.reset()
  config.setup({})
  local cfg = config.get()
  expect.equality(cfg.version, 1)
  expect.equality(cfg.integrations.haunt.enabled, true)
end

T['setup() with nil opts uses defaults'] = function()
  local config = require('loci.config')
  config.reset()
  config.setup()
  local cfg = config.get()
  expect.equality(cfg.version, 1)
  expect.equality(cfg.integrations.wayfinder.enabled, true)
end

T['all integrations are enabled by default'] = function()
  local config = require('loci.config')
  config.reset()
  local cfg = config.get()
  for _, key in ipairs({ 'tasknotes', 'obsidian', 'haunt', 'wayfinder', 'resession', 'tabby' }) do
    expect.equality(type(cfg.integrations[key]), 'table', key .. ' must be a table')
    expect.equality(cfg.integrations[key].enabled, true, key .. '.enabled must be true')
  end
end

T['setup() can disable individual integrations'] = function()
  local config = require('loci.config')
  config.reset()
  config.setup({
    integrations = {
      haunt     = { enabled = false },
      wayfinder = { enabled = false, require_named_api = false },
    },
  })
  local cfg = config.get()
  expect.equality(cfg.integrations.haunt.enabled, false)
  expect.equality(cfg.integrations.wayfinder.enabled, false)
  -- Others remain enabled.
  expect.equality(cfg.integrations.resession.enabled, true)
  expect.equality(cfg.integrations.tasknotes.enabled, true)
end

T['defaults() returns a copy'] = function()
  local config = require('loci.config')
  local d = config.defaults()
  d.integrations.haunt.enabled = false
  local d2 = config.defaults()
  expect.equality(d2.integrations.haunt.enabled, true)
end

T['setup() with invalid config raises an error'] = function()
  local config = require('loci.config')
  config.reset()
  local ok, err = pcall(function()
    config.setup({ integrations = { haunt = { enabled = "not-a-bool" } } })
  end)
  expect.equality(ok, false)
  expect.equality(type(err), 'string')
end

T['tasknotes config accepts optional vault_path'] = function()
  local config = require('loci.config')
  config.reset()
  config.setup({
    integrations = {
      tasknotes = { enabled = true, vault_path = '/some/path' },
    },
  })
  local cfg = config.get()
  expect.equality(cfg.integrations.tasknotes.vault_path, '/some/path')
end

return T
