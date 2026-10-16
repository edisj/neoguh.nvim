local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local common_ui = require("neogit.buffers.common")
local shared = require("neoguh.ui")

local EmptyLine = common_ui.EmptyLine
local Component = Ui.Component
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

local state_hl = {
  OPEN = "OkMsg",
  MERGED = "ErrorMsg",
  CLOSED = "DiagnosticHint",
}

local M = {}

local function issue_status(data)
  if data.state == "CLOSED" then
    if data.stateReason == "NOT_PLANNED" then
      return "Closed (not planned)", "Comment"
    end
    return "Closed", "NeogitGraphPurple"
  end
  return "Open", "DiagnosticOk"
end

function M.header(data)
  data = data or {}

  local title = (data.url or ""):gsub("^https?://github%.com/", "")
  local status, status_hl = issue_status(data)

  local labels = table.concat(
    map(vim.tbl_get(data, "labels", "nodes") or {},
        function(label) return label.name end), ", ")

  local assignees = table.concat(
    map(vim.tbl_get(data, "assignees", "nodes") or {},
        function(user) return user.login end), ", ")

  local header_content = {
    { label = "Author", value = (data.author or {}).login or "?", hl = "NeogitGraphAuthor" },
    { label = "Status", value = status, hl = status_hl },
    { label = "Assignees", value = assignees ~= "" and assignees or "none" },
    { label = "Updated", value = (data.updatedAt or data.createdAt or ""):sub(1, 10) },
    { label = "Labels", value = labels ~= "" and labels or "none" },
  }

  local pad = 12
  local row_fn = function(item)
    return row {
      text.highlight("NeogitStatusHEAD")(util.str_min_width(item.label .. ":", pad)),
      text.highlight(item.hl or "Normal")(item.value),
    }
  end

  return col(util.merge(
    map(header_content, row_fn),
    { shared.centered(text.highlight("Bold")(" " .. title)) },
    -- { shared.centered(text.highlight("Bold")(shared.GH_ICONS.issue_open .. " " .. title)) },
    { row { text.highlight("LineNr")(("▔"):rep(vim.o.columns)) } }
  ))
end

function M.description(data)
  local row_fn = function(line) return row { text(line) } end
  local body = col(map(shared.body_lines(data.body), row_fn))
  local header = row {
    text.highlight("Bold")(data.title),
    text.highlight("Comment")(" #" .. data.number),
  }
  local title = text.highlight("NeogitSectionHeader")("# Description")
  return shared.build_collapsible_section(title, shared.boxed(body, header))
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
  local nodes = vim.tbl_get(data, "comments", "nodes")
  local header = row {
    text.highlight("NeogitSectionHeader")(("# Discussion (%s) "):format(#nodes)),
  }
  return shared.build_collapsible_section(header, nodes, build_comment)
end

function M.components(data)
  return data and {
    M.header(data),
    M.description(data),
    M.comments(data),
  } or { row { text.highlight("Comment")("Loading…") } }
end

return M
