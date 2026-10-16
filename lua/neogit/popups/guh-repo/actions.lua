local M = {}
local config = require("neogit.config")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local GuhBuffer = require("neogit.buffers.guh-repo")

local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

---@param popup PopupData
function M.print_popup(popup)
  vim.notify(vim.inspect(popup))
end

---@param popup PopupData
function M.open_guh(popup)
  GuhBuffer.new():open()
end

return M
