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

local json = require('loci.store.json')

T['write() then read() roundtrips a table'] = helpers.async_test(function()
  local path = tmpdir .. '/data.json'
  local data = { name = 'test', count = 42, tags = { 'a', 'b' } }
  helpers.expect_ok(json.write(path, data))
  local r = json.read(path)
  local decoded = helpers.expect_ok(r)
  expect.equality(decoded.name, 'test')
  expect.equality(decoded.count, 42)
  expect.equality(#decoded.tags, 2)
  expect.equality(decoded.tags[1], 'a')
end)

T['write() creates parent directories'] = helpers.async_test(function()
  local path = tmpdir .. '/sub/dir/data.json'
  helpers.expect_ok(json.write(path, { ok = true }))
  local r = json.read(path)
  local decoded = helpers.expect_ok(r)
  expect.equality(decoded.ok, true)
end)

T['write() produces pretty-printed JSON'] = helpers.async_test(function()
  local path = tmpdir .. '/pretty.json'
  helpers.expect_ok(json.write(path, { b = 2, a = 1 }))
  local content = helpers.read_file(path)
  expect.equality(content:match('\n') ~= nil, true)
  expect.equality(content:sub(-1), '\n')
end)

T['write() produces sorted keys'] = helpers.async_test(function()
  local path = tmpdir .. '/sorted.json'
  helpers.expect_ok(json.write(path, { zebra = 1, alpha = 2 }))
  local content = helpers.read_file(path)
  local alpha_pos = content:find('"alpha"')
  local zebra_pos = content:find('"zebra"')
  expect.equality(alpha_pos < zebra_pos, true)
end)

T['read() returns not_found for missing file'] = helpers.async_test(function()
  local r = json.read(tmpdir .. '/nope.json')
  helpers.expect_err(r, 'not_found')
  expect.equality(r.meta.path, tmpdir .. '/nope.json')
  expect.equality(r.meta.source_code, 'not_found')
  expect.no_equality(r.meta.source_err, nil)
end)

T['read() returns decode_failed for invalid JSON'] = helpers.async_test(function()
  helpers.write_file(tmpdir .. '/bad.json', '{not json}')
  local r = json.read(tmpdir .. '/bad.json')
  helpers.expect_err(r, 'decode_failed')
  expect.equality(r.meta.path, tmpdir .. '/bad.json')
  expect.no_equality(r.meta.source_err, nil)
end)

T['read() preserves non-not-found read failures'] = helpers.async_test(function()
  local dir_path = tmpdir .. '/dir-as-file'
  vim.fn.mkdir(dir_path, 'p')
  local r = json.read(dir_path)
  expect.equality(r.ok, false)
  expect.equality(r.code ~= 'not_found', true)
  expect.equality(r.meta.path, dir_path)
  expect.no_equality(r.meta.source_code, nil)
  expect.no_equality(r.meta.source_err, nil)
end)

T['read() handles empty object'] = helpers.async_test(function()
  helpers.write_file(tmpdir .. '/empty.json', '{}')
  local r = json.read(tmpdir .. '/empty.json')
  local decoded = helpers.expect_ok(r)
  expect.equality(type(decoded), 'table')
end)

T['write() returns encode_failed for unencodable data'] = helpers.async_test(function()
  local path = tmpdir .. '/fail.json'
  local r = json.write(path, { fn = function() end })
  helpers.expect_err(r, 'encode_failed')
end)

T['write_lines() writes array as newline-separated text'] = helpers.async_test(function()
  local path = tmpdir .. '/lines.txt'
  helpers.expect_ok(json.write_lines(path, { 'line 1', 'line 2', 'line 3' }))
  local content = helpers.read_file(path)
  expect.equality(content, 'line 1\nline 2\nline 3\n')
end)

T['write_lines() creates parent dirs'] = helpers.async_test(function()
  local path = tmpdir .. '/deep/lines.txt'
  helpers.expect_ok(json.write_lines(path, { 'hello' }))
  expect.equality(helpers.read_file(path), 'hello\n')
end)

T['roundtrip with repository.json shape'] = helpers.async_test(function()
  local path = tmpdir .. '/repository.json'
  local repo = {
    schema_version = 1,
    repository_id = 'test-repo-abc123',
    name = 'test-repo',
    root = '/tmp/test',
    default_workspace_id = 'repo-default-xyz789',
    default_content_path = 'index.md',
    provenance = {
      created_at = '2026-05-23T10:00:00-04:00',
      last_refreshed_at = '2026-05-23T10:00:00-04:00',
    },
  }
  helpers.expect_ok(json.write(path, repo))
  local decoded = helpers.expect_ok(json.read(path))
  expect.equality(decoded.schema_version, 1)
  expect.equality(decoded.repository_id, 'test-repo-abc123')
  expect.equality(decoded.default_workspace_id, 'repo-default-xyz789')
  expect.equality(decoded.provenance.created_at, '2026-05-23T10:00:00-04:00')
end)

T['roundtrip with workspace.json shape'] = helpers.async_test(function()
  local path = tmpdir .. '/workspace.json'
  local ws = {
    schema_version = 1,
    workspace_id = 'parser-fix-main-8x2kqz',
    project_id = 'loci-v3-redesign-4k9m2q',
    name = 'Parser fix main',
    git = { branch = 'loci/parser-fix', worktree_path = vim.NIL },
    knowledge = { primary_loci_id = vim.NIL, objects = {} },
    haunt = {
      active = 'main',
      contexts = {
        main = { data_dir = '.loci/integrations/haunt/workspaces/parser-fix-main-8x2kqz/main' },
      },
    },
    linked_files = {},
  }
  helpers.expect_ok(json.write(path, ws))
  local decoded = helpers.expect_ok(json.read(path))
  expect.equality(decoded.workspace_id, 'parser-fix-main-8x2kqz')
  expect.equality(decoded.haunt.active, 'main')
  expect.equality(type(decoded.knowledge.objects), 'table')
  expect.equality(#decoded.knowledge.objects, 0)
end)

return T
