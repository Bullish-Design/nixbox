require("zeal").setup({
  picker = {
    type = "snacks",
    snacks = {
      layout = "select",
    },
  },
})

-- ── Terminal browser localleader ─────────────────────────────────────────────
-- Detects w3m terminal buffers (opened by zeal.nvim or standalone) and applies
-- buffer-local <localleader> keys. Zeal buffers get the w3m base keys plus
-- additional search keys.

local function is_w3m_buf(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return name:match("w3m") ~= nil
end

local function is_zeal_buf(buf)
  -- Zeal buffers are w3m buffers that were opened by zeal.nvim.
  -- Check the buffer variable set by zeal.nvim, fall back to name match.
  local ok, is_zeal = pcall(vim.api.nvim_buf_get_var, buf, "zeal_buf")
  if ok and is_zeal then return true end
  local name = vim.api.nvim_buf_get_name(buf)
  return name:match("zeal") ~= nil
end

local function apply_w3m_keys(buf)
  local wk = require("which-key")
  wk.add({
    { "<localleader>",  group = "w3m",                       buffer = buf },
    { "<localleader>b", function() vim.fn.feedkeys("B", "n") end, desc = "Back",       buffer = buf },
    { "<localleader>f", function() vim.fn.feedkeys("F", "n") end, desc = "Forward",    buffer = buf },
    { "<localleader>H", function() vim.fn.feedkeys("H", "n") end, desc = "Home",       buffer = buf },
    { "<localleader>r", function() vim.fn.feedkeys("R", "n") end, desc = "Reload",     buffer = buf },
    { "<localleader>q", function() vim.fn.feedkeys("q", "n") end, desc = "Close",      buffer = buf },
    { "<localleader>u", function() vim.fn.feedkeys("U", "n") end, desc = "Edit URL",   buffer = buf },
    { "<localleader>y", function() vim.fn.feedkeys("y", "n") end, desc = "Yank URL",   buffer = buf },
  })
end

local function apply_zeal_keys(buf)
  local wk = require("which-key")
  wk.add({
    { "<localleader>",  group = "Docs/Zeal",                               buffer = buf },
    { "<localleader>s", function() require("zeal").search() end,           desc = "New search",         buffer = buf },
    { "<localleader>S", function() require("zeal").search_by_ft() end,     desc = "Search by filetype", buffer = buf },
    { "<localleader>d", function() require("zeal").switch_docset() end,    desc = "Switch docset",      buffer = buf },
  })
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("W3mLocalleader", { clear = true }),
  callback = function(event)
    local buf = event.buf
    if not is_w3m_buf(buf) then return end
    apply_w3m_keys(buf)
    if is_zeal_buf(buf) then
      apply_zeal_keys(buf)
    end
  end,
})
