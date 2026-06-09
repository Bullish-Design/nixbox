local M = {}
local MiniTest = require('mini.test')
local expect = MiniTest.expect
local nio = require('nio')

local function current_case_name()
  local case = MiniTest.current and MiniTest.current.case
  if not case or type(case.desc) ~= 'table' then
    return '<unknown test case>'
  end
  return table.concat(case.desc, ' | ')
end

local function log_case(status, detail)
  local log_cases = vim.uv.os_getenv('LOCI_TEST_LOG_CASES')
  if log_cases == '0' then
    return
  end

  local suffix = detail and detail ~= '' and (' :: ' .. detail) or ''
  io.stdout:write('\n[loci-test] ' .. status .. ' ' .. current_case_name() .. suffix .. '\n')
  io.flush()
end

function M.ensure_main()
  if vim.in_fast_event() then
    nio.scheduler()
  end
end

---@async
function M.await_main()
  if vim.in_fast_event() then
    nio.scheduler()
  end
end

function M.wait_for_loci_init_complete(root, timeout)
  timeout = timeout or 5000
  return vim.wait(timeout, function()
    local repo_json    = root .. "/.loci/repository.json"
    local current_json = root .. "/.loci/graph/current.json"

    if not vim.uv.fs_stat(repo_json) then return false end
    if not vim.uv.fs_stat(current_json) then return false end

    local ok, repo = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(repo_json), "\n"))
    if not ok or type(repo) ~= "table" or type(repo.default_workspace_id) ~= "string" then
      return false
    end

    local ws_path = root .. "/.loci/graph/workspaces/" .. repo.default_workspace_id .. ".json"
    return vim.uv.fs_stat(ws_path) ~= nil
  end, 10, false)
end

local function async_registry()
  _G.LOCI_TEST_ASYNC_PENDING = _G.LOCI_TEST_ASYNC_PENDING or {
    count = 0,
    next_id = 0,
    records = {},
  }
  return _G.LOCI_TEST_ASYNC_PENDING
end

---@param fn function async test body
---@param opts? table { timeout?: integer }
---@return function synchronous test function for mini.test
function M.async_test(fn, opts)
  opts = opts or {}
  local timeout = opts.timeout or tonumber(vim.env.LOCI_TEST_TIMEOUT_MS) or 15000

  return function()
    local done, ok, errval = false, true, nil
    local case = MiniTest.current and MiniTest.current.case
    local registry = async_registry()
    registry.next_id = registry.next_id + 1
    local async_id = registry.next_id
    registry.count = registry.count + 1
    registry.records[async_id] = {
      case = case,
      name = current_case_name(),
      started_at = vim.uv.hrtime(),
    }

    log_case('ASYNC', 'start')
    nio.run(function()
      nio.scheduler()
      local success, err = xpcall(fn, debug.traceback)
      ok = success
      errval = err
      done = true
      registry.records[async_id] = nil
      registry.count = math.max(0, registry.count - 1)
    end)

    local waited = vim.wait(timeout, function() return done end, 10, false)

    if not waited then
      log_case('FAIL', 'async test timed out after ' .. tostring(timeout) .. 'ms')
      error('async test timed out after ' .. tostring(timeout) .. 'ms')
    end
    if ok then
      log_case('PASS', 'async complete')
    else
      log_case('FAIL', tostring(errval))
      if case and case.exec and type(case.exec.fails) == 'table' then
        table.insert(case.exec.fails, tostring(errval))
      end
    end
    if not ok then
      error(tostring(errval))
    end
  end
end

---@param body function
---@param cleanup function
local function run_with_cleanup(body, cleanup)
  local ok, err = xpcall(body, debug.traceback)
  local cleanup_ok, cleanup_err = xpcall(cleanup, debug.traceback)
  if not ok and not cleanup_ok then
    error(tostring(err) .. '\nCleanup also failed:\n' .. tostring(cleanup_err))
  end
  if not ok then
    error(err)
  end
  if not cleanup_ok then
    error(cleanup_err)
  end
