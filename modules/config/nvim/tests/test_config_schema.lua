local MiniTest = require('mini.test')
local helpers = require('tests.helpers')
local T = MiniTest.new_set({})

T['config defaults validate'] = function()
  local config_domain = require('loci.domain.config')
  local defaults_r = config_domain.canonical_defaults()
  helpers.expect_ok(defaults_r)
  helpers.expect_ok(config_domain.validate(defaults_r.value))
end

return T
