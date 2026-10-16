--- neogit helpers

local fn = vim.fn
local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local common_ui = require("neogit.buffers.common")

local EmptyLine = common_ui.EmptyLine
local Component = Ui.Component
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map
local config = require("neogit.config")

local BORDER_PAD = 4
local BORDER_CHARS = {
  single = {
    topleft = "┌",
    top = "─",
    topright = "┐",
    right = "│",
    botright = "┘",
    bot = "─",
    botleft = "└",
    left = "│",
    midleft = "├",
    midright = "┤",
  },
  rounded = {
    topleft = "╭",
    top = "─",
    topright = "╮",
    right = "│",
    botright = "╯",
    bot = "─",
    botleft = "╰",
    left = "│",
    midleft = "├",
    midright = "┤",
  },
  bold = {
    topleft = "┏",
    top = "━",
    topright = "┓",
    right = "┃",
    botright = "┛",
    bot = "━",
    botleft = "┗",
    left = "┃",
    midleft = "┣",
    midright = "┫",
  },
  double = {
    topleft = "╔",
    top = "═",
    topright = "╗",
    right = "║",
    botright = "╝",
    bot = "═",
    botleft = "╚",
    left = "║",
    midleft = "╠",
    midright = "╣",
  },
}
local M = {}

 M.REACTION_ICONS = {
  THUMBS_UP = "👍",
  THUMBS_DOWN = "👎",
  LAUGH = "😄",
  HOORAY = "🎉",
  CONFUSED = "😕",
  HEART = "❤️",
  ROCKET = "🚀",
  EYES = "👀",
}

M.GH_ICONS = {
  issue_open     = "",
  issue_closed   = "",
  issue_reopened = "",
  issue_skip     = "",
  pr_open        = "",
  pr_closed      = "",
  pr_draft       = "",
  pr_merged      = "",
  branch         = "",
  comment        = "",
  comments       = "",
  check          = "",
  x              = "",
}

-- ui stuff ------------------------------------------------------------------

function M.text_width(buf)
  local win = buf and fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
  local info = win and fn.getwininfo(win)[1]
  if not info then
    return vim.o.columns
  end
  return info.width - info.textoff
end

---@param c string|table
---@param bufnr? integer buffer whose window decides the width
function M.centered(c, bufnr)
  local width = M.text_width(bufnr)
  local text_width = fn.strdisplaywidth(type(c) == "string" and c or c.value)
  local padding_left = math.max(0, math.floor((width - text_width) / 2))
  return row({ type(c) == "string" and text(c) or c }, { padding_left = padding_left })
end

---Places a dummy component with item.kind and item.pos
---metadata so that an extmark can be placed in its position.
M.Border = Component.new(function(pos)
  return text("", { item = { kind = "border", pos = pos  } })
end)

