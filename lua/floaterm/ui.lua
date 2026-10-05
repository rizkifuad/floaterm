local M = {}
local state = require "floaterm.state"
local utils = require "floaterm.utils"
local voltui = require "volt.ui"
local zmx = require "floaterm.zmx"

local num_icons = {
  -- '󰎡',
  "󰎤",
  "󰎧",
  "󰎪",
  "󰎭",
  "󰎱",
  "󰎳",
  "󰎶",
  "󰎹",
  "󰎼",
}

M.items = function()
  local items = {}

  if zmx.enabled() then
    table.insert(items, { "󱂬  " .. zmx.prefix(), "ExGreen" })
  end

  for i, v in ipairs(state.terminals) do
    local icon = "" .. "  "
    local label = icon .. (v.name or "Terminal")
    local hl = utils.active_term() == v and "ExGreen" or "Comment"
    local actions = {
      click = function()
        utils.switch_term(v)
      end,
    }
    table.insert(items, { " " .. (num_icons[i] or tostring(i)) .. " " .. label .. " ", hl, actions })
  end

  table.insert(items, { "  a add  ", "comment", { click = function() require("floaterm.api").new_term() end } })
  table.insert(items, {
    zmx.enabled() and "  d kill  " or "  e edit  ",
    "comment",
    { click = function()
      if zmx.enabled() then
        require("floaterm.api").kill_term()
      else
        require("floaterm.api").edit_name()
      end
    end },
  })

  return { voltui.hpad(items, state.w - (state.config.border and 2 or 0)) }
end

M.bar = function()
  local w = state.w - (state.config.border and 2 or 0)

  local active_term = utils.active_term()
  local active_label = "  " .. active_term.name

  local bytes = vim.api.nvim_buf_get_offset(state.buf, vim.api.nvim_buf_line_count(state.buf)) - 1

  local line = {
    { active_label, "xdarkbg" },
    { "_pad_" },
    { string.format("   %.1f MB ", bytes / (1024 * 1024)), "exgreen" },
    { "   " .. active_term.time, "exred" },
  }
  return {
    voltui.hpad(line, w),
  }
end

return M
