local notes = require("productivity.notes")

-- Allow obsidian vault path to be configured via environment variable (for testing)
local vault_path_env = vim.uv.os_getenv("LOCI_OBSIDIAN_VAULT")
local vault_path_config = vault_path_env or "~/Documents/Notes"

require("obsidian").setup({
  workspaces = {
    {
      name = "notes",
      path = vault_path_config,
    },
  },
  picker = {
    name = "snacks.pick",
  },
  completion = {
    nvim_cmp = false,
    blink = true,
  },
  legacy_commands = false,
  ui = { enable = false },

  daily_notes = {
    folder = "1_Projects/" .. notes.project_name() .. "/daily",
  },

  -- Route new notes into the current project's directory under 1_Projects/
  new_notes_location = "notes_subdir",
  note_path_func = function(spec)
    local project = notes.project_name()
    local title = tostring(spec.title or spec.id)
    local slug = title:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower()
    local path = spec.dir / "1_Projects" / project / (slug .. ".md")
    return path
  end,

  -- Simpler IDs based on title
  note_id_func = function(title)
    if title then
      return title:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower()
    end
    return tostring(os.time())
  end,

  -- Open obsidian notes in a floating window
  follow_url_func = nil,
  open_notes_in = "vsplit",
})

-- ── Vault localleader ────────────────────────────────────────────────────────
-- Applied to any .md file inside the configured vault

local vault_path = vim.fn.expand(vault_path_config)
local tasknotes_path = notes.project_tasks_dir()

local function apply_obsidian_keys(buf)
  local wk = require("which-key")
  wk.add({
    { "<localleader>",  group = "Obsidian",                                                  buffer = buf },
    { "<localleader>o", "<cmd>Obsidian quick-switch<cr>",                                    desc = "Quick switch note", buffer = buf },
    { "<localleader>n", "<cmd>Obsidian new<cr>",                                             desc = "New note",          buffer = buf },
    { "<localleader>s", "<cmd>Obsidian search<cr>",                                          desc = "Search notes",      buffer = buf },
    { "<localleader>b", "<cmd>Obsidian backlinks<cr>",                                       desc = "Backlinks",         buffer = buf },
    { "<localleader>t", "<cmd>Obsidian tags<cr>",                                            desc = "Tags",              buffer = buf },
    { "<localleader>l", "<cmd>Obsidian follow-link<cr>",                                     desc = "Follow/create link", buffer = buf },
    { "<localleader>T", "<cmd>Obsidian toc<cr>",                                             desc = "Table of contents", buffer = buf },
    { "<localleader>D", "<cmd>Obsidian today<cr>",                                           desc = "Today's daily note", buffer = buf },
    { "<localleader>m", "<cmd>Obsidian template<cr>",                                        desc = "Insert template",   buffer = buf },
    { "<localleader>R", "<cmd>Obsidian rename<cr>",                                          desc = "Rename note",       buffer = buf },
    { "<localleader>c", "<cmd>Obsidian toggle-checkbox<cr>",                                 desc = "Toggle checkbox",   buffer = buf },
  })
end

local function apply_tasknotes_keys(buf)
  local wk = require("which-key")
  wk.add({
    { "<localleader>",  group = "Tasks",                                buffer = buf },
    { "<localleader>B", "<cmd>TaskNotesBrowse<cr>",                     desc = "Browse tasks",   buffer = buf },
    { "<localleader>N", "<cmd>TaskNotesNew<cr>",                        desc = "New task note",  buffer = buf },
    { "<localleader>e", "<cmd>TaskNotesEdit<cr>",                       desc = "Edit task",      buffer = buf },
    { "<localleader>x", "<cmd>TaskNotesTimerToggle<cr>",                desc = "Timer toggle",   buffer = buf },
    { "<localleader>v", "<cmd>TaskNotesListViews<cr>",                  desc = "List views",     buffer = buf },
  })
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("ObsidianLocalleader", { clear = true }),
  pattern = vault_path .. "/**/*.md",
  callback = function(event)
    local buf = event.buf
    local bufpath = vim.api.nvim_buf_get_name(buf)
    apply_obsidian_keys(buf)
    if bufpath:sub(1, #tasknotes_path) == tasknotes_path then
      apply_tasknotes_keys(buf)
    end
  end,
})
