local result = require("loci.result")
local notes = require("loci.service.notes")
local forms = require("loci.ui.forms")
local util = require("loci.ui.commands.util")

local M = {}

---@async
function M.register()
  vim.api.nvim_create_user_command("LociNoteCreate", function(args)
    local title = args.args ~= "" and args.args or nil

    if title then
      util.run_async(function()
        return notes.create({ title = title })
      end, function(r)
        if result.is_ok(r) then
          vim.cmd.edit(vim.fn.fnameescape(r.value.abs_path))
          util.notify_result("LOCI: Note created: " .. title, result.ok())
        else
          util.notify_result("LOCI: Note creation failed", r)
        end
      end)
      return
    end

    forms.note_new({}, function(form_result)
      if not result.is_ok(form_result) then
        util.notify_result("LOCI: Note cancelled", form_result)
        return
      end

      util.run_async(function()
        return notes.create(form_result.value)
      end, function(r)
        if result.is_ok(r) then
          vim.cmd.edit(vim.fn.fnameescape(r.value.abs_path))
          util.notify_result("LOCI: Note created: " .. form_result.value.title, result.ok())
        else
          util.notify_result("LOCI: Note creation failed", r)
        end
      end)
    end)
  end, {
    desc = "Create a new note",
    nargs = "?",
    force = true,
  })

  vim.api.nvim_create_user_command("LociDailyNote", function(args)
    local date = args.args ~= "" and args.args or os.date("%Y-%m-%d")

    util.run_async(function()
      return notes.daily({ date_string = date })
    end, function(r)
      if result.is_ok(r) then
        vim.cmd.edit(vim.fn.fnameescape(r.value.abs_path))
        util.notify_result("LOCI: Daily note for " .. date, result.ok())
      else
        util.notify_result("LOCI: Daily note failed", r)
      end
    end)
  end, {
    desc = "Create or open daily note",
    nargs = "?",
    force = true,
  })

  vim.api.nvim_create_user_command("LociScratchNote", function(args)
    local title = args.args ~= "" and args.args or ""
    local ws_id = vim.t.loci_workspace_id

    util.run_async(function()
      return notes.scratch({ title = title, workspace_id = ws_id })
    end, function(r)
      if result.is_ok(r) then
        vim.cmd.edit(vim.fn.fnameescape(r.value.abs_path))
        if r.value.workspace_association_error then
          util.notify_result("LOCI: Note created but workspace association failed: " .. r.value.workspace_association_error, result.err("workspace association failed", "conflict"))
        else
          util.notify_result("LOCI: Scratch note created", result.ok())
        end
      else
        util.notify_result("LOCI: Scratch note creation failed", r)
      end
    end)
  end, {
    desc = "Create a scratch note",
    nargs = "?",
    force = true,
  })

  vim.api.nvim_create_user_command("LociNoteAdopt", function()
    local current_file = vim.api.nvim_buf_get_name(0)

    util.run_async(function()
      return notes.ensure_id(current_file)
    end, function(r)
      if result.is_ok(r) then
        util.notify_result("LOCI: ID ensured: " .. r.value.loci_id, result.ok())
      else
        util.notify_result("LOCI: Ensure ID failed", r)
      end
    end)
  end, {
    desc = "Ensure current Markdown file has a loci_id",
    force = true,
  })
end

return M
