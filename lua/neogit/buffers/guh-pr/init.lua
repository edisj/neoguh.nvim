local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.guh-pr.ui")
local config = require("neogit.config")
local shared = require("neoguh.ui")

local PR_EXTRA_QUERY = [[
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      updatedAt
      mergeable
      labels(first:20){ nodes{ name color } }
      reactionGroups{ content users{ totalCount } }
      comments(first:100){
        nodes{
          author{ login } authorAssociation body createdAt url
          reactionGroups{ content users{ totalCount } }
        }
      }
    }
  }
}
]]

local M = { instances = {} }

local function key(repo, id)
  return ("%s#%s"):format(repo, id)
end

function M.new(repo, id)
  local instance = {
    repo = repo,
    id = id,
    feat = "pr",
    buffer = nil,
  }
  setmetatable(instance, { __index = M })
  return instance
end

function M:create()
  local status_maps = config.get_reversed_status_maps()
  self.buffer = Buffer.create {
    name = ("NeogitGuhPR:%s/pr#%s"):format(self.repo, self.id),
    filetype = "markdown",
    buftype = "nowrite",
    bufhidden = "hide",
    ---@diagnostic disable-next-line: undefined-field
    -- kind = (config.values.guh or {}).kind or "auto",
    kind = "auto",
    foldmarkers = false,
    mappings = {
      n = {
        [status_maps["Close"]] = function(b) b:close() end,
        [status_maps["Toggle"]] = function(b)
          local fold = b.ui:get_fold_under_cursor()
          if not fold then return end
          if fold.options.on_open then
            fold.options.on_open(fold, b.ui)
          else
            local start = fold:row_range_abs()
            if pcall(vim.cmd, "normal! za") then
              b:move_cursor(start)
              fold.options.folded = not fold.options.folded
            end
          end
        end,
        ["<CR>"] = function(b)
          local item = b.ui:get_item_under_cursor()
          if not item then return end
        end,
      },
    },
    after = shared.get_box_drawing_decorator("NeogitGuhPR", "single"),
    render = function() return ui.components(self:get_data()) end,
  }
end

function M:open()
  local existing = M.instances[key(self.repo, self.id)]
  if existing and existing:is_open() then
    self = existing
    self.buffer:focus()
  else
    M.instances[key(self.repo, self.id)] = self
    self:create()
    self:load()
  end
  return self
end

function M:load(force)
  self.guh_buf = require("guh.state").init_buf(self.feat, nil, self.repo, self.id)
  require("guh.gh").get_pr_data(self.id, self.repo, { force = force }, function(pr, err)
    if not pr then
      require("guh.util").msg(err or "failed to get pr data", vim.log.levels.ERROR)
      return
    end
    self:render(self:get_data())
  end)
  self:load_extra()
end

---Labels (with colors), conversation comments and reactions, which
---`gh.get_pr_data` does not select.
function M:load_extra()
 local fetch = require("neoguh.guh").get_fetcher(self, "pr_extra", PR_EXTRA_QUERY, function(resp)
    return vim.tbl_get(resp, "data", "repository", "pullRequest")
  end)

  fetch(self.repo, function(_, data, err)
    if not data then
      return require("guh.util").msg(err or "failed to get pr extras", vim.log.levels.ERROR)
    end
    self:render(self:get_data())
  end)
end

function M:get_data()
  local state = require("guh.state")
  local pr_data = state.get_pr_data(self.repo, self.id)
  if not pr_data then return end

  local buf = state.get_buf(self.feat, self.repo, self.id, false)
  local extra = buf and state.get_b_key(buf, { "guh", "pr_extra" }) or {}
  return vim.tbl_extend("force", pr_data, {
    updatedAt = extra.updatedAt,
    mergeable = extra.mergeable,
    reactionGroups = extra.reactionGroups,
    conversation = vim.tbl_get(extra, "comments") or {},
    labels = vim.tbl_get(extra, "labels") or pr_data.labels,
  })
end

function M:render(data)
  if self.buffer and self.buffer:is_valid() then
    self.buffer.ui:render(unpack(ui.components(data or self:get_data())))
  end
end

function M:is_open()
  return (self.buffer and self.buffer:is_visible()) == true
end

return M
