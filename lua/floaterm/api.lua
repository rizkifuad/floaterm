local state = require "floaterm.state"
local utils = require "floaterm.utils"
local volt_redraw = require("volt").redraw
local zmx = require "floaterm.zmx"
local M = {}

local function terminal_index(term)
  for index, terminal in ipairs(state.terminals or {}) do
    if terminal == term then
      return index
    end
  end
end

M.edit_name = function()
  if zmx.enabled() then
    vim.notify("floaterm: zmx session names cannot be renamed", vim.log.levels.INFO)
    return
  end
  local row = utils.get_buf_on_cursor()

  if row then
    vim.ui.input({ prompt = "   Enter name: " }, function(input)
      state.terminals[row].name = input
      vim.api.nvim_echo({}, false, {})
      volt_redraw(state.sidebuf, "bufs")
    end)
  end
end

M.new_term = function(opts)
  opts = opts or {}

  if opts.name == "auto" and not zmx.enabled() then
    vim.ui.input({ prompt = "   Enter name: " }, function(input)
      opts.name = input
      vim.api.nvim_echo({}, false, {})
    end)
  end

  local details = utils.new_term(opts)
  table.insert(state.terminals, details)

  if not opts.hidden then
    utils.switch_term(details)
  end

  utils.add_keymap(#state.terminals, details.buf)
end

M.switch_wins = function()
  local curwin = vim.api.nvim_get_current_win()

  local newwin = curwin == state.win and "sidewin" or "win"
  vim.api.nvim_set_current_win(state[newwin])
end

M.cycle_term_bufs = function(direction)
  if not state.terminals or #state.terminals == 0 then
    return
  end

  local cur_index
  if zmx.enabled() then
    local index = terminal_index(state.active_terminal)
    cur_index = index and { index } or nil
  else
    cur_index = utils.get_term_by_key(state.buf)
  end

  if not cur_index then
    -- If not in a terminal, switch to the first one
    utils.switch_term(state.terminals[1])
    return
  end

  local new_index = (cur_index[1] + (direction == "prev" and -2 or 0)) % #state.terminals
  utils.switch_term(state.terminals[new_index + 1])
end

M.delete_term = function(buf)
  local method = buf and "automatic" or "manual"

  if not buf then
    local i = utils.get_buf_on_cursor()
    if i then
      buf = state.terminals[i].buf
    end
  end

  if buf then
    local index = zmx.enabled() and terminal_index(state.active_terminal) or utils.get_term_by_key(buf)[1]
    local newbuf_i = (index == 1 and index + 1) or index - 1

    table.remove(state.terminals, index)

    if #state.terminals == 0 then
      M.new_term()
    end

    newbuf_i = #state.terminals == 1 and 1 or newbuf_i

    if method == "manual" and not zmx.enabled() then
      vim.api.nvim_buf_delete(buf, { force = true })
    end

    utils.switch_term(state.terminals[newbuf_i])

    local total_lines = vim.api.nvim_buf_get_lines(state.sidebuf, 0, -1, false)

    vim.api.nvim_set_option_value("modifiable", true, { buf = state.sidebuf })
    require("volt").set_empty_lines(state.sidebuf, #total_lines, 20)
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.sidebuf })

    volt_redraw(state.sidebuf, "all")
  end
end

M.kill_term = function()
  if not zmx.enabled() then
    return
  end

  local row = utils.get_buf_on_cursor()
  local term = row and state.terminals[row]
  if term and zmx.kill(term.session) then
    utils.remove_zmx_term(term)
  end
end

M.send_cmd = function(opts)
  if not state.terminals then
    require("floaterm").open()
    require("floaterm.api").new_term(opts)
  else
    opts.cmd = type(opts.cmd) == "string" and opts.cmd or opts.cmd()
    opts.buf = opts.buf or state.buf
    local bufdetails = zmx.enabled() and utils.active_term() or utils.get_term_by_key(opts.buf)[2]

    if opts.name then
      bufdetails = utils.get_term_by_key(opts.name, "name")[2]
    end

    local job_id = vim.b[bufdetails.buf].terminal_job_id
    vim.api.nvim_chan_send(job_id, opts.cmd .. " \n")
    vim.api.nvim_buf_call(bufdetails.buf, function()
      vim.cmd [[normal G]]
    end)
  end
end

return M
