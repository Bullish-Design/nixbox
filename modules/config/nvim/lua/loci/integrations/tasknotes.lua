local result = require("loci.result")
local path = require("loci.store.path")

local M = {}

local _available = nil

function M.available()
  if _available == nil then
    _available = pcall(require, "tasknotes")
  end
  return _available
end

function M.health()
  return {
    name = "tasknotes",
    available = M.available(),
    detail = M.available() and "tasknotes plugin loaded" or "tasknotes not available",
  }
end

function M.setup(opts)
  if not M.available() then
    return result.ok({ available = false, reason = "tasknotes not available" })
  end

  local cfg = require("loci.config").get()
  local tasknotes_cfg = type(cfg.integrations.tasknotes) == "table" and cfg.integrations.tasknotes or {}

  -- Resolve Obsidian vault path: config > env var > default
  local vault_path_env = vim.uv.os_getenv("LOCI_OBSIDIAN_VAULT")
  local obsidian_vault = vim.fn.expand(
    tasknotes_cfg.vault_path or vault_path_env or "~/Documents/Notes"
  )

  local function ensure_dir(dir)
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end

  local tasks_vault = path.must_content_path("tasks")
  ensure_dir(tasks_vault)
  ensure_dir(obsidian_vault .. "/TaskNotes")
  ensure_dir(obsidian_vault .. "/TaskNotes/Views")

  local tasknotes = require("tasknotes")
  tasknotes.setup({
    vault_path = tasks_vault,
    cache = {
      filename = "cache.json",
    },
    obsidian = {
      enabled = true,
      vault_path = obsidian_vault,
    },
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

  -- Register BufNewFile autocmd for project task linking when configured.
  local pattern = tasknotes_cfg.project_notes_pattern
  if type(pattern) == "string" and pattern ~= "" then
    vim.api.nvim_create_autocmd("BufNewFile", {
      group = vim.api.nvim_create_augroup("TaskNotesProjectLink", { clear = true }),
      pattern = pattern,
      callback = function(event)
        vim.defer_fn(function()
          local buf = event.buf
          if not vim.api.nvim_buf_is_valid(buf) then return end

          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          local end_idx, has_project, tags_idx = nil, false, nil
          for i, line in ipairs(lines) do
            if line:match("^project:") then has_project = true end
            if line:match("^tags:") then tags_idx = i end
            if i > 1 and line == "---" then
              end_idx = i
              break
            end
          end

          if not end_idx then return end

          local lines_to_add = {}
          if not has_project then
            local project_root = vim.fs.root(0, ".git") or vim.fn.getcwd()
            local project_name = vim.fs.basename(project_root)
            table.insert(lines_to_add, "project: \"[[" .. project_name .. "]]\"")
            table.insert(lines_to_add, "project_root: " .. project_root)
          end

          if tags_idx then
            local tags_line = lines[tags_idx]
            local tags_str = tags_line:match("^tags:%s*%[(.+)%]")
            if tags_str then
              local has_task = false
              for tag in tags_str:gmatch("%w+") do
                if tag == "task" then
                  has_task = true
                  break
                end
              end
              if not has_task then
                vim.api.nvim_buf_set_lines(buf, tags_idx - 1, tags_idx - 1, false, { "tags: [" .. tags_str .. ", task]" })
              end
            end
          else
            table.insert(lines_to_add, "tags: [task]")
          end

          if #lines_to_add > 0 then
            vim.api.nvim_buf_set_lines(buf, end_idx - 1, end_idx - 1, false, lines_to_add)
          end
        end, 100)
      end,
    })
  end

  return result.ok({})
end

return M
