local types = require("blink.cmp.types")

local M = {}
M.__index = M

function M.new(opts)
  local self = setmetatable({}, M)
  self.opts = opts or {}
  return self
end

function M:enabled()
  return vim.bo.filetype == "input-form" and vim.b.loci_tag_input == true
end

function M:get_trigger_characters()
  return { "," }
end

function M:get_completions(_, callback)
  local ok, loci_tags = pcall(require, "loci.tags")
  if not ok then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local items = {}
  for _, tag in ipairs(loci_tags.list()) do
    items[#items + 1] = {
      label = tag,
      kind = types.CompletionItemKind.Text,
      insertText = tag,
      documentation = { kind = "markdown", value = "Loci tag" },
    }
  end

  callback({
    items = items,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

return M
