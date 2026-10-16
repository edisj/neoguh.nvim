vim.api.nvim_create_user_command("Neoguh", function(args)
  local view = require("neogit.buffers.guh-repo")
  local arg = vim.trim(args.args)
  if arg == "" then return view.new():open() end

  local target = require("guh.util").parse_target(arg)
  if not target or not target.owner then
    return vim.notify(("Neoguh: expected a repo, got %q"):format(arg), vim.log.levels.ERROR)
  end
  view.new(("%s/%s"):format(target.owner, target.repo)):open()
end, { nargs = "?", desc = "Open NeogitGuhView" })
