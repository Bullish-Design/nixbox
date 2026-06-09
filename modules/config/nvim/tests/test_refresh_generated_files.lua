local MiniTest = require('mini.test')
local expect = MiniTest.expect
local refresh = require('loci.store.refresh')

local T = MiniTest.new_set()

T['generated files are excluded from canonical content indexes'] = function()
  local scan_result = {
    content_entries = {
      { abs_path = '/tmp/index.md', content_path = 'index.md', state = 'generated', object = { loci_id = 'repo-index-1', type = 'repository-index' }, diagnostics = {} },
      { abs_path = '/tmp/note.md', content_path = 'notes/note.md', state = 'canonical', object = { loci_id = 'note-1', type = 'note', projects = {} }, diagnostics = {} },
    },
    projects = {},
    workspaces = {},
    diagnostics = {},
  }
  local r = refresh.snapshot(scan_result, {})
  expect.equality(r.ok, true)
  expect.equality(r.value.content_by_loci_id['repo-index-1'], nil)
  expect.no_equality(r.value.content_by_loci_id['note-1'], nil)
end

return T
