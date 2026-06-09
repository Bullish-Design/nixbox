local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

T["LociDoctor command is registered"] = function()
  require("loci").setup({ refresh = { on_setup = false } })
  expect.equality(vim.fn.exists(":LociDoctor"), 2)
end

return T
