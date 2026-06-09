-- Minimal Neovim init for running loci tests

vim.env.XDG_STATE_HOME = vim.env.XDG_STATE_HOME or '/tmp/loci-nvim-state'
vim.env.XDG_CACHE_HOME = vim.env.XDG_CACHE_HOME or '/tmp/loci-nvim-cache'
vim.g.loci_test_disable_neoconf = true
vim.fn.mkdir(vim.env.XDG_STATE_HOME, 'p')
vim.fn.mkdir(vim.env.XDG_CACHE_HOME, 'p')

-- Add the plugin to runtimepath
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.runtimepath:prepend(plugin_root)
package.path = table.concat({
  plugin_root .. '/?.lua',
  plugin_root .. '/?/init.lua',
  package.path,
}, ';')

package.preload['tests.helpers'] = function()
  return dofile(plugin_root .. '/tests/helpers.lua')
end

-- Ensure mini.nvim is available in both vim.pack and lazy-like layouts.
pcall(vim.cmd, 'packadd mini.nvim')
pcall(vim.cmd, 'packadd nvim-nio')
if vim.fn.exists('*MiniTest') ~= 1 then
  local pack_mini = vim.fn.globpath(vim.o.packpath, 'pack/*/opt/mini.nvim', false, true)
  if type(pack_mini) == 'table' then
    for _, p in ipairs(pack_mini) do
      if vim.fn.isdirectory(p) == 1 then
        vim.opt.runtimepath:prepend(p)
      end
    end
  end
end

local has_nio = pcall(require, 'nio')
if not has_nio then
  local pack_nio = vim.fn.globpath(vim.o.packpath, 'pack/*/opt/nvim-nio', false, true)
  if type(pack_nio) == 'table' then
    for _, p in ipairs(pack_nio) do
      if vim.fn.isdirectory(p) == 1 then
        vim.opt.runtimepath:prepend(p)
      end
    end
  end
end

-- Disable unnecessary providers
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- Avoid writes to user state during tests (important in sandboxed runs)
vim.opt.shadafile = 'NONE'

-- Configure mini.test. The LOCI reporter also waits for pending nvim-nio tests
-- before the final summary, so keep it installed even when case logging is off.
require('mini.test').setup({
  execute = {
    reporter = require('tests.loci_reporter').new(),
  },
})
