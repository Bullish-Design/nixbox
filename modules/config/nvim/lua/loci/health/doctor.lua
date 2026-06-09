local result = require("loci.result")
local util = require("loci.ui.commands.util")

local M = {}

local REMEDIATION = {
  loci_root_missing = {
    severity = "blocking",
    summary = "Initialize LOCI for this repository.",
    commands = { ":LociInit" },
    docs = "docs/loci/repository-initialization.md",
  },
  loci_dir_missing = {
    severity = "blocking",
    summary = "Initialize LOCI for this repository.",
    commands = { ":LociInit" },
    docs = "docs/loci/repository-initialization.md",
  },
  loci_json_missing = {
    severity = "blocking",
    summary = "The LOCI sentinel is missing. Re-run initialization or restore .loci/loci.json from version control if appropriate.",
    commands = { ":LociInit" },
    docs = "docs/loci/repository-initialization.md",
  },
  repository_json_missing = {
    severity = "blocking",
    summary = "Repository graph metadata is missing. Re-run initialization in a clean repo or restore .loci/repository.json.",
    commands = { ":LociInit", ":LociHealth" },
    docs = "docs/loci/repository-initialization.md",
  },
  current_workspace_missing = {
    severity = "repairable",
    summary = "The current pointer references a missing Workspace. Open the repository fallback Workspace or choose an existing Workspace.",
    commands = { ":LociRepositoryOpen", ":LociWorkspaceSwitch" },
    docs = "docs/loci/workspace-lifecycle.md",
  },
  fallback_workspace_missing = {
    severity = "blocking",
    summary = "The repository fallback Workspace graph is missing. Re-run initialization only after confirming existing graph state is safe.",
    commands = { ":LociInit", ":LociHealth" },
    docs = "docs/loci/workspace-lifecycle.md",
  },
  project_markdown_missing = {
    severity = "repairable",
    summary = "A Project graph points to missing Markdown. Restore the project note or run refresh after intentionally moving it.",
    commands = { ":LociRefresh", ":LociProjectSwitch" },
    docs = "docs/loci/repository-initialization.md",
  },
  workspace_knowledge_missing = {
    severity = "repairable",
    summary = "A Workspace knowledge association points to missing Markdown. Restore the note or remove the association.",
    commands = { ":LociRefresh", ":LociWorkspaceInfo" },
    docs = "docs/loci/workspace-lifecycle.md",
  },
  haunt_dir_missing = {
    severity = "repairable",
    summary = "A Haunt context directory is missing. Switch to the context or recreate the directory under .loci/integrations/haunt/workspaces/.",
    commands = { ":LociHauntList", ":LociHauntSwitch" },
    docs = "docs/loci/haunt-contexts.md",
  },
  haunt_unavailable = {
    severity = "optional",
    summary = "Haunt is enabled but not available. Install/enable Haunt, or disable the integration in LOCI config.",
    commands = { ":LociHealth" },
    docs = "docs/loci/haunt-contexts.md",
  },
  wayfinder_unavailable = {
    severity = "optional",
    summary = "Wayfinder is enabled but not available. Install/enable Wayfinder, or disable the integration in LOCI config.",
    commands = { ":LociTrailList", ":LociHealth" },
    docs = "docs/loci/wayfinder-trails.md",
  },
  resession_unavailable = {
    severity = "optional",
    summary = "Resession is enabled but unavailable. Workspace activation still works, but tab sessions will not be saved/restored.",
    commands = { ":LociWorkspaceSwitch" },
    docs = "docs/loci/workspace-lifecycle.md",
  },
  tabby_unavailable = {
    severity = "optional",
    summary = "Tabby is enabled but unavailable. LOCI should use native tabs or degrade gracefully.",
    commands = { ":LociWorkspaceSwitch" },
    docs = "docs/loci/workspace-lifecycle.md",
  },
  obsidian_unavailable = {
    severity = "optional",
    summary = "obsidian.nvim is unavailable. LOCI can still create the vault symlink, but Obsidian-specific Neovim commands may not exist.",
    commands = { ":LociHealth" },
    docs = "docs/loci/obsidian-symlink-setup.md",
  },
  obsidian_not_configured = {
    severity = "configuration",
    summary = "Vault path/project path are not configured. Add vault settings to .loci/loci.json or require('loci').setup().",
    commands = { ":LociHealth" },
    docs = "docs/loci/obsidian-symlink-setup.md",
  },
  tasknotes_unavailable = {
    severity = "optional",
    summary = "TaskNotes is unavailable. LOCI task delegation commands will warn but should not mutate task lifecycle state.",
    commands = { ":TaskBrowse" },
    docs = "docs/loci/tasknotes-delegation.md",
  },
  bases_unavailable = {
    severity = "optional",
    summary = "bases.nvim is unavailable. LOCI can still generate .base files, but validation may be skipped.",
    commands = { ":LociRefresh" },
    docs = "docs/loci/obsidian-symlink-setup.md",
  },
}

