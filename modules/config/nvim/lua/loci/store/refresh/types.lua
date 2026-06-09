---@class loci.RefreshDiagnostic
---@field code string
---@field message string
---@field severity 'info'|'warning'|'error'
---@field path string|nil
---@field id string|nil
---@field details table|nil

---@class loci.RefreshScanResult
---@field content_entries table[]
---@field projects table[]
---@field workspaces table[]
---@field repository table|nil
---@field current table|nil
---@field diagnostics loci.RefreshDiagnostic[]
---@field stats table

local M = {}

return M
