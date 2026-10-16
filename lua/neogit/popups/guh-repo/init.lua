local config = require("neogit.config")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.guh-repo.actions")

local M = {}

function M.create(env)
  local has_item = env.item ~= nil

  local p = popup
    .builder()
    :name("NeogitGuhPopup")
    :group_heading("Guh")
    :action("g", "guh", actions.open_guh)
    :new_action_group("Show")
    :action("p", "guh", actions.print_popup)
    :env(env)
    :build()

  p:show()

  return p
end

return M
