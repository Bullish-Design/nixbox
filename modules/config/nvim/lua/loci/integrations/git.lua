local result = require("loci.result")
local path_store = require("loci.store.path")

local M = {}
local _available = nil

-- ============================================================================
-- Helpers
-- ============================================================================

local function is_nil(value)
  return value == nil or value == vim.NIL
end

local function call_on_main(fn)
  if vim.in_fast_event() then
    require("loci.async").schedule()
  end
  return pcall(fn)
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.available()
  if _available == nil then
    _available = vim.fn.executable("git") == 1
  end
  return _available
end

function M.health()
  return {
    name = "git",
    available = M.available(),
    detail = M.available() and "git executable found" or "git not found",
  }
end

---Resolve worktree path to absolute directory.
---@param workspace table workspace graph
---@param repository table repository graph
---@return loci.Result<string> absolute path
function M.resolve_worktree(workspace, repository)
  local root = repository.root or path_store.repository_root()
  local worktree = workspace.git and workspace.git.worktree_path
  local target

  if is_nil(worktree) or worktree == "" then
    target = root
  elseif worktree:match("^/") then
    target = vim.fs.normalize(worktree)
  else
    target = vim.fs.normalize(root .. "/" .. worktree)
  end

  local stat = vim.uv.fs_stat(target)
  if not stat or stat.type ~= "directory" then
    return result.err("Git worktree does not exist: " .. target, "not_found", { path = target })
  end

  return result.ok(target)
end

---Switch to worktree directory with tab-local cwd.
---@param target string absolute path
---@return loci.Result
function M.switch_worktree(target)
  local ok, err = call_on_main(function()
    vim.cmd.tcd(vim.fn.fnameescape(target))
  end)
  if not ok then
    return result.err("Failed to switch worktree: " .. tostring(err), "command_failed", { path = target })
  end
  return result.ok({ path = target })
end

---Get current branch name.
---@param dir? string optional worktree path
---@return loci.Result<string|nil>
function M.current_branch(dir)
  if not M.available() then
    return result.ok(nil)
  end

  local cwd = dir or vim.uv.cwd()
  local cmd = { "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    return result.ok(nil)
  end

  local branch = vim.trim(output)
  if branch == "" or branch == "HEAD" then
    return result.ok(nil)
  end

  return result.ok(branch)
end

return M
