local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local tmpdir

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      tmpdir = helpers.create_tmpdir()
    end,
    post_case = function()
      helpers.remove_tmpdir(tmpdir)
    end,
  },
})

local fs = require('loci.store.fs')

T['fs module does not expose alias methods'] = function()
  expect.equality(fs.mkdirp, nil)
  expect.equality(fs.rm, nil)
end

T['read_file() reads existing file'] = helpers.async_test(function()
  helpers.write_file(tmpdir .. '/hello.txt', 'hello world')
  local r = fs.read_file(tmpdir .. '/hello.txt')
  expect.equality(helpers.expect_ok(r), 'hello world')
end)

T['read_file() returns err for missing file'] = helpers.async_test(function()
  local r = fs.read_file(tmpdir .. '/nope.txt')
  helpers.expect_err(r, 'not_found')
end)

T['read_file() reads empty file'] = helpers.async_test(function()
  helpers.write_file(tmpdir .. '/empty.txt', '')
  local r = fs.read_file(tmpdir .. '/empty.txt')
  expect.equality(helpers.expect_ok(r), '')
end)

T['exists() returns true for existing file'] = helpers.async_test(function()
  helpers.write_file(tmpdir .. '/a.txt', 'x')
  expect.equality(helpers.expect_ok(fs.exists(tmpdir .. '/a.txt')), true)
end)

T['exists() returns false for missing file'] = helpers.async_test(function()
  expect.equality(helpers.expect_ok(fs.exists(tmpdir .. '/nope.txt')), false)
end)

T['exists() returns true for directory'] = helpers.async_test(function()
  expect.equality(helpers.expect_ok(fs.exists(tmpdir)), true)
end)

T['mkdir_p() creates nested directories'] = helpers.async_test(function()
  local deep = tmpdir .. '/a/b/c'
  helpers.expect_ok(fs.mkdir_p(deep))
  expect.equality(helpers.expect_ok(fs.exists(deep)), true)
end)

T['mkdir_p() is idempotent'] = helpers.async_test(function()
  local dir = tmpdir .. '/x/y'
  helpers.expect_ok(fs.mkdir_p(dir))
  helpers.expect_ok(fs.mkdir_p(dir))
  expect.equality(helpers.expect_ok(fs.exists(dir)), true)
end)

T['write_file() creates file and parent dirs'] = helpers.async_test(function()
  local path = tmpdir .. '/sub/dir/file.txt'
  local r = fs.write_file(path, 'content')
  helpers.expect_ok(r)
  local read_r = fs.read_file(path)
  expect.equality(helpers.expect_ok(read_r), 'content')
end)

T['write_file() overwrites existing file'] = helpers.async_test(function()
  local path = tmpdir .. '/over.txt'
  helpers.expect_ok(fs.write_file(path, 'first'))
  helpers.expect_ok(fs.write_file(path, 'second'))
  local r = fs.read_file(path)
  expect.equality(helpers.expect_ok(r), 'second')
end)

T['write_file_atomic() writes file atomically'] = helpers.async_test(function()
  local path = tmpdir .. '/atomic.txt'
  local r = fs.write_file_atomic(path, 'atomic content')
  helpers.expect_ok(r)
  local read_r = fs.read_file(path)
  expect.equality(helpers.expect_ok(read_r), 'atomic content')
end)

T['write_file_atomic() creates parent dirs'] = helpers.async_test(function()
  local path = tmpdir .. '/deep/atomic.txt'
  local r = fs.write_file_atomic(path, 'deep')
  helpers.expect_ok(r)
  expect.equality(helpers.expect_ok(fs.exists(path)), true)
end)

T['readdir() lists directory entries'] = helpers.async_test(function()
  helpers.write_file(tmpdir .. '/a.txt', 'a')
  helpers.write_file(tmpdir .. '/b.txt', 'b')
  local entries = helpers.expect_ok(fs.readdir(tmpdir))
  expect.equality(type(entries), 'table')
  local names = vim.tbl_map(function(entry)
    return entry.name
  end, entries)
  table.sort(names)
  expect.equality(vim.tbl_contains(names, 'a.txt'), true)
  expect.equality(vim.tbl_contains(names, 'b.txt'), true)
end)

T['readdir() returns error for missing dir'] = helpers.async_test(function()
  local r = fs.readdir(tmpdir .. '/nope')
  helpers.expect_err(r, 'not_found')
end)

T['unlink() deletes a file'] = helpers.async_test(function()
  local path = tmpdir .. '/del.txt'
  helpers.expect_ok(fs.write_file(path, 'bye'))
  expect.equality(helpers.expect_ok(fs.exists(path)), true)
  local r = fs.unlink(path)
  helpers.expect_ok(r)
  expect.equality(helpers.expect_ok(fs.exists(path)), false)
end)

T['unlink() returns error for missing file'] = helpers.async_test(function()
  local r = fs.unlink(tmpdir .. '/nope.txt')
  helpers.expect_err(r, 'not_found')
end)

return T
