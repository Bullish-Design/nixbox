local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

T["doctor provides direct remediation for missing repository json"] = function()
  local doctor = require("loci.health.doctor")
  local hint = doctor.hint_for_code("repository_json_missing")
  expect.equality(type(hint), "table")
  expect.equality(hint.commands[1], ":LociInit")
  expect.equality(hint.docs, "docs/loci/repository-initialization.md")
end

T["doctor provides remediation for missing loci root"] = function()
  local doctor = require("loci.health.doctor")
  local hint = doctor.hint_for_code("loci_root_missing")
  expect.equality(type(hint), "table")
  expect.equality(hint.commands[1], ":LociInit")
end

T["doctor provides prefix remediation for workspace graph issues"] = function()
  local doctor = require("loci.health.doctor")
  local hint = doctor.hint_for_code("workspace_graph_decode_failed")
  expect.equality(type(hint), "table")
  expect.equality(hint.docs, "docs/loci/workspace-lifecycle.md")
end

T["doctor annotates report items with remediation"] = function()
  local doctor = require("loci.health.doctor")
  local report = {
    root = "/tmp/example",
    generated_at = "2026-05-23T10:00:00Z",
    counts = { ok = 0, warn = 1, error = 1, info = 0 },
    sections = { "Repository", "Integrations" },
    items = {
      { section = "Repository", status = "error", code = "repository_json_missing", message = "missing" },
      { section = "Integrations", status = "warn", code = "wayfinder_unavailable", message = "missing" },
    },
  }

  local annotated = doctor.annotate(report)
  expect.equality(annotated.doctor.hints, 2)
  expect.equality(#annotated.items[1].remediation, 1)
end

T["doctor formats actionable report"] = function()
  local doctor = require("loci.health.doctor")
  local lines = doctor.format_report({
    root = "/tmp/example",
    generated_at = "2026-05-23T10:00:00Z",
    counts = { ok = 0, warn = 0, error = 1, info = 0 },
    sections = { "Repository" },
    items = {
      { section = "Repository", status = "error", code = "repository_json_missing", message = "missing" },
    },
  })

  local text = table.concat(lines, "\n")
  expect.equality(text:find("LOCI Doctor", 1, true) ~= nil, true)
  expect.equality(text:find(":LociInit", 1, true) ~= nil, true)
end

return T
