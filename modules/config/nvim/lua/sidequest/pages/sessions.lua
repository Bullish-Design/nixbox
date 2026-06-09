return {
  root = "overview",
  pages = {
    overview = {
      title = function(ctx)
        if ctx.session and ctx.session.current then return "Sessions: " .. ctx.session.current end
        return "Sessions"
      end,
      sections = {
        { type = "lines", title = "Status", render = function(ctx)
          if ctx.session and ctx.session.current then return { "Attached to: " .. ctx.session.current } end
          return { "Not attached to any session" }
        end },
        { type = "separator" },
        { type = "actions", title = "Actions", items = {
          { key = "s", icon = "󰆓 ", label = "Save", action = "session.save" },
          { key = "S", icon = "󰆔 ", label = "Save as...", action = "session.save_as" },
          { key = "l", icon = "󰁯 ", label = "Load", action = "session.load", close = true },
          { key = "c", icon = " ", label = "Load for cwd", action = "session.load_current_dir", close = true },
          { key = "d", icon = "󰆴 ", label = "Delete", action = "session.delete" },
          { key = "D", icon = " ", label = "Detach", action = "session.detach" },
          { key = "t", icon = " ", label = "Save tab session", action = "session.save_tab" },
        } },
        { type = "separator" },
        { type = "lines", title = "Saved Sessions", render = function(ctx)
          if not ctx.session or not ctx.session.available then return { "(resession not available)" } end
          local list = ctx.session.list
          if #list == 0 then return { "(no saved sessions)" } end
          local lines = {}
          for _, name in ipairs(list) do
            local marker = (ctx.session.current == name) and " ← active" or ""
            table.insert(lines, "  " .. name .. marker)
          end
          return lines
        end },
      },
    },
  },
}
