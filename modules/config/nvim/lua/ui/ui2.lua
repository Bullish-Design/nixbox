if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("UI2 requires Neovim 0.12+", vim.log.levels.WARN)
  return
end

local ok, ui2 = pcall(require, "vim._core.ui2")
if not ok then
  vim.notify("UI2 module not available in this build", vim.log.levels.WARN)
  return
end

ui2.enable({
  enable = true,
  msg = {
    targets = {
      default = "cmd",
      [""] = "msg",
      empty = "cmd",
      bufwrite = "msg",
      undo = "msg",
      quickfix = "msg",
      search_cmd = "cmd",
      search_count = "cmd",
      completion = "cmd",
      wildlist = "cmd",
      typed_cmd = "cmd",
      emsg = "pager",
      echoerr = "pager",
      lua_error = "pager",
      rpc_error = "pager",
      shell_cmd = "pager",
      shell_err = "pager",
      shell_out = "pager",
      verbose = "pager",
      list_cmd = "pager",
      progress = "pager",
    },
    cmd = { height = 0.4 },
    msg = { height = 0.3, timeout = 5000 },
    pager = { height = 0.6 },
    dialog = { height = 0.5 },
  },
})
