local function overview_lines(ctx)
  local lines = { "root:    " .. (ctx.root or "unknown") }
  if ctx.git and ctx.git.branch then table.insert(lines, "branch:  " .. ctx.git.branch) end
  if ctx.session and ctx.session.current then table.insert(lines, "session: " .. ctx.session.current) end
  if ctx.buffers then table.insert(lines, "bufs:    " .. ctx.buffers.count) end
  if ctx.diagnostics then
    local d = ctx.diagnostics
    if d.error + d.warn > 0 then table.insert(lines, "diag:    " .. d.error .. "E " .. d.warn .. "W") end
  end
  return lines
end

local sessions_page = {
  title = "Sidequest > Sessions",
  sections = {
    { type = "lines", title = "Current Session", render = function(ctx) if ctx.session and ctx.session.current then return { "attached: " .. ctx.session.current } end return { "(not attached to any session)" } end },
    { type = "separator" },
    { type = "actions", title = "Actions", items = {
      { key = "s", icon = "󰆓 ", label = "Save session", action = "session.save" },
      { key = "S", icon = "󰆔 ", label = "Save as...", action = "session.save_as" },
      { key = "l", icon = "󰁯 ", label = "Load session", action = "session.load", close = true },
      { key = "d", icon = "󰆴 ", label = "Delete session", action = "session.delete" },
      { key = "D", icon = " ", label = "Detach", action = "session.detach" },
      { key = "t", icon = " ", label = "Save tab session", action = "session.save_tab" },
    } },
    { type = "separator" },
    { type = "lines", title = "Available Sessions", render = function(ctx)
      if not ctx.session or not ctx.session.list then return { "(resession not available)" } end
      if #ctx.session.list == 0 then return { "(no saved sessions)" } end
      local lines = {}
      for _, name in ipairs(ctx.session.list) do table.insert(lines, "  " .. name .. ((ctx.session.current == name) and " *" or "")) end
      return lines
    end },
  },
}

return {
  root = "overview",
  tabs = {
    { id = "code", label = "Code", icon = "󰅩" },
    { id = "testing", label = "Testing", icon = "" },
    { id = "notes", label = "Notes", icon = "󰎞" },
  },
  tab_pages = {
    code = {
      overview = {
        title = "Code",
        sections = {
          { type = "lines", title = "Issue Files", render = function()
            local issue_data, issue_id = require("sidequest.issue").get_active_issue()
            if not issue_data then return { "(no active issue)" } end
            local files = issue_data.files and issue_data.files.code or {}
            if #files == 0 then return { "issue: " .. issue_id, "(no code files attached)" } end
            local lines = { "issue: " .. issue_id }
            for _, f in ipairs(files) do table.insert(lines, "  " .. f) end
            return lines
          end },
          { type = "separator" },
          { type = "actions", items = {
            { key = "a", icon = " ", label = "Attach current file", action = "issue.files.attach_current" },
            { key = "f", icon = "󰱼 ", label = "Find issue file", action = "issue.files.find", close = true },
            { key = "g", icon = "󰊢 ", label = "Grep issue files", action = "issue.files.grep", close = true },
            { key = "b", icon = "󰓩 ", label = "Buffers", action = "picker.buffers", close = true },
            { key = "G", icon = " ", label = "Git status", action = "git.status", close = true },
            { key = "s", icon = "󰆓 ", label = "Sessions", page = "sessions" },
          } },
        },
      },
    },
    testing = {
      overview = {
        title = "Testing",
        sections = {
          { type = "actions", items = {
            { key = "r", icon = " ", label = "Run tests", action = "test.run" },
            { key = "f", icon = "󰱼 ", label = "Find test file", action = "test.find", close = true },
            { key = "l", icon = "󰁯 ", label = "Last test output", action = "test.last" },
          } },
        },
      },
    },
    notes = {
      overview = {
        title = "Notes",
        sections = {
          { type = "actions", items = {
            { key = "n", icon = "󰎞 ", label = "New note", action = "notes.new" },
            { key = "f", icon = "󰱼 ", label = "Find note", action = "notes.find", close = true },
            { key = "t", icon = " ", label = "Todos", action = "notes.todos", close = true },
          } },
        },
      },
    },
  },
  pages = {
    overview = {
      title = function(ctx) return "Sidequest: " .. (ctx.project_name or "unknown") end,
      sections = {
        { type = "lines", title = "Workspace", render = overview_lines },
        { type = "separator" },
        { type = "actions", title = "Actions", items = {
          { key = "f", icon = "󰱼 ", label = "Find file", action = "picker.files", close = true },
          { key = "g", icon = "󰊢 ", label = "Live grep", action = "picker.grep", close = true },
          { key = "b", icon = "󰓩 ", label = "Buffers", action = "picker.buffers", close = true },
          { key = "t", icon = " ", label = "Terminal", action = "terminal.toggle", close = true },
          { key = "G", icon = " ", label = "Git status", action = "git.status", close = true },
          { key = "s", icon = "󰆓 ", label = "Sessions", page = "sessions" },
        } },
      },
    },
    sessions = sessions_page,
    _help = {
      title = "Sidequest: Active Keymaps",
      sections = {{ type = "lines", render = function(ctx)
        local lines = { "Tree: " .. require("sidequest.state").get().active_tree, "Page: " .. (ctx._previous_page or "unknown"), "Strict: " .. tostring(require("sidequest").get_config().keymaps.strict), "", "Mappings:" }
        for _, m in ipairs(require("sidequest.keymaps").get_active()) do table.insert(lines, string.format("  %-10s %s", m.lhs, m.desc or "")) end
        return lines
      end }},
    },
  },
}
