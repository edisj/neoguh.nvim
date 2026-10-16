local api = vim.api
local fn = vim.fn

local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local ui = require("neogit.buffers.guh-issue.ui")
local shared = require("neoguh.ui")

local QUERY = [[
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    issue(number:$number){
      number title state body url createdAt
      author{ login }
      labels(first:20){ nodes{ name color } }
      assignees(first:10){ nodes{ login } }
      comments(first:100){ nodes{ author{ login } authorAssociation body createdAt url } }
    }
  }
}
]]

local function key(repo, id)
  return ("%s#%s"):format(repo, id)
end

local M = { instances = {} }

function M.new(repo, id)
  local instance = { feat = "issue", buffer = nil, repo = repo, id = id }
  setmetatable(instance, { __index = M })
  return instance
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

function M:create()
  self.buffer = Buffer.create {
    name = ("NeogitGuhIssue:%s/issue#%s"):format(self.repo, self.id),
    filetype = "markdown",
    buftype = "nowrite",
    bufhidden = "hide",
    ---@diagnostic disable-next-line: undefined-field
    -- kind = (config.values.guh or {}).kind or "tab",
    kind = "auto",
    foldmarkers = false,
    mappings = {
      n = shared.get_buffer_n_mappings(self),
    },
    render = function() return ui.components(self:get_data()) end,
    after = shared.get_box_drawing_decorator("NeogitGuhIssue", "single"),
  }
end

function M:load()
  self:fetch_data_and_render("issue_data", QUERY)
end

function M:fetch_data_and_render(b_key, query)
  local fetch = require("neoguh.guh").get_fetcher(self, b_key, query, function(resp)
    return vim.tbl_get(resp, "data", "repository", "issue")
  end)

  local on_result = function(guh_buf, data, err)
    if not data then
      return require("guh.util").msg(err or "failed to fetch issue", vim.log.levels.ERROR)
    end
    self.guh_buf = guh_buf
    self:render()
  end

  fetch(self.repo, on_result)
end

function M:get_data()
  local buf = require("guh.state").get_buf(self.feat, self.repo, self.id, false)
  return buf
    and vim.api.nvim_buf_is_valid(buf)
    and require("guh.state").get_b_key(buf, { "guh", "issue_data" })
    or nil
end

function M:render()
  if self.buffer and self.buffer:is_valid() then
    self.buffer.ui:render(unpack(ui.components(self:get_data())))
  end
end

function M:is_open()
  return (self.buffer and self.buffer:is_visible()) == true
end

return M
