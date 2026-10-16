--- guh helpers

local M = {}

function M.get_fetcher(buffer, b_key, query, resp_to_data)
  return function(repo, on_result)
    local state = require("guh.state")

    local guh_buf = state.init_buf(buffer.feat, nil, repo, buffer.id)

    local cached = state.get_b_key(guh_buf, { "guh", b_key })
    if cached then
      return on_result(guh_buf, cached)
    end

    local owner, name = repo:match("^([^/]+)/(.+)$")
    if not owner then
      local errmsg = "invalid repo: " .. repo
      return on_result(guh_buf, nil, errmsg)
    end

    local cmd = {
      "gh",
      "api",
      "graphql",
      "-f",
      "owner=" .. owner,
      "-f",
      "name=" .. name,
      "-f",
      "query=" .. (query:gsub("%%s", repo))
    }
    -- NOTE:
    if tonumber(buffer.id) then
      vim.list_extend(cmd, { "-F", "number=" .. buffer.id })
    end

    require("guh.util").system(cmd, nil, function(r)
      local ok, resp = pcall(vim.json.decode, r.stdout or "")

      if r.code ~= 0 or not ok then
        return on_result(guh_buf, nil, r.stderr or "failed to decode gh response")
      end

      if resp.errors then
        local errors = vim.inspect(resp.errors)
        return on_result(guh_buf, nil, errors)
      end

      local data = resp_to_data(resp)
      if data and vim.api.nvim_buf_is_valid(guh_buf) then
        require("guh.state").set_b_key(guh_buf, { "guh", b_key }, data)
        on_result(guh_buf, data)
      else
        on_result(guh_buf, nil, "no data in response")
      end
    end)
  end
end

return M
