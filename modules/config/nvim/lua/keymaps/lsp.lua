-- LSP keymaps: g* navigation (buffer-local) + <localleader> code actions.
-- Applied via LspAttach autocmd.
local wk = require("which-key")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
  callback = function(event)
    local buf = event.buf

    -- Groups for which-key labels
    wk.add({
      { "<localleader>", group = "LSP", buffer = buf },
    })

    -- LSP navigation (vim convention: "go to")
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf, desc = "LSP: definition" })
    vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = buf, desc = "LSP: references" })
    vim.keymap.set("n", "gI", vim.lsp.buf.implementation, { buffer = buf, desc = "LSP: implementation" })
    vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, { buffer = buf, desc = "LSP: type definition" })
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf, desc = "LSP: declaration" })
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = buf, desc = "LSP: hover" })
    vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, { buffer = buf, desc = "LSP: signature help" })

    -- <localleader> buffer-level code actions
    vim.keymap.set("n", "<localleader>r", vim.lsp.buf.rename, { buffer = buf, desc = "Rename symbol" })
    vim.keymap.set("n", "<localleader>a", function() require("tiny-code-action").code_action() end, { buffer = buf, desc = "Code action" })
    vim.keymap.set("n", "<localleader>f", function() vim.lsp.buf.format({ async = true }) end, { buffer = buf, desc = "Format buffer" })
    vim.keymap.set("n", "<localleader>d", vim.diagnostic.open_float, { buffer = buf, desc = "Line diagnostics" })
    vim.keymap.set("n", "<localleader>O", "<cmd>Outline<cr>", { buffer = buf, desc = "Symbol outline" })
    vim.keymap.set("n", "<localleader>p", function() require("overlook.api").peek_definition() end, { buffer = buf, desc = "Peek definition" })
    vim.keymap.set("n", "<localleader>P", function() require("overlook.api").close_all() end, { buffer = buf, desc = "Close peek" })
  end,
})
