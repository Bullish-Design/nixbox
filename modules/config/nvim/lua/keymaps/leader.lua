-- Single declarative spec for ALL <leader>* mappings.
-- This file is the keymap reference — it reads like the which-key popup.
local wk = require("which-key")

wk.add({

  -- ── Find ─────────────────────────────────────────────────────────────
  { "<leader>f",       group = "Find" },
  { "<leader>ff",      function() Snacks.picker.files() end,        desc = "Files" },
  { "<leader><space>", function() Snacks.picker.files() end,        desc = "Files" },
  { "<leader>fg",      function() Snacks.picker.grep() end,         desc = "Grep" },
  { "<leader>/",       function() Snacks.picker.grep() end,         desc = "Grep" },
  { "<leader>fb",      function() Snacks.picker.buffers() end,      desc = "Buffers" },
  { "<leader>fh",      function() Snacks.picker.help() end,         desc = "Help" },
  { "<leader>fr",      function() Snacks.picker.recent() end,       desc = "Recent" },
  { "<leader>fk",      function() Snacks.picker.keymaps() end,      desc = "Keymaps" },
  { "<leader>fd",      function() Snacks.picker.diagnostics() end,  desc = "Diagnostics" },
  { "<leader>fc",      function() Snacks.picker.commands() end,     desc = "Commands" },
  { "<leader>fs",      function() Snacks.picker.lsp_symbols() end,           desc = "LSP symbols (document)" },
  { "<leader>fS",      function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP symbols (workspace)" },
  { "<leader>fG",      function() Snacks.picker.git_status() end,   desc = "Git status" },
  { "<leader>fw",      function() require("wayfinder").open() end,  desc = "Wayfinder" },
  { "<leader>fz",      function() require("zeal").search() end,     desc = "Zeal docs" },
  { "<leader>ft",      "<cmd>TodoQuickFix keywords=TODO,FIX,FIXME,NOTE,PERF,HACK,WARN,TEST<cr>", desc = "Todos" },

  -- ── FFF (fast fuzzy find) ──────────────────────────────────────────
  { "<leader>F",       group = "FFF" },
  { "<leader>Ff",      function() require("fff").find_files() end,     desc = "Files" },
  { "<leader>Fg",      function() require("fff").live_grep() end,      desc = "Grep" },
  { "<leader>Fz",      function() require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } }) end, desc = "Fuzzy grep" },
  { "<leader>Fc",      function() require("fff").live_grep({ query = vim.fn.expand("<cword>") }) end, desc = "Current word" },

  -- ── Git ──────────────────────────────────────────────────────────────
  { "<leader>g",  group = "Git" },
  { "<leader>gg", function() require("neogit").open() end,  desc = "Neogit" },
  { "<leader>gD", "<cmd>DiffviewOpen<cr>",                  desc = "Diffview" },
  { "<leader>gq", "<cmd>DiffviewClose<cr>",                 desc = "Close diffview" },
  { "<leader>gb", function() MiniGit.show_at_cursor() end,  desc = "Blame/show" },
  { "<leader>gn", function() MiniDiff.goto_hunk("next") end, desc = "Next hunk" },
  { "<leader>gp", function() MiniDiff.goto_hunk("prev") end, desc = "Prev hunk" },
  { "<leader>gr", function() MiniDiff.do_hunks(0, "reset") end, desc = "Reset hunks" },

  -- ── Workspace ────────────────────────────────────────────────────────
  { "<leader>w",  group = "Workspace" },
  { "<leader>w-", "<C-w>s", desc = "Split below" },
  { "<leader>w|", "<C-w>v", desc = "Split right" },

  -- Tab subgroup
  { "<leader>wt",  group = "Tab" },
  { "<leader>wtn", function()
      vim.cmd("tabnew")
      vim.api.nvim_feedkeys(":Tabby rename_tab ", "n", false)
    end,                                                                               desc = "New" },
  { "<leader>wtj", "<cmd>Tabby jump_to_tab<cr>",                                     desc = "Jump to" },
  { "<leader>wtr", ":Tabby rename_tab ",                                              desc = "Rename" },
  { "<leader>wtc", "<cmd>tabclose<cr>",                                               desc = "Close" },
  { "<leader>wto", "<cmd>tabonly<cr>",                                                desc = "Only this" },
  { "<leader>wtT", function() require("workspace.submodes").tab_nav() end,            desc = "Nav submode" },
  { "<leader>wtm", function() require("workspace.submodes").tab_move() end,           desc = "Move submode" },
  { "<leader>wtp", "<cmd>Tabby pick_window<cr>",                                      desc = "Pick window" },
  { "<leader>wtd", "<C-w>c",                                                          desc = "Close window" },
  { "<leader>wtz", function() Snacks.zoom() end,                                      desc = "Zoom" },
  { "<leader>wte", "<C-w>=",                                                          desc = "Equalize" },

  -- Buffer subgroup
  { "<leader>wb",  group = "Buffer" },
  { "<leader>wbb", function() require("bento.api").toggle_menu() end,                 desc = "Bento menu" },
  { "<leader>wbl", function() require("bento.api").open_menu() end,                   desc = "Open menu (expanded)" },
  { "<leader>wbL", function() require("bento.api").toggle_lock() end,                 desc = "Lock buffer" },
  { "<leader>wbD", function() require("bento.api").close_all_buffers({ visible = false, locked = false }) end, desc = "Close hidden" },
  { "<leader>wbd", function() Snacks.bufdelete() end,                                 desc = "Delete" },

  -- Sidequest subgroup
  { "<leader>ws",  group = "Sidequest" },
  { "<leader>wst", function() require("sidequest").toggle({ focus = true }) end,                desc = "Toggle" },
  { "<leader>wsf", function() require("sidequest").focus() end,                                 desc = "Focus" },
  { "<leader>wsh", function() require("sidequest").home() end,                                  desc = "Home" },
  { "<leader>wsg", function() require("sidequest").open_tree("git", { focus = true }) end,      desc = "Git" },
  { "<leader>wss", function() require("sidequest").open_tree("sessions", { focus = true }) end, desc = "Sessions" },

  -- ── Quit / Session ───────────────────────────────────────────────────
  { "<leader>q",  group = "Quit/Session" },
  { "<leader>qq", "<cmd>quitall<cr>",                          desc = "Quit all" },
  { "<leader>qs", function() require("resession").load() end,   desc = "Restore session" },
  { "<leader>qS", function() require("resession").save() end,   desc = "Save session" },
  { "<leader>qd", function() require("resession").delete() end, desc = "Delete session" },
  { "<leader>qD", function() require("resession").detach() end, desc = "Detach session" },
  { "<leader>qw", function() require("workspace.sessions").load_workspace() end,   desc = "Restore workspace" },
  { "<leader>qW", function() require("workspace.sessions").save_workspace() end,   desc = "Save workspace" },
  { "<leader>qx", function() require("workspace.sessions").delete_workspace() end, desc = "Delete workspace" },

  -- ── Search / Replace ─────────────────────────────────────────────────
  { "<leader>s",  group = "Search/Replace" },
  { "<leader>sr", function() require("grug-far").open() end, desc = "Grug-far" },

  -- ── Diagnostics ──────────────────────────────────────────────────────
  { "<leader>x",  group = "Diagnostics" },
  { "<leader>xd", vim.diagnostic.setloclist, desc = "Buffer list" },
  { "<leader>xq", vim.diagnostic.setqflist,  desc = "Workspace quickfix" },
  { "<leader>xn", function() vim.diagnostic.jump({ count = 1 }) end,  desc = "Next" },
  { "<leader>xp", function() vim.diagnostic.jump({ count = -1 }) end, desc = "Previous" },
  { "<leader>xw", function() require("wtf").ai() end,  desc = "WTF: explain diagnostic" },
  { "<leader>xs", function() require("wtf").search() end, desc = "WTF: search diagnostic" },

  -- ── Notes ───────────────────────────────────────────────────────────
  { "<leader>n",  group = "Notes" },

  -- Project notes (obsidian-backed, floating window)
  { "<leader>nn", function() require("productivity.notes").new_project_note() end,   desc = "New project note" },
  { "<leader>ni", function() require("productivity.notes").project_index() end,      desc = "Project index" },
  { "<leader>nf", function() require("productivity.notes").find_project_notes() end, desc = "Find project notes" },
  { "<leader>ng", function() require("productivity.notes").search_project_notes() end, desc = "Grep project notes" },
  { "<leader>np", function() require("productivity.notes").browse_projects() end,    desc = "Browse all projects" },

  -- Vault-wide (obsidian)
  { "<leader>no", "<cmd>Obsidian quick-switch<cr>",  desc = "Quick switch (vault)" },
  { "<leader>ns", "<cmd>Obsidian search<cr>",        desc = "Search vault" },
  { "<leader>nd", "<cmd>Obsidian today<cr>",         desc = "Daily note" },

  -- Tasks
  { "<leader>nt", "<cmd>TaskNotesBrowse<cr>",        desc = "Browse tasks" },
  { "<leader>nT", "<cmd>TaskNotesNew<cr>",           desc = "New task" },

  -- Annotations (haunt.nvim — stored in project notes dir)
  { "<leader>na", function() require("haunt.api").annotate() end,    desc = "Add/edit annotation" },
  { "<leader>nl", function() require("haunt.picker").show() end,     desc = "List annotations" },
  { "<leader>n]", function() require("haunt.api").next() end,        desc = "Next annotation" },
  { "<leader>n[", function() require("haunt.api").prev() end,        desc = "Prev annotation" },

  -- ── UI toggles ───────────────────────────────────────────────────────
  { "<leader>u",  group = "UI toggle" },
  { "<leader>up", function() require("precognition").toggle() end,                          desc = "Precognition" },
  { "<leader>uh", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, desc = "Inlay hints" },

  -- ── Single-key actions ───────────────────────────────────────────────
  { "<leader>e", function() Snacks.explorer() end,                            desc = "Explorer" },
  { "<leader>;", function() require("sidequest").toggle({ focus = true }) end, desc = "Sidequest toggle" },
  { "<leader>.", function() Snacks.scratch() end,                              desc = "Scratch buffer" },
  { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },

  -- ── Terminal ─────────────────────────────────────────────────────────
  { "<A-i>", function() Snacks.terminal.toggle() end, desc = "Terminal toggle", mode = { "n", "t" } },

  { "<leader>l",  group = "Loci" },
  { "<leader>lI", "<cmd>LociInit<cr>", desc = "Init" },
  { "<leader>lH", "<cmd>LociHealth<cr>", desc = "Health" },
  { "<leader>lD", "<cmd>LociDoctor<cr>", desc = "Doctor" },
  { "<leader>lR", "<cmd>LociOpenRoot<cr>", desc = "Open root" },

  -- Projects
  { "<leader>lp", group = "Projects" },
  { "<leader>lpn", "<cmd>LociProjectCreate<cr>", desc = "New project" },
  { "<leader>lpo", "<cmd>LociProjectOpen<cr>", desc = "Open project" },
  { "<leader>lpp", "<cmd>LociProjectSwitch<cr>", desc = "Switch" },
  { "<leader>lpi", "<cmd>LociProjectInfo<cr>", desc = "Info" },
  { "<leader>lpr", "<cmd>LociProjectRefresh<cr>", desc = "Refresh" },
  { "<leader>lpL", "<cmd>LociProjectLink<cr>", desc = "Link current" },

  -- Workspaces
  { "<leader>lw", group = "Workspaces" },
  { "<leader>lwn", "<cmd>LociWorkspaceCreate<cr>", desc = "New" },
  { "<leader>lwo", "<cmd>LociWorkspaceSwitch<cr>", desc = "Switch" },
  { "<leader>lwc", "<cmd>LociWorkspaceClone<cr>", desc = "Clone" },
  { "<leader>lwi", "<cmd>LociWorkspaceInfo<cr>", desc = "Info" },
  { "<leader>lwa", "<cmd>LociWorkspaceArchive<cr>", desc = "Archive" },
  { "<leader>lwr", "<cmd>LociWorkspaceRefresh<cr>", desc = "Refresh" },
  { "<leader>lwR", "<cmd>LociRepositoryOpen<cr>", desc = "Repository" },
  -- Workspace knowledge management
  { "<leader>lwk", group = "Knowledge" },
  { "<leader>lwka", "<cmd>LociKnowledgeAdd<cr>", desc = "Add" },
  { "<leader>lwkr", "<cmd>LociKnowledgeRemove<cr>", desc = "Remove" },
  { "<leader>lwkp", "<cmd>LociKnowledgeSetPrimary<cr>", desc = "Set primary" },
  -- Workspace file linking
  { "<leader>lwf", group = "Linked files" },
  { "<leader>lwfL", "<cmd>LociFileLink<cr>", desc = "Link current" },
  { "<leader>lwfU", "<cmd>LociFileUnlink<cr>", desc = "Unlink current" },

  -- Notes
  { "<leader>ln", group = "Notes" },
  { "<leader>lnn", "<cmd>LociNoteCreate<cr>", desc = "New note" },
  { "<leader>lnd", "<cmd>LociDailyNote<cr>", desc = "Daily note" },
  { "<leader>lns", "<cmd>LociScratchNote<cr>", desc = "Scratch note" },
  { "<leader>lne", "<cmd>LociNoteAdopt<cr>", desc = "Adopt note" },

  -- Haunt (annotation) contexts
  { "<leader>lx", group = "Haunt" },
  { "<leader>lxL", "<cmd>LociHauntList<cr>", desc = "List" },
  { "<leader>lxn", "<cmd>LociHauntNew<cr>", desc = "New" },
  { "<leader>lxs", "<cmd>LociHauntSwitch<cr>", desc = "Switch" },
  { "<leader>lxr", "<cmd>LociHauntRename<cr>", desc = "Rename" },
  { "<leader>lxd", "<cmd>LociHauntDelete<cr>", desc = "Delete" },

  -- Trails (Wayfinder integration)
  { "<leader>lt", group = "Trails" },
  { "<leader>ltL", "<cmd>LociTrailList<cr>", desc = "List" },
  { "<leader>ltn", "<cmd>LociTrailCreate<cr>", desc = "New" },
  { "<leader>lts", "<cmd>LociTrailSwitch<cr>", desc = "Switch" },
  { "<leader>lty", "<cmd>LociTrailSave<cr>", desc = "Save" },
  { "<leader>ltl", "<cmd>LociTrailLoad<cr>", desc = "Load" },
  { "<leader>ltr", "<cmd>LociTrailResume<cr>", desc = "Resume" },
  { "<leader>ltR", "<cmd>LociTrailRename<cr>", desc = "Rename" },
  { "<leader>ltd", "<cmd>LociTrailDelete<cr>", desc = "Delete" },
  { "<leader>ltS", "<cmd>LociTrailShow<cr>", desc = "Show UI" },
  { "<leader>ltq", "<cmd>LociTrailExport<cr>", desc = "Export" },

  -- Refresh all
  { "<leader>lF", "<cmd>LociRefresh<cr>", desc = "Full refresh" },

})