local PREFIX_RULES = {
  {
    prefix = "project_graph_",
    hint = {
      severity = "repairable",
      summary = "A Project graph file is missing, malformed, or inconsistent. Inspect the graph file and run refresh after correcting it.",
      commands = { ":LociRefresh", ":LociProjectSwitch" },
      docs = "docs/loci/repository-initialization.md",
    },
  },
  {
    prefix = "workspace_graph_",
    hint = {
      severity = "repairable",
      summary = "A Workspace graph file is missing, malformed, or inconsistent. Inspect the graph file and run refresh after correcting it.",
      commands = { ":LociRefresh", ":LociWorkspaceSwitch" },
      docs = "docs/loci/workspace-lifecycle.md",
    },
  },
  {
    prefix = "markdown_",
    hint = {
      severity = "repairable",
      summary = "A Markdown association or frontmatter issue was found. Fix the Markdown file, then run refresh.",
      commands = { ":LociNoteAdopt", ":LociRefresh" },
      docs = "docs/loci/workspace-lifecycle.md",
    },
  },
  {
    prefix = "vault_symlink_",
    hint = {
      severity = "configuration",
      summary = "The Obsidian vault symlink is missing or points somewhere unexpected. Review vault config and re-run initialization/health.",
      commands = { ":LociHealth" },
      docs = "docs/loci/obsidian-symlink-setup.md",
    },
  },
}

local function deepcopy(value)
  return vim.deepcopy(value)
end

function M.hint_for_code(code)
  if not code or code == "" then
    return nil
  end

  if REMEDIATION[code] then
    return deepcopy(REMEDIATION[code])
  end

  for _, rule in ipairs(PREFIX_RULES) do
    if code:sub(1, #rule.prefix) == rule.prefix then
      return deepcopy(rule.hint)
    end
  end

  return nil
end

function M.hints_for_item(item)
  local hint = M.hint_for_code(item and item.code)
  if not hint then
    return {}
  end
  return { hint }
end

function M.annotate(report)
  local annotated = vim.deepcopy(report)
  annotated.doctor = {
    hints = 0,
    blocking = 0,
    repairable = 0,
    optional = 0,
    configuration = 0,
  }

  for _, item in ipairs(annotated.items or {}) do
    item.remediation = M.hints_for_item(item)
    for _, hint in ipairs(item.remediation) do
      annotated.doctor.hints = annotated.doctor.hints + 1
      if annotated.doctor[hint.severity] ~= nil then
        annotated.doctor[hint.severity] = annotated.doctor[hint.severity] + 1
      end
    end
  end

  return annotated
end

local function status_icon(status)
  if status == "error" then
    return "ERROR"
  elseif status == "warn" then
    return "WARN"
  elseif status == "ok" then
    return "OK"
  end
  return "INFO"
end

function M.format_report(report, opts)
  opts = opts or {}
  local annotated = M.annotate(report)
  local lines = {}

  table.insert(lines, "# LOCI Doctor")
  table.insert(lines, "")
  table.insert(lines, "Generated: " .. tostring(annotated.generated_at or "unknown"))
  table.insert(lines, "Root: " .. tostring(annotated.root or "unknown"))
  table.insert(lines, "")
  table.insert(lines, string.format(
    "Summary: %d error(s), %d warning(s), %d info, %d ok",
    annotated.counts and annotated.counts.error or 0,
    annotated.counts and annotated.counts.warn or 0,
    annotated.counts and annotated.counts.info or 0,
    annotated.counts and annotated.counts.ok or 0
  ))
  table.insert(lines, string.format(
    "Remediation hints: %d total (%d blocking, %d repairable, %d optional, %d configuration)",
    annotated.doctor.hints,
    annotated.doctor.blocking,
    annotated.doctor.repairable,
    annotated.doctor.optional,
    annotated.doctor.configuration
  ))
  table.insert(lines, "")

  local sections = annotated.sections or {}
  for _, section in ipairs(sections) do
    local section_started = false
    for _, item in ipairs(annotated.items or {}) do
      local include = opts.include_ok or item.status ~= "ok"
      if item.section == section and include then
        if not section_started then
          table.insert(lines, "## " .. section)
          table.insert(lines, "")
          section_started = true
        end

        table.insert(lines, "- [" .. status_icon(item.status) .. "] " .. tostring(item.code) .. ": " .. tostring(item.message))
        if item.path then
          table.insert(lines, "  - Path: `" .. tostring(item.path) .. "`")
        end
        if item.id then
          table.insert(lines, "  - ID: `" .. tostring(item.id) .. "`")
        end
        for _, hint in ipairs(item.remediation or {}) do
          table.insert(lines, "  - Fix: " .. hint.summary)
          if hint.commands and #hint.commands > 0 then
            table.insert(lines, "  - Commands: `" .. table.concat(hint.commands, "`, `") .. "`")
          end
          if hint.docs then
            table.insert(lines, "  - Docs: `" .. hint.docs .. "`")
          end
        end
      end
    end
    if section_started then
      table.insert(lines, "")
    end
  end

  if #lines == 8 then
    table.insert(lines, "No actionable health findings.")
  end

  return lines
end

function M.collect(opts)
  local health = require("loci.health")
  local r = health.collect(opts)
  if not r.ok then
    return r
  end
  return result.ok(M.annotate(r.value))
end

function M.open(opts)
  opts = opts or {}
  local health = require("loci.health")
  local r = health.collect(opts)
  if not r.ok then
    util.notify_result("LOCI: Doctor failed", r)
    return r
  end

  local lines = M.format_report(r.value, opts)
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, "LOCI Doctor")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  return result.ok({ buffer = buf, lines = lines })
end

return M
