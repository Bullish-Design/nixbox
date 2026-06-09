local create = require("loci.service.repository.create")
local verify = require("loci.service.repository.verify")
local repair = require("loci.service.repository.repair")

local M = {}

M.init_new = create.init_new
M.ensure = create.ensure
M.verify_existing = verify.verify_existing
M.repair = repair.repair

M.init = M.ensure

return M
