local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local common_ui = require("neogit.buffers.common")
local shared = require("neoguh.ui")

local EmptyLine = common_ui.EmptyLine
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

local state_hl = {
  OPEN = "NeogitBranch",
  MERGED = "NeogitGraphPurple",
  CLOSED = "NeogitGraphRed",
}
local function pr_status(data)
  if data.state == "MERGED" then return "Merged", "NeogitGraphPurple" end
  if data.state == "CLOSED" then return "Closed", "NeogitGraphRed" end
  if data.isDraft then return "Draft", "Comment" end
  return "Open", "DiagnosticOk"
end

local M = {}

function M.header(data)
  data = data or {}

  local title = (data.url or ""):gsub("^https?://github%.com/", "")
  local status, status_hl = pr_status(data)

  local labels = table.concat(
    map(data.labels or {}, function(label) return label.name end),
    ", "
  )

  local last_commit = (data.commits or {})[#(data.commits or {})]
  local updated = ((last_commit and last_commit.committedDate) or data.createdAt or ""):sub(1, 10)

  local header_content = {
    { label = "Author", value = (data.author or {}).login or "?", hl = "NeogitGraphAuthor" },
    { label = "Status", value = status, hl = status_hl },
    {
      label = "Branch",
      value = ("%s -> %s"):format(data.headRefName or "?", data.baseRefName or "?"),
      hl = "NeogitBranch",
    },
    { label = "Updated", value = updated },
    { label = "Labels", value = labels ~= "" and labels or "none" },
  }

  local pad = 10
  local row_fn = function(item)
    return row {
      text.highlight("NeogitStatusHEAD")(util.str_min_width(item.label .. ":", pad)),
      text.highlight(item.hl or "Normal")(item.value),
    }
  end

  return col(util.merge(
    map(header_content, row_fn),
    -- { row { text.highlight("Normal")("") } },
    { shared.centered(text.highlight("Bold")(" " .. title)) },
    { row { text.highlight("LineNr")(("▔"):rep(vim.o.columns)) } }))
end

function M.description(data)
  -- local body = vim.split(vim.trim((pr.body or ""):gsub("\r", "")), "\n", { plain = true })
  local row_fn = function(line) return row { text(line) } end
  local body = col(map(shared.body_lines(data.body), row_fn))
  local header = row {
    text.highlight("Bold")(data.title),
    text.highlight("Comment")(" #" .. data.number),
  }
  return shared.build_collapsible_section(text.highlight("NeogitSectionHeader")("# Description "), shared.boxed(body, header))
end

function M.commits(data)
  local row_fn = function(c)
      return row({
        text.highlight("NeogitObjectId")((c.oid or ""):sub(1, 12)),
        text("  "),
        text((c.committedDate or ""):sub(1, 10)),
        text("  "),
        text(c.messageHeadline or ""),
      }, { item = { kind = "commit", id = c.oid } })
  end
  local title = ("# Commits (%s) "):format(#(data.commits or {}))
  local header = text.highlight("NeogitSectionHeader")(title)
  return shared.build_collapsible_section(header, data.commits or {}, row_fn)
end

local function ci_summary(jobs)
  local pass, fail, pending = 0, 0, 0

  for _, job in ipairs(jobs or {}) do
    if not job.conclusion then
      pending = pending + 1
    elseif job.conclusion == "success" or job.conclusion == "neutral" or job.conclusion == "skipped" then
      pass = pass + 1
    else
      fail = fail + 1
    end
  end

  local total = pass + fail + pending
  if total == 0 then
    return nil
  end

  local icon, hl
  if fail > 0 then
    icon, hl = shared.GH_ICONS.x, "ErrorMsg"
  elseif pending > 0 then
    icon, hl = shared.GH_ICONS.dot or "●", "WarningMsg"
  else
    icon, hl = shared.GH_ICONS.check, "DiagnosticOk"
  end

  return ("%s %d/%d"):format(icon, pass, total), hl
end

local function build_comment(comment)
  local author = comment.author.login
  -- local body = vim.split(vim.trim((comment.body or ""):gsub("\r", "")), "\n", { plain = true })
  local created_at = comment.createdAt
  local association = comment.authorAssociation ~= "NONE" and comment.authorAssociation or ""

  local header =  row({
    text.highlight("Normal")(author),
    text("  "),
    text.highlight("Comment")((created_at or ""):sub(1, 10)),
    text("  "),
    text.highlight("Comment")(association),
  }, { context = true, item = { kind = "header" }, line_hl = "NormalSplit" })

  local content = col({}, { item = { kind = "comment", id = comment.url } })
  for _, line in ipairs(shared.body_lines(comment.body)) do
    content:append(text(line))
  end

  return shared.boxed(content, header)
end

function M.comments(data)
  local nodes = vim.tbl_get(data, "conversation", "nodes") or {}
  local header = row {
    text.highlight("NeogitSectionHeader")(("# Discussion (%s) "):format(#nodes)),
    -- text.highlight("Comment")(("%s %s "):format(#nodes, shared.GH_ICONS.comment)),
  }
  return shared.build_collapsible_section(header, nodes, build_comment)
end

function M.ci_jobs(data)
  local row_fn = function(job)
    return row({
      text(require("guh.gh").ci_icon(job)),
      text("  "),
      text(job.name or ""),
    }, { item = { kind = "job", id = job.databaseId } })
  end

  local jobs = data.ci_jobs or {}
  local summary, hl = ci_summary(jobs)
  local header = row {
    text.highlight("NeogitSectionHeader")("# CI "),
    text.highlight(hl or "Comment")(summary or "󰟢"),
    text(" "),
  }
  return shared.build_collapsible_section(header, jobs, row_fn, true)
end

function M.components(data)
  return data and {
    M.header(data),
    M.description(data),
    M.commits(data),
    M.comments(data),
    M.ci_jobs(data),
  } or { row { text.highlight("Comment")("Loading…") } }
end

return M