end

function M.with_cleanup(body, cleanup)
  return run_with_cleanup(body, cleanup)
end

---@return string absolute path to the temp directory
function M.create_tmpdir()
  M.ensure_main()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, 'p')
  return tmpdir
end

---@param dir string
function M.remove_tmpdir(dir)
  M.ensure_main()
  if not dir or dir == '' then
    return
  end

  local cwd = vim.fn.getcwd(-1, -1)
  local tab_cwd = vim.fn.getcwd(0, 0)
  if cwd:sub(1, #dir) == dir or tab_cwd:sub(1, #dir) == dir then
    local home = vim.uv.os_getenv('HOME') or '/tmp'
    pcall(vim.cmd, 'cd ' .. vim.fn.fnameescape(home))
    pcall(vim.cmd, 'tcd ' .. vim.fn.fnameescape(home))
  end

  if vim.fn.isdirectory(dir) == 1 then
    vim.fn.delete(dir, 'rf')
  end
end

---@param tmpdir string
---@return function restore
function M.patch_project_root(tmpdir)
  M.ensure_main()
  local original_env = vim.env.LOCI_PROJECT_ROOT
  vim.env.LOCI_PROJECT_ROOT = tmpdir
  return function()
    M.ensure_main()
    vim.env.LOCI_PROJECT_ROOT = original_env
  end
end

---Create a temporary obsidian vault directory.
---@return string vault_path
function M.create_obsidian_vault()
  M.ensure_main()
  local vault = vim.fn.tempname()
  vim.fn.mkdir(vault, 'p')
  return vault
end

---@param vault_path string
---@return function restore
function M.patch_obsidian_vault(vault_path)
  M.ensure_main()
  local original_env = vim.env.LOCI_OBSIDIAN_VAULT
  vim.env.LOCI_OBSIDIAN_VAULT = vault_path
  return function()
    M.ensure_main()
    vim.env.LOCI_OBSIDIAN_VAULT = original_env
  end
end

---@param tmpdir string the repository root
---@return string the .loci/ path
function M.init_loci_dir(tmpdir)
  M.ensure_main()
  local loci_root = tmpdir .. '/.loci'
  vim.fn.mkdir(loci_root, 'p')

  local repo_data = vim.json.encode({
    schema_version = 1,
    repository_id = 'test-repo-123456',
    name = 'test',
    root = tmpdir,
    default_workspace_id = 'fallback-main-xyz123',
    default_content_path = 'index.md',
    provenance = {
      created_at = '2026-01-01T00:00:00Z',
      last_refreshed_at = '2026-01-01T00:00:00Z',
    },
  })
  local f = io.open(loci_root .. '/repository.json', 'w')
  f:write(repo_data .. '\n')
  f:close()

  return loci_root
end

function M.reset_modules()
  local haunt_mod = package.loaded['loci.integrations.haunt']
  if type(haunt_mod) == 'table' and type(haunt_mod.reset_for_tests) == 'function' then
    pcall(haunt_mod.reset_for_tests)
  end

  local path_mod = package.loaded['loci.store.path']
  if type(path_mod) == 'table' and type(path_mod.reset) == 'function' then
    pcall(path_mod.reset)
  end

  for name, _ in pairs(package.loaded) do
    if name == 'loci' or name:match('^loci%.') then
      package.loaded[name] = nil
    end
  end
end

---Clear plugin API/package stubs used by integration tests.
function M.clear_integration_stubs()
  package.loaded['haunt.api'] = nil
  package.loaded['wayfinder'] = nil
  package.loaded['resession'] = nil
  package.loaded['tabby'] = nil
  package.loaded['obsidian'] = nil
  package.loaded['bases'] = nil
  M.clear_wayfinder_command_stubs()
end

---Delete LOCI commands and reset command registration state.
function M.clear_loci_commands()
  local registry = require("loci.ui.commands.registry")

  for _, name in ipairs(registry.CANONICAL) do
    pcall(vim.api.nvim_del_user_command, name)
  end

  for _, name in ipairs(registry.FORBIDDEN) do
    pcall(vim.api.nvim_del_user_command, name)
  end

  local commands_mod = package.loaded["loci.ui.commands"]
  if type(commands_mod) == "table" and type(commands_mod.reset_for_tests) == "function" then
    pcall(commands_mod.reset_for_tests)
  end
end

function M.clear_loci_runtime_state()
  vim.g.loci_repository_id = nil
  vim.g.loci_project_id = nil
  vim.t.loci_workspace_id = nil
end

function M.capture_editor_state()
  M.ensure_main()
  return {
    cwd = vim.fn.getcwd(-1, -1),
    tab_cwd = vim.fn.getcwd(0, 0),
    loci_repository_id = vim.g.loci_repository_id,
    loci_project_id = vim.g.loci_project_id,
    loci_workspace_id = vim.t.loci_workspace_id,
  }
end

function M.restore_editor_state(state)
  M.ensure_main()
  pcall(vim.cmd, "silent! %bwipeout!")
  pcall(vim.cmd, "silent! tabonly")

  if state and state.cwd and state.cwd ~= "" then
    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(state.cwd))
  end
  if state and state.tab_cwd and state.tab_cwd ~= "" then
    pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(state.tab_cwd))
  end

  vim.g.loci_repository_id = state and state.loci_repository_id or nil
  vim.g.loci_project_id = state and state.loci_project_id or nil
  vim.t.loci_workspace_id = state and state.loci_workspace_id or nil
