local ok, tiny = pcall(require, "tiny-cmdline")
if not ok then
  return
end

tiny.setup({
  width = { value = "70%", min = 50, max = 100 },
  position = { x = "50%", y = "66%" },
  border = nil,
  menu_col_offset = 3,
  native_types = { "/", "?" },
  on_reposition = tiny.adapters.blink,
})