---@takes a Component, `content` and puts it in a box.
---
---What's actually happening is that I'm sandwiching every side of
---the component with blank `Border` components which themelves are
---just blank `text("")` components, but are tagged with `kind` and `pos`
---metadata. Then, at some point later during the render cycle, an extmark
---is placed at those empty border components.
---
---@param content Component
---@param header? Component
---@param footer? Component
function M.boxed(content, header, footer)
  -- recursively unwinds component into left+content+right rows
  local function sandwich_component_w_side_borders(c)
    if c.tag == "row" or c.tag == "text" then
      return row { M.Border("left"), c, M.Border("right") }
    end

    local function sandwich_child(child)
      return sandwich_component_w_side_borders(child)
    end
    return col(map(c.children, sandwich_child), c.options)
  end

  local inner_content = {}
  if header then
    inner_content[#inner_content + 1] = sandwich_component_w_side_borders(header)
    inner_content[#inner_content + 1] = M.Border("mid")
  end
  inner_content[#inner_content + 1] = sandwich_component_w_side_borders(content)

  return col {
    M.Border("top"),
    col(inner_content, { foldable = true, folded = false }),
    M.Border("bot"),
  }
end

function M.build_collapsible_section(title, nodes, row_fn, folded)
  return col.tag("Section")({
    row { type(title) == "string" and text(title) or title },
    row_fn and col(map(nodes, row_fn)) or nodes,
    EmptyLine(),
  }, { foldable = true, folded = folded or false, id = "recent" })
end

function M.body_lines(body)
  return vim.split(vim.trim((body or ""):gsub("\r", "")), "\n", { plain = true })
end


-- Buffer.create helpers ------------------------------------------------------

---this gets set as the `after` field in neogit's Buffer.create
---@param ns_name string
function M.get_box_drawing_decorator(ns_name, style)
  style = style or "single"
  ---@param buffer Buffer
  return function(buffer)
    buffer:set_window_option("breakindentopt", "sbr")
    local pad = string.rep(" ", BORDER_PAD)
    local sbr = pad .. BORDER_CHARS[style].left
    buffer:set_window_option("showbreak", sbr)
    buffer:create_namespace(ns_name)
    buffer:set_decorations(ns_name, {
      on_start = function(_, _) -- ["start", tick]
        return buffer:exists() and buffer:is_valid() and buffer:is_focused()
      end,
      on_win = function(_, winid, bufnr, toprow, botrow) -- ["win", winid, bufnr, toprow, botrow]
        if bufnr ~= buffer.handle then return false end
        buffer:clear_namespace(ns_name)

        local info = vim.fn.getwininfo(winid)[1]
        local width = info.width - info.textoff

        for row = toprow, botrow do
          local lnum = row + 1
          for _, node in pairs(buffer.ui.node_index:find_by_line(lnum)) do
            local item = node.options.item
            if not (item and item.kind == "border") then goto continue end

            local pos = item.pos
            -- local style = item.style

            local chars = BORDER_CHARS[style]
            local fill = string.rep(chars.top, width - (2 + 2*BORDER_PAD))
            local l, r
            if pos == "top" then
              l = pad .. chars.topleft
              r = chars.topright .. pad
            elseif pos == "mid" then
              l = pad .. chars.midleft
              r = chars.midright .. pad
            elseif pos == "bot" then
              l = pad .. chars.botleft
              r = chars.botright .. pad
            elseif pos == "left" then
              l = pad .. chars.left .. " "
            elseif pos == "right" then
               r = " " .. chars.right .. pad
            end

            if pos == "top" then
              local tl = pad .. BORDER_CHARS[style].topleft
              local tr = BORDER_CHARS[style].topright .. pad
              buffer:set_extmark(buffer:get_namespace_id(ns_name), row, 0, {
                virt_text = { { tl .. fill .. tr, "Function" } },
                virt_text_pos = "inline",
                priority = 1,
              })
            elseif pos == "mid" then
              local ml = pad .. BORDER_CHARS[style].midleft
              local mr = BORDER_CHARS[style].midright .. pad
              buffer:set_extmark(buffer:get_namespace_id(ns_name), row, 0, {
                virt_text = { { ml .. fill .. mr, "Function" } },
                virt_text_pos = "inline",
                priority = 1,
              })
            elseif pos == "bot" then
              local bl = pad .. BORDER_CHARS[style].botleft
              local br = BORDER_CHARS[style].botright .. pad
              buffer:set_extmark(buffer:get_namespace_id(ns_name), row, 0, {
                virt_text = { { bl .. fill .. br, "Function" } },
                virt_text_pos = "inline",
                priority = 1,
              })
            elseif pos == "left" then
              local l = pad .. BORDER_CHARS[style].left .. " "
              buffer:set_extmark(buffer:get_namespace_id(ns_name), row, 0, {
                virt_text = { { l, "Function" } },
                virt_text_pos = "inline",
                priority = 1,
              })
            elseif pos == "right" then
              local r = " " .. BORDER_CHARS[style].right .. pad
              buffer:set_extmark(buffer:get_namespace_id(ns_name), row, 0, {
                virt_text = { { r, "Function" } },
                virt_text_pos = "right_align",
                virt_text_repeat_linebreak = true,
                priority = 1,
              })
            end

            ::continue::
          end
        end


        return true
      end,
    })
  end
end

function M.get_buffer_n_mappings(buffer)
  local status_maps = config.get_reversed_status_maps()
  return {
    [status_maps["Close"]] = function(b) b:close() end,
    [status_maps["Toggle"]] = function(b)
      local fold = b.ui:get_fold_under_cursor()
      if not fold then return end
      if fold.options.on_open then
        fold.options.on_open(fold, b.ui)
      else
        local start = fold:row_range_abs()
        ---@diagnostic disable-next-line: param-type-mismatch
        if pcall(vim.cmd, "normal! za") then
          b:move_cursor(start)
          fold.options.folded = not fold.options.folded
        end
      end
    end,
    ["R"] = function() buffer:load() end,
    ["<CR>"] = function(b)
      local item = b.ui:get_item_under_cursor()
      if not item then return end
      if item.kind == "pr" then
        require("neogit.buffers.guh-pr").new(buffer.repo, item.id):open()
      elseif item.kind == "issue" then
        -- vim.notify(vim.inspect(item))
        require("neogit.buffers.guh-issue").new(buffer.repo, item.id):open()
        -- vim.cmd("Guh " .. self.repo .. "#" .. item.id)
      elseif item.kind == "branch" then
        vim.cmd("Guh " .. buffer.repo .. "/tree/" .. item.id)
      elseif item.kind == "commit" then
        require("guh.pr").show_commit(item.id, buffer.repo, true)
      end
    end,
  }
end

return M