end

---@param opts? table
---@return table ctx
function M.create_test_repo(opts)
  opts = opts or {}

  local tmpdir = M.create_tmpdir()
  local restore_root = M.patch_project_root(tmpdir)

  -- Set up temporary obsidian vault for integration tests
  local vault_path = M.create_obsidian_vault()
  local restore_vault = M.patch_obsidian_vault(vault_path)

  local editor_state = M.capture_editor_state()

  M.reset_modules()
  require('loci.config').setup(vim.tbl_deep_extend('force', {
    refresh = { on_setup = false },
  }, opts.config or {}))

  return {
    tmpdir = tmpdir,
    repo = tmpdir,
    loci = tmpdir .. '/.loci',
    loci_root = tmpdir .. '/.loci',
    vault_path = vault_path,
    cleanup = function()
      M.restore_editor_state(editor_state)
      M.clear_integration_stubs()
      M.clear_loci_commands()
      M.clear_loci_runtime_state()
      restore_vault()
      restore_root()
      M.reset_modules()
      M.remove_tmpdir(vault_path)
      M.remove_tmpdir(tmpdir)
    end,
  }
end

function M.async_with_repo(fn, opts)
  return M.async_test(function()
    local ctx = M.create_test_repo(opts)
    run_with_cleanup(function()
      fn(ctx)
    end, ctx.cleanup)
  end, opts)
end

function M.async_with_initialized_repo(fn, opts)
  return M.async_with_repo(function(ctx)
    local repository = require('loci.service.repository')
    M.expect_ok(repository.init({ now = '2026-05-23T10:00:00Z' }))
    fn(ctx)
  end, opts)
end

---@async
---@param dir string
function M.async_mkdirp(dir)
  local fs = require('loci.store.fs')
  local r = fs.mkdir_p(dir)
  M.expect_ok(r)
  return dir
end

---@async
---@param filepath string
---@param text string
function M.async_write_file(filepath, text)
  local fs = require('loci.store.fs')
  local r = fs.write_file(filepath, text)
  M.expect_ok(r)
  return filepath
end

---@async
---@param filepath string
---@return string
function M.async_read_file(filepath)
  local fs = require('loci.store.fs')
  return M.expect_ok(fs.read_file(filepath))
end

