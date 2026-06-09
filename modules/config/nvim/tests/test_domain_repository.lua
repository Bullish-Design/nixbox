local MiniTest = require('mini.test')
local expect = MiniTest.expect
local helpers = require('tests.helpers')

local T = MiniTest.new_set()

T['new() creates basic repository'] = function()
  local repository = require('loci.domain.repository')
  local repo = helpers.expect_ok(repository.new({
    root = '/home/user/project',
    name = 'my-project',
    created_at = '2026-05-23T10:00:00-04:00',
  }))
  expect.equality(repo.schema_version, 1)
  expect.equality(repo.name, 'my-project')
  expect.equality(repo.root, '/home/user/project')
  expect.equality(repo.default_content_path, 'index.md')
end

T['new() derives name from root when missing'] = function()
  local repository = require('loci.domain.repository')
  local repo = helpers.expect_ok(repository.new({
    root = '/home/user/my-project',
    created_at = '2026-05-23T10:00:00-04:00',
  }))
  expect.equality(repo.name, 'my-project')
end

T['validate() accepts valid repository'] = function()
  local repository = require('loci.domain.repository')
  local repo = helpers.expect_ok(repository.new({
    root = '/home/user/project',
    name = 'test-project',
    created_at = '2026-05-23T10:00:00-04:00',
  }))
  local r = repository.validate(repo)
  expect.equality(r.ok, true)
  expect.equality(r.value, repo)
end

T['validate() rejects missing repository_id'] = function()
  local repository = require('loci.domain.repository')
  local repo = helpers.expect_ok(repository.new({
    root = '/home/user/project',
    name = 'test-project',
    created_at = '2026-05-23T10:00:00-04:00',
  }))
  repo.repository_id = nil
  local r = repository.validate(repo)
  expect.equality(r.ok, false)
  expect.equality(r.code, 'validation_failed')
end

T['validate() rejects relative root'] = function()
  local repository = require('loci.domain.repository')
  local repo_r = repository.new({
    root = 'relative/path',
    name = 'test-project',
  })
  expect.equality(repo_r.ok, false)
end

T['validate() rejects wrong default_content_path'] = function()
  local repository = require('loci.domain.repository')
  local repo = helpers.expect_ok(repository.new({
    root = '/home/user/project',
    name = 'test-project',
    created_at = '2026-05-23T10:00:00-04:00',
  }))
  repo.default_content_path = 'other/path.md'
  local r = repository.validate(repo)
  expect.equality(r.ok, false)
  expect.equality(r.code, 'validation_failed')
end

return T
