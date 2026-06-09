local notes = require("productivity.notes")

require("haunt").setup({
  -- Store annotations alongside obsidian project notes
  data_dir = notes.project_notes_dir() .. "/.haunt/",
  per_branch_bookmarks = true,
  picker = "snacks",
})

local function loci_workspace_active()
  return type(vim.t.loci_workspace_id) == "string" and vim.t.loci_workspace_id ~= ""
end

-- Update haunt data_dir when project root changes
vim.api.nvim_create_autocmd("DirChanged", {
  group = vim.api.nvim_create_augroup("HauntProjectDir", { clear = true }),
  callback = function()
    if loci_workspace_active() then
      return
    end

    local ok, haunt_api = pcall(require, "haunt.api")
    if not ok or type(haunt_api.change_data_dir) ~= "function" then
      return
    end

    local dir = notes.project_notes_dir() .. "/.haunt/"
    local changed_ok, err = pcall(haunt_api.change_data_dir, dir)
    if not changed_ok then
      vim.schedule(function()
        vim.notify("Haunt project data-dir update failed: " .. tostring(err), vim.log.levels.WARN)
      end)
    end
  end,
})