---@async
---@param path string
function M.async_rm_rf(path)
  if not path or path == '' then
    return
  end
  local err, stat = nio.uv.fs_stat(path)
  if err or not stat then
    return
  end
  if stat.type == 'directory' then
    local scan_err, handle = nio.uv.fs_scandir(path)
    if scan_err == nil and handle then
      while true do
        local name = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end
        M.async_rm_rf(path .. '/' .. name)
      end
    end
    local rmdir_err = nio.uv.fs_rmdir(path)
    if rmdir_err then
      error('rmdir failed for ' .. path .. ': ' .. tostring(rmdir_err))
    end
  else
    local unlink_err = nio.uv.fs_unlink(path)
    if unlink_err then
      error('unlink failed for ' .. path .. ': ' .. tostring(unlink_err))
    end
  end
end

---@async
---@param cmd string
function M.async_cmd(cmd)
  M.await_main()
  vim.cmd(cmd)
end

---@async
---@param filepath string
function M.async_edit(filepath)
  M.await_main()
  vim.cmd('noswapfile edit ' .. vim.fn.fnameescape(filepath))
end

---@async
function M.async_enew()
  M.await_main()
  vim.cmd('enew')
end

---@async
---@param ms integer
function M.async_sleep(ms)
  nio.sleep(ms or 10)
end

---@async
---@param timeout integer
---@param predicate function
---@param interval? integer
function M.async_wait_until(timeout, predicate, interval)
  local deadline = vim.uv.hrtime() + (timeout * 1000000)
  interval = interval or 10
  while vim.uv.hrtime() < deadline do
    M.await_main()
    if predicate() then
      return true
    end
    nio.sleep(interval)
  end
  M.await_main()
  return predicate() == true
end

---@param r table
---@return any
function M.expect_ok(r)
  if type(r) ~= "table" then
    error("expected Result table, got " .. type(r))
  end
  if r.ok ~= true then
    error("expected ok Result, got code=" .. tostring(r.code) .. " err=" .. tostring(r.err))
  end
  return r.value
end

function M.expect_meta(r)
  if type(r) ~= "table" then
    error("expected Result table, got " .. type(r))
  end
  if type(r.meta) ~= "table" then
    error("expected Result.meta table")
  end
  return r.meta
end

---@param r table
---@param expected_code? string
---@return string the error message
function M.expect_err(r, expected_code)
  expect.equality(type(r), 'table')
  expect.equality(r.ok, false)
  expect.no_equality(r.err, nil)
  if expected_code then
    expect.equality(r.code, expected_code)
  end
  return r.err
end

function M.expect_match(value, pattern, context)
  expect.equality(type(value), "string", context)
  expect.no_equality(value:match(pattern), nil, context or pattern)
end

---@param haystack string
---@param needle string
---@param context? string
function M.expect_contains(haystack, needle, context)
  expect.equality(type(haystack), 'string', context)
  expect.equality(type(needle), 'string', context)
  expect.no_equality(haystack:find(needle, 1, true), nil, context or needle)
end

---@param haystack string
---@param needle string
---@param context? string
function M.expect_not_contains(haystack, needle, context)
  expect.equality(type(haystack), 'string', context)
  expect.equality(type(needle), 'string', context)
  expect.equality(haystack:find(needle, 1, true), nil, context or needle)
end

function M.plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":p:h:h")
end

function M.repo_file(relpath)
  return M.plugin_root() .. "/" .. relpath
end

function M.expect_initialized_repo(root)
  local required = {
    root .. "/.loci/repository.json",
    root .. "/.loci/graph/current.json",
  }
  for _, p in ipairs(required) do
    if not vim.uv.fs_stat(p) then
      error("expected initialized repo file missing: " .. p)
    end
  end

  -- Verify the fallback workspace file also exists.
  local ok, repo = pcall(
    vim.fn.json_decode,
    table.concat(vim.fn.readfile(root .. "/.loci/repository.json"), "\n")
  )
  if not ok or type(repo) ~= "table" or type(repo.default_workspace_id) ~= "string" then
    error("expected initialized repo: repository.json is not valid")
  end
  local ws_path = root .. "/.loci/graph/workspaces/" .. repo.default_workspace_id .. ".json"
  if not vim.uv.fs_stat(ws_path) then
    error("expected initialized repo file missing: " .. ws_path)
  end
