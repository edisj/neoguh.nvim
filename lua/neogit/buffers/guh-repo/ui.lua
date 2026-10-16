local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local common_ui = require("neogit.buffers.common")
local shared = require("neoguh.ui")

local EmptyLine = common_ui.EmptyLine
local Diff = common_ui.Diff
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

local M = {}

function M.header(data)
  data = data or {}
  local repo = " " .. (data.nameWithOwner or "")
  local desc = data.description or "?"
  local branch  = vim.tbl_get(data, "defaultBranchRef", "name") or "?"
  local license = vim.tbl_get(data, "licenseInfo", "spdxId") or "?"

  local header_content = {
    { label = "Branch", value = branch, hl = "NeogitBranch" },
    { label = "License", value = license },
    { label = "Desc", value = desc },
  }
  local pad = 10
  local row_fn = function(item)
    return row {
      text.highlight("NeogitStatusHEAD")(util.str_min_width(item.label .. ":", pad)),
      text.highlight(item.hl or "Normal")(item.value),
    }
  end

  local header = row_fn { label = "Repo", value = repo, hl = "Bold" }
  return shared.build_collapsible_section(header, header_content, row_fn)
end

function M.issues(data)
  local nodes = vim.tbl_get(data or {}, "issues", "nodes") or {}
  local number_pad = util.max_length(map(nodes, function(n)
    return tostring(n.number)
  end)) + 1

  local row_fn = function(node)
    return row({
      text.highlight("LineNr")(util.str_min_width("#" .. node.number, number_pad)),
      text(" "),
      text.highlight("DiagnosticOk")(shared.GH_ICONS.issue_open),
      text(" "),
      text(node.title),
      text(" "),
      text.highlight("Comment")(node.comments.totalCount .. " " .. shared.GH_ICONS.comment)
    }, {
      virtual_text = {
        { " ", "Constant" },
        { util.str_clamp((node.author or {}).login or "", 20), "NeogitGraphAuthor" },
        -- { util.str_min_width(date, 10), "Special" },
      },
      item  = { kind = "issue", id = node.number }
    })
  end

  local title = ("Open issues (last-updated) %s"):format(#nodes)
  local header = text.highlight("NeogitSectionHeader")(title)
  return shared.build_collapsible_section(header, nodes, row_fn)
end

local function pr_icon(node)
  if node.state == "MERGED" then return shared.GH_ICONS.pr_merged, "NeogitGraphPurple" end
  if node.state == "CLOSED" then return shared.GH_ICONS.pr_closed, "ErrorMsg" end
  if node.isDraft then return shared.GH_ICONS.pr_draft, "NeogitTagName" end
  return shared.GH_ICONS.pr_open, "DiagnosticOk"
end

function M.prs(data)
  local nodes = vim.tbl_get(data or {}, "pullRequests", "nodes") or {}
  local number_pad = util.max_length(map(nodes, function(n)
    return tostring(n.number)
  end)) + 1

  local row_fn = function(node)
    local icon, hl = pr_icon(node)

    return row({
      text.highlight("LineNr")(util.str_min_width("#" .. node.number, number_pad)),
      text(" "),
      text.highlight(hl)(icon),
      text(" "),
      text(node.title),
      text(" "),
      text.highlight("Comment")(node.comments.totalCount .. " " .. shared.GH_ICONS.comment)
    }, {
      virtual_text = {
        { " ", "Constant" },
        { util.str_clamp((node.author or {}).login or "", 20), "NeogitGraphAuthor" },
        -- { util.str_min_width(date, 10), "Special" },
      },
      item = { kind = "pr", id = node.number },
    })
  end

  local title = ("Open PRs (last-updated) %s"):format(#nodes)
  local header = text.highlight("NeogitSectionHeader")(title)
  return shared.build_collapsible_section(header, nodes, row_fn)
end

function M.recent_commits(data)
  local nodes = vim.tbl_get(data or {}, "defaultBranchRef", "target", "history", "nodes") or {}
  local row_fn = function(node)
    local id = node.oid:sub(1, 12)
    return row({
      text.highlight("NeogitObjectId")(id),
      text("  "),
      text(node.messageHeadline),
    }, { item = { kind = "commit", id = id } })
  end

  local title = "Recent commits"
  local header = text.highlight("NeogitSectionHeader")(title)
  return shared.build_collapsible_section(header, nodes, row_fn)
end

function M.branches(data)
  local nodes = vim.tbl_get(data or {}, "refs", "nodes") or {}
  local slug = (data or {}).nameWithOwner or ""

  local row_fn = function(node)
    return row({
      text(("%s/tree/%s"):format(slug, node.name)),
    }, { item = { kind = "branch", id = node.name } })
  end

  local title = ("Branches (last-updated): https://github.com/%s/branches %s"):format(slug, #nodes)
  local header = text.highlight("NeogitSectionHeader")(title)
  return shared.build_collapsible_section(header, nodes, row_fn, true)
end

function M.components(data)
  return data and {
    M.header(data),
    M.issues(data),
    M.prs(data),
    M.recent_commits(data),
    M.branches(data)
  } or { row { text.highlight("Comment")("Loading…") } }
end

return M
