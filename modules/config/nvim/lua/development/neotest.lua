local has_nio = pcall(require, "nio")
if not has_nio then
  vim.schedule(function()
    vim.notify("neotest disabled: nvim-nio not available", vim.log.levels.WARN)
  end)
  return
end

require("neotest").setup({
  adapters = {
    require("neotest-python")({}),
  },
})