end

---@param path string
---@return table
function M.read_json(path)
  local f = io.open(path, 'r')
  if not f then
    error('Could not open file: ' .. path)
  end
  local content = f:read('*a')
  f:close()
  return vim.json.decode(content)
end

---@param path string
---@param value table
function M.write_json(path, value)
  local encoded = vim.json.encode(value)
  local f = io.open(path, 'w')
  f:write(encoded .. '\n')
  f:close()
end

---@param path string
---@return string
function M.read_file(path)
  local f = io.open(path, 'r')
  if not f then
    error('Could not open file: ' .. path)
  end
  local content = f:read('*a')
  f:close()
  return content
end

---@param path string
---@param text string
function M.write_file(path, text)
  local f = io.open(path, 'w')
  f:write(text)
  f:close()
end

---@param fn function callback that receives context table
function M.with_repo(fn)
  local tmpdir = M.create_tmpdir()
  local restore = M.patch_project_root(tmpdir)
  local editor_state = M.capture_editor_state()
  M.init_loci_dir(tmpdir)

  local ctx = {
    tmpdir = tmpdir,
    loci_root = tmpdir .. '/.loci',
  }

  run_with_cleanup(function()
    fn(ctx)
  end, function()
    M.restore_editor_state(editor_state)
    M.clear_integration_stubs()
    M.clear_loci_commands()
    M.clear_loci_runtime_state()
    restore()
    M.reset_modules()
    M.remove_tmpdir(tmpdir)
  end)
end

