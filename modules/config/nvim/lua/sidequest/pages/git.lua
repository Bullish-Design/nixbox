return {
  root = "overview",
  pages = {
    overview = {
      title = function(ctx)
        if ctx.git and ctx.git.branch then return "Git: " .. ctx.git.branch end
        return "Git"
      end,
      sections = {
        { type = "lines", title = "Status", render = function(ctx)
          if ctx.git and ctx.git.branch then return { "branch: " .. ctx.git.branch } end
          return { "(not in a git repository)" }
        end },
        { type = "separator" },
        { type = "actions", title = "Actions", items = {
          { key = "s", icon = " ", label = "Status", action = "git.status", close = true },
          { key = "c", icon = "󰜘 ", label = "Commits", action = "git.log", close = true },
          { key = "b", icon = " ", label = "Branches", action = "git.branches", close = true },
          { key = "n", icon = " ", label = "Neogit", action = "git.neogit", close = true },
          { key = "d", icon = " ", label = "Diff", action = "git.diff", close = true },
        } },
      },
    },
  },
}
