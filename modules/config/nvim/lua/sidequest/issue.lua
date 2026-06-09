local M = {}
local data_dir = ".sidequest"
local data_file = "issues.json"

function M.get_data_dir()
  local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
  return root .. "/" .. data_dir
end

function M.get_data_path()
  return M.get_data_dir() .. "/" .. data_file
end

function M.load()
  local path = M.get_data_path()
  local f = io.open(path, "r")
  if not f then
    local legacy_path = (vim.fs.root(0, ".git") or vim.fn.getcwd()) .. "/.sidequest.json"
    local lf = io.open(legacy_path, "r")
    if not lf then return { issues = {}, active_issue = nil } end
    local legacy_content = lf:read("*a")
    lf:close()
    local ok_legacy, legacy_data = pcall(vim.json.decode, legacy_content)
    if not ok_legacy then return { issues = {}, active_issue = nil } end
    M.save(legacy_data)
    return legacy_data
  end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok then return { issues = {}, active_issue = nil } end
  data.issues = data.issues or {}
  return data
end

function M.save(data)
  vim.fn.mkdir(M.get_data_dir(), "p")
  local path = M.get_data_path()
  local content = vim.json.encode(data)
  local f = io.open(path, "w")
  if not f then
    vim.notify("Sidequest: cannot write " .. path, vim.log.levels.ERROR)
    return
  end
  f:write(content)
  f:close()
end

function M.get_active_issue()
  local data = M.load()
  if not data.active_issue then return nil end
  return data.issues[data.active_issue], data.active_issue
end

function M.attach_file(issue_id, tab, filepath)
  local data = M.load()
  if not data.issues[issue_id] then data.issues[issue_id] = { title = issue_id, files = {} } end
  if not data.issues[issue_id].files[tab] then data.issues[issue_id].files[tab] = {} end
  for _, f in ipairs(data.issues[issue_id].files[tab]) do if f == filepath then return end end
  table.insert(data.issues[issue_id].files[tab], filepath)
  M.save(data)
end

function M.detach_file(issue_id, tab, filepath)
  local data = M.load()
  local issue = data.issues[issue_id]
  if not issue or not issue.files[tab] then return end
  issue.files[tab] = vim.tbl_filter(function(f) return f ~= filepath end, issue.files[tab])
  M.save(data)
end

return M
