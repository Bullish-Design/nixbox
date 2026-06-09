local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()

local result = require('loci.result')

T['ok() returns table with ok=true'] = function()
  local r = result.ok('hello')
  expect.equality(r.ok, true)
  expect.equality(r.value, 'hello')
  expect.equality(r.err, nil)
  expect.equality(r.code, nil)
end

T['ok() with nil value'] = function()
  local r = result.ok()
  expect.equality(r.ok, true)
  expect.equality(r.value, nil)
end

T['ok() with meta'] = function()
  local r = result.ok('val', { path = '/tmp' })
  expect.equality(r.meta.path, '/tmp')
end

T['ok() value can be a table'] = function()
  local r = result.ok({ a = 1, b = 2 })
  expect.equality(r.ok, true)
  expect.equality(r.value.a, 1)
  expect.equality(r.value.b, 2)
end

T['err() returns table with ok=false'] = function()
  local r = result.err('boom', 'io_read_failed')
  expect.equality(r.ok, false)
  expect.equality(r.err, 'boom')
  expect.equality(r.code, 'io_read_failed')
  expect.equality(r.value, nil)
end

T['err() without code'] = function()
  local r = result.err('oops')
  expect.equality(r.ok, false)
  expect.equality(r.err, 'oops')
  expect.equality(r.code, nil)
end

T['err() with meta'] = function()
  local r = result.err('fail', 'not_found', { path = '/x' })
  expect.equality(r.meta.path, '/x')
end

T['is_ok() returns true for ok result'] = function()
  expect.equality(result.is_ok(result.ok('v')), true)
end

T['is_ok() returns false for err result'] = function()
  expect.equality(result.is_ok(result.err('e')), false)
end

T['is_ok() returns false for non-table'] = function()
  expect.equality(result.is_ok(nil), false)
  expect.equality(result.is_ok('string'), false)
  expect.equality(result.is_ok(42), false)
end

T['is_ok() returns false for table without ok field'] = function()
  expect.equality(result.is_ok({ value = 'x' }), false)
end

T['unwrap() returns value for ok'] = function()
  local val, err = result.unwrap(result.ok('hello'))
  expect.equality(val, 'hello')
  expect.equality(err, nil)
end

T['unwrap() returns nil and error for err'] = function()
  local val, err = result.unwrap(result.err('boom', 'io_read_failed'))
  expect.equality(val, nil)
  expect.equality(err, 'boom')
end

T['unwrap() handles non-table gracefully'] = function()
  local val, err = result.unwrap(nil)
  expect.equality(val, nil)
  expect.equality(err, 'unknown error')
end

return T
