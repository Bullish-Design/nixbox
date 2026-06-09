-- Unified notes system: project-scoped obsidian notes + haunt annotations
-- Notes open in a floating overlay (top-right, 1/3 width, 2/3 height).

local M = {}

local vault_path = vim.fn.expand("~/Documents/Notes")
local projects_path = vault_path .. "/1_Projects"

local function sanitize_project_name(name)
  local cleaned = tostring(name or ""):gsub("^%.+", "")
  if cleaned == "" then
    return "default"
  end
  return cleaned
end

--- Get the current project root directory name.
--- Falls back to cwd basename if no git root found.
function M.project_name()
  local root = vim.fs.root(0, ".git")
  if root then
    return sanitize_project_name(vim.fn.fnamemodify(root, ":t"))
  end
  return sanitize_project_name(vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
end

--- Get the full path to the current project's notes directory.
function M.project_notes_dir()
  return projects_path .. "/" .. M.project_name()
end

function M.project_daily_dir()
  return M.project_notes_dir() .. "/daily"
end

function M.project_tasks_dir()
  return M.project_notes_dir() .. "/tasks"
end

--- Ensure the project notes directory exists.
function M.ensure_project_dir()
  local dir = M.project_notes_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

--- Open a file in a floating window overlay (top-right, 1/3 width, 2/3 height).
function M.open_float(path)
  local buf
  if path then
    -- Check if file is already loaded in a buffer
    buf = vim.fn.bufnr(path)
    if buf == -1 then
      buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(buf, path)
      -- Load the file content
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! edit " .. vim.fn.fnameescape(path))
      end)
    end
  else
    buf = vim.api.nvim_create_buf(true, false)
  end

  local editor_w = vim.o.columns
  local editor_h = vim.o.lines - vim.o.cmdheight - 1 -- account for statusline/cmdline

  local win_w = math.floor(editor_w / 3)
  local win_h = math.floor(editor_h * 2 / 3)

  local col = editor_w - win_w - 1
  local row = 1

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_w,
    height = win_h,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = " Notes ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("linebreak", true, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  return buf, win
end

--- Create and open a new project note in a floating window.
function M.new_project_note()
  local dir = M.ensure_project_dir()
  vim.ui.input({ prompt = "Note title: " }, function(title)
    if not title or title == "" then return end
    local slug = title:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower()
    local filename = slug .. ".md"
    local filepath = dir .. "/" .. filename

    -- Create the file with frontmatter if it doesn't exist
    if vim.fn.filereadable(filepath) == 0 then
      local lines = {
        "---",
        "title: " .. title,
        "project: " .. M.project_name(),
        "created: " .. os.date("%Y-%m-%d"),
        "tags:",
        "  - project-note",
        "---",
        "",
        "",
      }
      vim.fn.writefile(lines, filepath)
    end

    M.open_float(filepath)
  end)
end

--- Open an existing project note via picker, displayed in a floating window.
function M.find_project_notes()
  local dir = M.ensure_project_dir()
  Snacks.picker.files({ cwd = dir })
end

--- Search across all project notes.
function M.search_project_notes()
  local dir = M.ensure_project_dir()
  Snacks.picker.grep({ cwd = dir })
end

--- Open the project notes directory index or create one.
function M.project_index()
  local dir = M.ensure_project_dir()
  local index = dir .. "/index.md"

  if vim.fn.filereadable(index) == 0 then
    local project = M.project_name()
    local lines = {
      "---",
      "title: " .. project .. " Project Notes",
      "project: " .. project,
      "created: " .. os.date("%Y-%m-%d"),
      "tags:",
      "  - project-index",
      "---",
      "",
      "# " .. project,
      "",
      "## Notes",
      "",
      "",
    }
    vim.fn.writefile(lines, index)
  end

  M.open_float(index)
end

--- Browse all project directories under 1_Projects.
function M.browse_projects()
  Snacks.picker.files({ cwd = projects_path })
end

--- Search across the entire vault.
function M.search_vault()
  Snacks.picker.grep({ cwd = vault_path })
end

--- Quick-switch note from the full vault, opening in float.
function M.quick_switch()
  Snacks.picker.files({ cwd = vault_path })
end

return M
