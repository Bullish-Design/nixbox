local M = {}
local registry = {}

function M.register(name, fn) registry[name] = fn end
function M.get(name) return registry[name] end

function M.run(name, ctx)
  local fn = registry[name]
  if fn then fn(ctx) else vim.notify("Sidequest: unknown action '" .. name .. "'", vim.log.levels.WARN) end
end

function M.resolve(item, ctx)
  if item.page then return function() require("sidequest").go(item.page) end end
  if type(item.action) == "function" then return function() item.action(ctx) end end
  if type(item.action) == "string" then return function() M.run(item.action, ctx) end end
  return nil
end

M.register("picker.files", function(ctx) Snacks.picker.files({ cwd = ctx and ctx.root or nil }) end)
M.register("picker.grep", function(ctx) Snacks.picker.grep({ cwd = ctx and ctx.root or nil }) end)
M.register("picker.buffers", function() Snacks.picker.buffers() end)
M.register("terminal.toggle", function() Snacks.terminal.toggle() end)
M.register("git.status", function() Snacks.picker.git_status() end)
M.register("git.log", function() Snacks.picker.git_log() end)
M.register("git.branches", function() Snacks.picker.git_branches() end)
M.register("git.neogit", function() require("neogit").open() end)
M.register("git.diff", function() vim.cmd("DiffviewOpen") end)
M.register("close", function() require("sidequest").close() end)
M.register("back", function() require("sidequest").back() end)
M.register("back_or_close", function() local sq = require("sidequest"); if not sq.back() then sq.close() end end)
M.register("refresh", function() require("sidequest").refresh() end)
M.register("home", function() require("sidequest").home() end)
M.register("help", function() require("sidequest").go("_help") end)
M.register("session.save", function()
  local resession = require("resession")
  local current = resession.get_current()
  if current then resession.save(current, { notify = true }) else resession.save() end
  require("sidequest").refresh()
end)
M.register("session.save_as", function() require("resession").save(); require("sidequest").refresh() end)
M.register("session.load", function() require("sidequest").close(); require("resession").load() end)
M.register("session.load_current_dir", function()
  local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local resession = require("resession")
  if vim.tbl_contains(resession.list(), name) then require("sidequest").close(); resession.load(name) else vim.notify("No session found for: " .. name, vim.log.levels.INFO) end
end)
M.register("session.delete", function() require("resession").delete(); require("sidequest").refresh() end)
M.register("session.detach", function() require("resession").detach(); vim.notify("Detached from session", vim.log.levels.INFO); require("sidequest").refresh() end)
M.register("session.save_tab", function() require("resession").save_tab(); require("sidequest").refresh() end)
M.register("test.run", function(ctx) Snacks.picker.grep({ cwd = ctx and ctx.root or nil, search = "test" }) end)
M.register("test.find", function(ctx) Snacks.picker.files({ cwd = ctx and ctx.root or nil, search = "test" }) end)
M.register("test.last", function() vim.notify("No stored test output yet", vim.log.levels.INFO) end)
M.register("notes.new", function(ctx)
  local root = (ctx and ctx.root) or vim.fn.getcwd()
  local notes_dir = root .. "/.sidequest/notes"
  vim.fn.mkdir(notes_dir, "p")
  vim.cmd("edit " .. notes_dir .. "/" .. os.date("%Y-%m-%d") .. "-note.md")
end)
M.register("notes.find", function(ctx)
  local notes_dir = (ctx and ctx.root or vim.fn.getcwd()) .. "/.sidequest/notes"
  vim.fn.mkdir(notes_dir, "p")
  Snacks.picker.files({ cwd = notes_dir })
end)
M.register("notes.todos", function(ctx) Snacks.picker.grep({ cwd = ctx and ctx.root or nil, search = "TODO" }) end)
M.register("issue.files.attach_current", function()
  local issue = require("sidequest.issue")
  local data = issue.load()
  if not data.active_issue then
    vim.notify("No active issue", vim.log.levels.WARN)
    return
  end
  local tab = require("sidequest.state").current_tab() or "code"
  local filepath = vim.fn.expand("%:.")
  if filepath == "" then
    vim.notify("No file to attach", vim.log.levels.WARN)
    return
  end
  issue.attach_file(data.active_issue, tab, filepath)
  vim.notify("Attached: " .. filepath, vim.log.levels.INFO)
  require("sidequest").refresh()
end)
M.register("issue.files.find", function(ctx)
  local issue_mod = require("sidequest.issue")
  local issue_data = issue_mod.get_active_issue()
  if not issue_data then
    Snacks.picker.files({ cwd = ctx.root })
    return
  end
  local tab = require("sidequest.state").current_tab() or "code"
  local files = issue_data.files and issue_data.files[tab] or {}
  if #files == 0 then
    Snacks.picker.files({ cwd = ctx.root })
    return
  end
  Snacks.picker.files({ cwd = ctx.root, filter = files })
end)
M.register("issue.files.grep", function(ctx)
  local issue_mod = require("sidequest.issue")
  local issue_data = issue_mod.get_active_issue()
  if not issue_data then
    Snacks.picker.grep({ cwd = ctx.root })
    return
  end
  local tab = require("sidequest.state").current_tab() or "code"
  local files = issue_data.files and issue_data.files[tab] or {}
  if #files == 0 then
    Snacks.picker.grep({ cwd = ctx.root })
    return
  end
  Snacks.picker.grep({ cwd = ctx.root, dirs = files })
end)

return M
