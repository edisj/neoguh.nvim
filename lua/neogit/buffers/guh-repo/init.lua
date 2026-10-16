local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local ui = require("neogit.buffers.guh-repo.ui")
local shared = require("neoguh.ui")

local QUERY = [[
query($owner:String!,$name:String!){
  repository(owner:$owner,name:$name){
    nameWithOwner
    description
    pushedAt
    licenseInfo{ nickname name spdxId }
    defaultBranchRef{ name target{ ... on Commit{ history(first:10){ nodes{ oid messageHeadline } } } } }
    refs(refPrefix:"refs/heads/",first:4,orderBy:{field:TAG_COMMIT_DATE,direction:DESC}){nodes{name}}
    pullRequests(first:10,states:OPEN,orderBy:{field:UPDATED_AT,direction:DESC}){
      nodes{
        number title isDraft state reviewDecision mergeable
        author{ login } updatedAt
        comments{ totalCount }
        additions deletions
      }
    }
    issues(first:10,states:OPEN,orderBy:{field:UPDATED_AT,direction:DESC}){
      nodes{
        number title
        author{ login } updatedAt
        comments{ totalCount }
        labels(first:3){ nodes{ name color } }
      }
    }
  }
  mine: search(query:"repo:%s is:pr is:open author:@me",type:ISSUE,first:10){
    nodes{ ... on PullRequest{ number title } }
  }
  review: search(query:"repo:%s is:pr is:open review-requested:@me",type:ISSUE,first:10){
    nodes{ ... on PullRequest{ number title } }
  }
}
]]

local M = {}

function M.new(repo)
  local instance = {
    repo = repo,
    feat = "pr",
    id = "all",
    buffer = nil,
  }
  setmetatable(instance, { __index = M })
  return instance
end

function M:create()
  self.buffer = Buffer.create {
    name = "NeogitGuhView",
    filetype = "NeogitGuhView",
    bufhidden = "hide",
    ---@diagnostic disable-next-line: undefined-field
    kind = (config.values.guh or {}).kind or "tab",
    foldmarkers = true,
    mappings = {
      n = shared.get_buffer_n_mappings(self),
    },
    render = function() return ui.components(self:get_data()) end,
  }
end

function M:open()
  if M.is_open() then
    M.instance.buffer:focus()
  else
    M.instance = self
    self:create()
    self:load()
  end
  return self
end

function M:fetch_data_and_render(b_key, query)
  local fetch = require("neoguh.guh").get_fetcher(self, b_key, query, function(resp)
    local data = vim.tbl_get(resp, "data", "repository")
    return data
  end)

  local on_result = function(guh_buf, data, err)
    if not data then
      return require("guh.util").msg(err or "failed to fetch repo", vim.log.levels.ERROR)
    end
    self.guh_buf = guh_buf
    self:render()
  end

  fetch(self.repo, on_result)
end

function M:load()
  local on_done = function(repo)
    if not repo then return end
    self.repo = repo
    self:fetch_data_and_render("repo_data", QUERY)
  end
  if not self.repo then
    require("guh.gh").get_repo(nil, on_done)
  else
    on_done(self.repo)
  end
end

function M:render()
  if self.buffer and self.buffer:is_valid() then
    self.buffer.ui:render(unpack(ui.components(self:get_data())))
  end
end

function M:get_data()
  -- local buf = self.repo and state.get_buf(self.feat, self.repo, self.id, false)
  return self.guh_buf
    and vim.api.nvim_buf_is_valid(self.guh_buf)
    and require("guh.state").get_b_key(self.guh_buf, { "guh", "repo_data" })
    or nil
end

function M.is_open()
  return (M.instance and M.instance.buffer and M.instance.buffer:is_visible()) == true
end

return M