---@param tmpdir string
function M.assert_not_cwd_under(tmpdir)
  M.ensure_main()
  local cwd = vim.fn.getcwd(-1, -1)
  local tab_cwd = vim.fn.getcwd(0, 0)
  if cwd:sub(1, #tmpdir) == tmpdir then
    error('global cwd still points inside deleted temp repo: ' .. cwd)
  end
  if tab_cwd:sub(1, #tmpdir) == tmpdir then
    error('tab cwd still points inside deleted temp repo: ' .. tab_cwd)
  end
end

---Create a complete Phase 6 test fixture with repository, fallback workspace, project, and workspace.
---@param opts? table optional {now = clock_func, with_primary_markdown = true}
---@return table context
function M.create_phase6_fixture(opts)
  opts = opts or {}
  local now = opts.now or function() return "2026-05-23T10:00:00Z" end
  local with_primary = opts.with_primary_markdown ~= false

  local tmpdir = M.create_tmpdir()
  local restore = M.patch_project_root(tmpdir)
  M.init_loci_dir(tmpdir)
  M.reset_modules()

  local path_store = require("loci.store.path")
  local repository_domain = require("loci.domain.repository")
  local workspace_domain = require("loci.domain.workspace")
  local project_domain = require("loci.domain.project")

  local timestamp = now()
  local loci_root = tmpdir .. "/.loci"

  -- Create repository
  local repository_r = repository_domain.new({
    root = tmpdir,
    repository_id = "loci-plugin-4k9m2q",
    default_workspace_id = "fallback-main-8x2kqz",
    name = "Test Repository",
    created_at = timestamp,
    last_refreshed_at = timestamp,
  })
  if not repository_r.ok then
    error("Failed to create repository: " .. repository_r.err)
  end
  local repository = repository_r.value

  -- Create fallback workspace
  local fallback_workspace = workspace_domain.default_for_repository(repository, {
    workspace_id = "fallback-main-8x2kqz",
    created_at = timestamp,
    last_refreshed_at = timestamp,
  })

  -- Create project
  local project_r = project_domain.new({
    project_id = "loci-v3-redesign-4k9m2q",
    title = "LOCI V3 Redesign",
    content_path = "projects/loci-v3-redesign.md",
    now = timestamp,
  })
  if not project_r.ok then
    error("Failed to create project: " .. project_r.err)
  end
  local project = project_r.value

  -- Create project workspace
  local workspace = workspace_domain.new({
    workspace_id = "parser-fix-main-8x2kqz",
    project_id = "loci-v3-redesign-4k9m2q",
    name = "Parser fix main",
    label = "Parser fix",
    branch = "loci/parser-fix",
    worktree_path = nil,
    created_at = timestamp,
    last_refreshed_at = timestamp,
  })

  -- Write all graphs using synchronous I/O (required during test setup)
  vim.fn.mkdir(loci_root .. "/graph/workspaces", "p")
  vim.fn.mkdir(loci_root .. "/graph/projects", "p")

  M.write_json(loci_root .. "/repository.json", repository)
  M.write_json(loci_root .. "/graph/workspaces/" .. fallback_workspace.workspace_id .. ".json", fallback_workspace)
  M.write_json(loci_root .. "/graph/projects/" .. project.project_id .. ".json", project)
  M.write_json(loci_root .. "/graph/workspaces/" .. workspace.workspace_id .. ".json", workspace)
  M.write_json(loci_root .. "/graph/current.json", {
    repository_id = repository.repository_id,
    project_id = vim.NIL,
    workspace_id = fallback_workspace.workspace_id,
    activated_at = timestamp,
  })

  -- Create primary markdown if requested
  local primary_markdown = nil
  if with_primary then
    local task_dir = path_store.must_content_path("tasks")
    vim.fn.mkdir(task_dir, "p")

    local primary_path = task_dir .. "/primary-task.md"
    local primary_content = table.concat({
      "---",
      "loci_id: fix-parser-edge-case-7f3a9c",
      "title: Fix parser edge case",
      "type: task",
      "status: open",
      "---",
      "",
      "# Fix parser edge case",
    }, "\n")

    M.write_file(primary_path, primary_content .. "\n")

    -- Store the markdown info in the workspace
    primary_markdown = {
      loci_id = "fix-parser-edge-case-7f3a9c",
      title = "Fix parser edge case",
      type = "task",
      content_path = "tasks/primary-task.md",
    }

    -- Add to workspace knowledge
    local entry = workspace_domain.knowledge_entry(primary_markdown, "primary")
    table.insert(workspace.knowledge.objects, entry)
    workspace.knowledge.primary_loci_id = primary_markdown.loci_id

    -- Write updated workspace
    M.write_json(loci_root .. "/graph/workspaces/" .. workspace.workspace_id .. ".json", workspace)
  end

  return {
    tmpdir = tmpdir,
    loci = loci_root,
    restore = restore,
    repository = repository,
    fallback_workspace = fallback_workspace,
    project = project,
    workspace = workspace,
    primary_markdown = primary_markdown,
    cleanup = function()
      M.restore_editor_state(editor_state)
      M.clear_integration_stubs()
      M.clear_loci_commands()
      M.clear_loci_runtime_state()
      restore()
      M.reset_modules()
      M.remove_tmpdir(tmpdir)
    end,
  }
end

function M.async_with_phase7_fixture(fn, opts)
  return M.async_test(function()
    local ctx = M.create_phase7_fixture(opts)
    run_with_cleanup(function()
      fn(ctx)
    end, function()
      vim.t.loci_workspace_id = nil
      package.loaded["haunt.api"] = nil
      ctx.cleanup()
    end)
  end, opts)
end

---Create a Phase 7 fixture (extends Phase 6 with Haunt contexts).
---@param opts? table
---@return table
function M.create_phase7_fixture(opts)
  local ctx = M.create_phase6_fixture(opts)

  local workspace_path = ctx.loci .. "/graph/workspaces/" .. ctx.workspace.workspace_id .. ".json"
  local workspace = M.read_json(workspace_path)

  workspace.haunt = {
    active = "main",
    contexts = {
      main = {
        data_dir = ".loci/integrations/haunt/workspaces/" .. workspace.workspace_id .. "/main",
      },
    },
  }

  M.write_json(workspace_path, workspace)
  vim.fn.mkdir(ctx.loci .. "/integrations/haunt/workspaces/" .. workspace.workspace_id .. "/main", "p")

  ctx.workspace = workspace
  ctx.workspace_path = workspace_path
  ctx.haunt_root = ctx.loci .. "/integrations/haunt/workspaces/" .. workspace.workspace_id
  return ctx
end

---Stub Haunt API for testing.
---@return table calls table with recorded change_data_dir calls
function M.stub_haunt_api()
  local calls = {}
  package.loaded["haunt.api"] = {
    change_data_dir = function(path)
      table.insert(calls, path)
      return true
    end,
  }
  local haunt_mod = package.loaded["loci.integrations.haunt"]
  if type(haunt_mod) == "table" and type(haunt_mod.reset_for_tests) == "function" then
    haunt_mod.reset_for_tests()
  end
  return calls
end

---Stub Haunt API that fails.
function M.stub_failing_haunt_api()
  package.loaded["haunt.api"] = {
    change_data_dir = function()
      error("boom")
    end,
  }
  local haunt_mod = package.loaded["loci.integrations.haunt"]
  if type(haunt_mod) == "table" and type(haunt_mod.reset_for_tests) == "function" then
    haunt_mod.reset_for_tests()
  end
end

---Create a Phase 8 fixture (extends Phase 7 with Wayfinder Trail registry).
---@param opts? table
---@return table
function M.create_phase8_fixture(opts)
  local ctx = M.create_phase7_fixture(opts)

  local workspace_path = ctx.loci .. "/graph/workspaces/" .. ctx.workspace.workspace_id .. ".json"
  local workspace = M.read_json(workspace_path)

  workspace.wayfinder = {
    active = "main",
    trails = {
      main = {
        trail_name = "loci-" .. workspace.workspace_id .. "-main",
      },
    },
  }

  M.write_json(workspace_path, workspace)

  ctx.workspace = workspace
  ctx.workspace_path = workspace_path
  return ctx
end

function M.async_with_phase8_fixture(fn, opts)
  return M.async_test(function()
    local ctx = M.create_phase8_fixture(opts)
    M.install_wayfinder_command_stubs()
    run_with_cleanup(function()
      fn(ctx)
    end, function()
      M.clear_wayfinder_command_stubs()
      M.clear_wayfinder_stubs()
      ctx.cleanup()
    end)
  end, opts)
end

---Install Wayfinder command stubs for testing.
---@param called? table optional table to record calls
---@return table calls table with recorded command calls
function M.install_wayfinder_command_stubs(called)
  called = called or {}
  local commands = {
    "WayfinderTrailSave",
    "WayfinderTrailSaveAs",
    "WayfinderTrailLoad",
    "WayfinderTrailResume",
    "WayfinderTrailDelete",
    "WayfinderTrailRename",
    "WayfinderTrailShow",
    "WayfinderExportTrailQuickfix",
  }

  for _, name in ipairs(commands) do
    pcall(vim.api.nvim_del_user_command, name)
    vim.api.nvim_create_user_command(name, function()
      table.insert(called, name)
    end, {})
  end

  return called
end

---Clear Wayfinder command stubs.
function M.clear_wayfinder_command_stubs()
  local commands = {
    "WayfinderTrailSave",
    "WayfinderTrailSaveAs",
    "WayfinderTrailLoad",
    "WayfinderTrailResume",
    "WayfinderTrailDelete",
    "WayfinderTrailRename",
    "WayfinderTrailShow",
    "WayfinderExportTrailQuickfix",
  }
  for _, name in ipairs(commands) do
    pcall(vim.api.nvim_del_user_command, name)
  end
end

---Stub Wayfinder direct API for testing.
---@return table with trail, saved, loaded, deleted, renamed tables
function M.stub_wayfinder_direct_api()
  package.loaded["wayfinder"] = {
    trail = {
      loaded = {},
      saved = {},
      deleted = {},
      renamed = {},
      load_named = function(name)
        table.insert(package.loaded["wayfinder"].trail.loaded, name)
      end,
      save_named = function(name)
        table.insert(package.loaded["wayfinder"].trail.saved, name)
      end,
      delete_named = function(name)
        table.insert(package.loaded["wayfinder"].trail.deleted, name)
      end,
      rename = function(old_name, new_name)
        table.insert(package.loaded["wayfinder"].trail.renamed, { old_name, new_name })
      end,
    },
  }
  return package.loaded["wayfinder"].trail
end

---Clear Wayfinder API stub.
function M.clear_wayfinder_stubs()
  package.loaded["wayfinder"] = nil
end

-- ============================================================================
-- Health Testing Helpers
-- ============================================================================

---Create a complete initialized health fixture.
---@param opts? table optional {now = clock_func}
---@return table context with tmpdir, loci_root, cleanup
function M.with_health_repo(fn)
  local ctx = M.create_test_repo({
    config = {
      integrations = {
        tabby     = { enabled = false },
        resession = { enabled = false },
        haunt     = { enabled = false },
        wayfinder = { enabled = false, require_named_api = false },
        tasknotes = { enabled = false },
        obsidian  = { enabled = false },
      },
    },
  })

  run_with_cleanup(function()
    local now = "2026-05-23T10:00:00Z"
    local repository_domain = require("loci.domain.repository")
    local workspace_domain = require("loci.domain.workspace")

    vim.fn.mkdir(ctx.loci_root .. "/graph/workspaces", "p")
    vim.fn.mkdir(ctx.loci_root .. "/graph/projects", "p")
    vim.fn.mkdir(ctx.loci_root .. "/content", "p")
    vim.fn.mkdir(ctx.loci_root .. "/indexes", "p")
    vim.fn.mkdir(ctx.loci_root .. "/integrations", "p")

    M.write_json(ctx.loci_root .. "/loci.json", {
      schema_version = 1,
      kind = "loci",
      created_at = now,
    })

    local repository_r = repository_domain.new({
      root = ctx.tmpdir,
      repository_id = "test-repo-123456",
      default_workspace_id = "fallback-main-xyz123",
      name = "Test Repository",
      created_at = now,
      last_refreshed_at = now,
    })
    if not repository_r.ok then
      error("Failed to create repository: " .. repository_r.err)
    end
    local repository = repository_r.value

    local fallback_workspace = workspace_domain.default_for_repository(repository, {
      workspace_id = repository.default_workspace_id,
      created_at = now,
      last_refreshed_at = now,
    })

    M.write_json(ctx.loci_root .. "/repository.json", repository)
    M.write_json(ctx.loci_root .. "/graph/workspaces/" .. fallback_workspace.workspace_id .. ".json", fallback_workspace)
    M.write_json(ctx.loci_root .. "/graph/current.json", {
      repository_id = repository.repository_id,
      project_id = vim.NIL,
      workspace_id = fallback_workspace.workspace_id,
      activated_at = now,
    })

    ctx.repository = repository
    ctx.fallback_workspace = fallback_workspace

    fn(ctx)
  end, ctx.cleanup)
end

---Remove a file synchronously for health testing.
---@param path string
function M.remove_file(path)
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

---Write text file (already have M.write_file, but adding for clarity in health context).
---@param path string
---@param text string
function M.write_text(path, text)
  M.write_file(path, text)
end

---Write invalid JSON file.
---@param path string
---@param text string invalid JSON text
function M.write_invalid_json(path, text)
  M.write_file(path, text)
end

---Find a health item by code.
---@param report table health report
---@param code string item code to find
---@return table|nil health item or nil
function M.find_health_item(report, code)
  for _, item in ipairs(report.items) do
    if item.code == code then
      return item
    end
  end
  return nil
end

---Assert a health item has expected status.
---@param report table health report
---@param code string item code
---@param status string expected status
function M.expect_health_status(report, code, status)
  local item = M.find_health_item(report, code)
  if not item then
    error("Health item not found: " .. code)
  end
  if item.status ~= status then
    error("Expected status '" .. status .. "' but got '" .. item.status .. "' for code: " .. code)
  end
end

return M
