local MiniTest = require('mini.test')
local expect = MiniTest.expect
local refresh = require('loci.store.refresh')

local T = MiniTest.new_set()

T['body wikilink alone does not create membership'] = function()
  local scan_result = {
    content_entries = {
      {
        abs_path = '/tmp/note.md',
        content_path = 'notes/note.md',
        state = 'canonical',
        object = { loci_id = 'note-abc123', type = 'note', projects = {} },
        body = 'This mentions [[Project Alpha]].',
        diagnostics = {},
      },
    },
    projects = { { id = 'project-abc123', name = 'Project Alpha' } },
    workspaces = {},
    diagnostics = {},
  }
  local r = refresh.snapshot(scan_result, {})
  expect.equality(r.ok, true)
  expect.equality(r.value.project_memberships['project-abc123'], nil)
end

return T
