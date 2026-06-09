local notes = require("productivity.notes")
local obsidian_vault = vim.fn.expand("~/Documents/Notes")

local function ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

-- Ensure TaskNotes/Obsidian paths exist before plugin startup.
ensure_dir(notes.project_notes_dir())
ensure_dir(notes.project_tasks_dir())
ensure_dir(obsidian_vault .. "/TaskNotes")
ensure_dir(obsidian_vault .. "/TaskNotes/Views")

require("tasknotes").setup({
  vault_path = notes.project_tasks_dir(),
  cache = {
    filename = "cache-" .. notes.project_name() .. ".json",
  },
  obsidian = {
    enabled = true,
    vault_path = obsidian_vault,
  },
  -- Add project context to task frontmatter
  field_mapping = {
    title = "title",
    status = "status",
    priority = "priority",
    due = "due",
    scheduled = "scheduled",
    contexts = "contexts",
    projects = "projects",
    tags = "tags",
    timeEstimate = "timeEstimate",
    timeEntries = "timeEntries",
    completedDate = "completedDate",
    dateCreated = "dateCreated",
    dateModified = "dateModified",
  },
})

-- Hook into TaskNotesNew to inject project link into frontmatter
vim.api.nvim_create_autocmd("BufNewFile", {
  group = vim.api.nvim_create_augroup("TaskNotesProjectLink", { clear = true }),
  pattern = vim.fn.expand("~/Documents/Notes/1_Projects") .. "/**/tasks/*.md",
  callback = function(event)
    -- Defer so tasknotes has time to write its frontmatter first
    vim.defer_fn(function()
      local buf = event.buf
      if not vim.api.nvim_buf_is_valid(buf) then return end

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      -- Find the closing --- of frontmatter and inject project link before it
      local end_idx = nil
      local has_project = false
      for i, line in ipairs(lines) do
        if line:match("^project:") then
          has_project = true
        end
        if i > 1 and line == "---" then
          end_idx = i
          break
        end
      end

      if end_idx and not has_project then
        local project = notes.project_name()
        local project_line = "project: \"[[" .. project .. "]]\""
        local project_root_line = "project_root: " .. (vim.fs.root(0, ".git") or vim.fn.getcwd())
        vim.api.nvim_buf_set_lines(buf, end_idx - 1, end_idx - 1, false, {
          project_line,
          project_root_line,
        })
      end
    end, 100)
  end,
})
