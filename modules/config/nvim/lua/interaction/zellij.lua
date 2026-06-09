-- Only set up zellij navigation when running inside zellij
if vim.env.ZELLIJ == nil then
  return
end

require("zellij-nav").setup()
