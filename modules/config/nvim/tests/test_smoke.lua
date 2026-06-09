local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()

T['require loci loads without error'] = function()
  local ok, mod = pcall(require, 'loci')
  expect.equality(ok, true)
  expect.equality(type(mod.setup), 'function')
end

T['setup with refresh disabled does not crash'] = function()
  require('loci').setup({ refresh = { on_setup = false } })
end

T['all domain modules load'] = function()
  for _, name in ipairs({ 'id', 'repository', 'project', 'workspace', 'markdown_object' }) do
    local ok = pcall(require, 'loci.domain.' .. name)
    expect.equality(ok, true)
  end
end

T['all store modules load'] = function()
  for _, name in ipairs({ 'fs', 'path', 'json', 'graph', 'refresh', 'markdown' }) do
    local ok = pcall(require, 'loci.store.' .. name)
    expect.equality(ok, true)
  end
end

T['all service modules load'] = function()
  for _, name in ipairs({ 'repository', 'project', 'workspace', 'activation', 'runtime', 'bases', 'tasknotes' }) do
    local ok = pcall(require, 'loci.service.' .. name)
    expect.equality(ok, true)
  end
end

T['all integration modules load'] = function()
  for _, name in ipairs({ 'git', 'haunt', 'obsidian', 'resession', 'tabby', 'wayfinder' }) do
    local ok = pcall(require, 'loci.integrations.' .. name)
    expect.equality(ok, true)
  end
end

T['all ui modules load'] = function()
  for _, name in ipairs({ 'commands', 'forms', 'picker', 'status' }) do
    local ok = pcall(require, 'loci.ui.' .. name)
    expect.equality(ok, true)
  end
end

return T
