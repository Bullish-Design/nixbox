local M = {}

local function split_csv(value)
  local out = {}
  for item in tostring(value or ""):gmatch("[^,]+") do
    item = vim.trim(item)
    if item ~= "" then
      out[item] = true
    end
  end
  return out
end

local required = split_csv(vim.env.LOCI_MANUAL_REQUIRED or "haunt,wayfinder,resession,tabby")

local state = {
  passed = 0,
  failed = 0,
  skipped = 0,
  failures = {},
}

local function line(message)
  io.stdout:write(message .. "\n")
  io.stdout:flush()
end

local function pass(name, message)
  state.passed = state.passed + 1
  line("[PASS] " .. name .. (message and (" — " .. message) or ""))
end

local function skip(name, message)
  state.skipped = state.skipped + 1
  line("[SKIP] " .. name .. (message and (" — " .. message) or ""))
end

local function fail(name, message)
  state.failed = state.failed + 1
  table.insert(state.failures, { name = name, message = message })
  line("[FAIL] " .. name .. " — " .. tostring(message))
end

local function require_or_fail(name, module_name)
  local ok, mod = pcall(require, module_name)
  if ok then
    return mod
  end
  if required[name] then
    fail(name, "required module unavailable: " .. module_name .. ": " .. tostring(mod))
  else
    skip(name, "module unavailable: " .. module_name)
  end
  return nil
end

local function command_exists(command)
  return vim.fn.exists(":" .. command) == 2
end

local function command_or_fail(name, command)
  if command_exists(command) then
    return true
  end
  if required[name] then
    fail(name, "required command unavailable: :" .. command)
  else
    skip(name, "command unavailable: :" .. command)
  end
  return false
end

local function expect_ok(name, r)
  if r and r.ok then
    return r.value
  end
  fail(name, r and (r.err or r.code) or "result was nil")
  return nil
end

local function setup_repository()
  local loci = require("loci")
  loci.setup({
    refresh = { on_setup = false, before_picker = false },
    integrations = {
      haunt = true,
      wayfinder = true,
      resession = true,
      tabby = true,
      tasknotes = false,
      obsidian = false,
      bases = false,
    },
  })

  local repository = require("loci.service.repository")
  local workspace = require("loci.service.workspace")

  expect_ok("repository.init", repository.init({ name = "loci-manual-validation" }))
  local ws = expect_ok("workspace.create", workspace.create({
    name = "Manual Integration Validation",
    now = "2026-05-23T10:00:00Z",
  }))

  return ws
end

local function validate_resession(ws)
  local resession = require_or_fail("resession", "resession")
  if not resession then
    return
  end

  local activation = require("loci.service.activation")
  local r1 = activation.activate(ws.workspace_id, {
    notify = false,
    open_primary = false,
    clock = function() return "2026-05-23T10:01:00Z" end,
  })
  if not r1.ok then
    fail("resession", "activation failed before resession validation: " .. tostring(r1.err))
    return
  end

  local r2 = activation.deactivate_current({
    notify = false,
    clock = function() return "2026-05-23T10:02:00Z" end,
  })
  if not r2.ok then
    fail("resession", "deactivation failed: " .. tostring(r2.err))
    return
  end

  pass("resession", "workspace activate/deactivate completed with real adapter available")
end

local function validate_tabby(ws)
  -- Tabby exposes several module shapes across versions. LOCI's adapter owns the exact integration.
  local tabby_available = pcall(require, "tabby") or pcall(require, "tabby.tab")
  if not tabby_available then
    if required.tabby then
      fail("tabby", "tabby module unavailable")
    else
      skip("tabby", "tabby module unavailable")
    end
    return
  end

  local activation = require("loci.service.activation")
  local before = vim.fn.tabpagenr("$")
  local r = activation.activate(ws.workspace_id, {
    notify = false,
    open_primary = false,
    clock = function() return "2026-05-23T10:03:00Z" end,
  })
  if not r.ok then
    fail("tabby", "activation failed: " .. tostring(r.err))
    return
  end

  local after = vim.fn.tabpagenr("$")
  if vim.t.loci_workspace_id ~= ws.workspace_id then
    fail("tabby", "tab-local workspace id was not set")
    return
  end

  pass("tabby", "activation set tab-local workspace id; tabs before=" .. before .. ", after=" .. after)
end

local function validate_haunt(ws)
  local haunt_api = require_or_fail("haunt", "haunt.api")
  if not haunt_api then
    return
  end
  if type(haunt_api.change_data_dir) ~= "function" then
    fail("haunt", "haunt.api.change_data_dir is not a function")
    return
  end

  local workspace = require("loci.service.workspace")
  local created = workspace.haunt_new(ws.workspace_id, "manual-validation", {
    switch = true,
    activate = true,
  })
  if not created.ok then
    fail("haunt", "haunt_new failed: " .. tostring(created.err))
    return
  end

  local switched = workspace.haunt_switch(ws.workspace_id, "main", { activate = true })
  if not switched.ok then
    fail("haunt", "haunt_switch back to main failed: " .. tostring(switched.err))
    return
  end

  pass("haunt", "created and switched real Haunt context")
end

local function validate_wayfinder(ws)
  if not command_or_fail("wayfinder", "WayfinderTrailResume") then
    return
  end

  local workspace = require("loci.service.workspace")
  local created = workspace.create_trail(ws.workspace_id, "manual-validation")
  if not created.ok then
    fail("wayfinder", "new_trail failed: " .. tostring(created.err))
    return
  end

  local switched = workspace.switch_trail(ws.workspace_id, "main")
  if not switched.ok then
    fail("wayfinder", "switch_trail back to main failed: " .. tostring(switched.err))
    return
  end

  local ok, err = pcall(vim.cmd, "silent! WayfinderTrailResume")
  if not ok then
    fail("wayfinder", "WayfinderTrailResume command failed: " .. tostring(err))
    return
  end

  pass("wayfinder", "created logical Trail and real resume command did not throw")
end

function M.run()
  line("== LOCI manual integration validation ==")
  line("LOCI_PROJECT_ROOT=" .. tostring(vim.env.LOCI_PROJECT_ROOT))
  line("XDG_STATE_HOME=" .. tostring(vim.env.XDG_STATE_HOME))
  line("")

  local ok, ws_or_err = pcall(setup_repository)
  if not ok or not ws_or_err then
    fail("setup", ws_or_err)
  else
    local ws = ws_or_err
    validate_tabby(ws)
    validate_resession(ws)
    validate_haunt(ws)
    validate_wayfinder(ws)
  end

  line("")
  line(string.format("Summary: %d passed, %d skipped, %d failed", state.passed, state.skipped, state.failed))

  if state.failed > 0 then
    line("")
    line("Failures:")
    for _, failure in ipairs(state.failures) do
      line("- " .. failure.name .. ": " .. tostring(failure.message))
    end
    vim.cmd("cquit 1")
  end
end

return M
