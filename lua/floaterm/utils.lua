local M = {}
local api = vim.api
local map = vim.keymap.set
local state = require "floaterm.state"
local volt_redraw = require("volt").redraw
local shell = vim.o.shell
local zmx = require "floaterm.zmx"

M.convert_buf2term = function(cmd, opts)
  if cmd then
    cmd = type(cmd) == "function" and cmd() or cmd
    cmd = { shell, "-c", cmd .. "; " .. shell }
  else
    cmd = { shell }
  end
  vim.fn.jobstart(cmd, { term = true, on_exit = opts and opts.on_exit })
end

M.new_term = function(opts)
  if zmx.enabled() then
    opts = opts or {}
    local session = opts.session or zmx.next_session(state.terminals)
    state.zmx_buf = state.zmx_buf or api.nvim_create_buf(false, true)
    return {
      buf = state.zmx_buf,
      time = os.date "%H:%M",
      name = zmx.display_name(session),
      session = session,
    }
  end

  local defaults = {
    buf = api.nvim_create_buf(false, true),
    time = os.date "%H:%M",
    name = "Terminal",
  }

  return vim.tbl_extend("force", defaults, opts or {})
end

M.add_keymap = function(key, buf)
  map("n", tostring(key), function()
    M.switch_term(state.terminals[key])
  end, { buffer = state.sidebuf })
end

M.gen_term_bufs = function()
  for i, _ in ipairs(state.terminals) do
    local term = state.terminals[i]
    state.terminals[i] = vim.tbl_extend("force", M.new_term(zmx.enabled() and term or nil), term)
    local buf = state.terminals[i].buf
    M.add_keymap(i, buf)
  end
end

M.active_term = function()
  if state.active_terminal then
    return state.active_terminal
  end
  return M.get_term_by_key(state.buf) and M.get_term_by_key(state.buf)[2]
end

M.switch_term = function(term)
  if not term then
    return
  end
  state.active_terminal = term
  M.switch_buf(term.buf, term)
end

M.remove_zmx_term = function(term)
  if not state.volt_set or not zmx.enabled() or not term then
    return
  end

  local entry = M.get_term_by_key(term.session, "session")
  if not entry then
    return
  end

  local was_active = M.active_term() == term
  table.remove(state.terminals, entry[1])

  if #state.terminals == 0 then
    state.active_terminal = nil
    state.buf = nil
    state.zmx_buf = nil
    state.terminals = nil
    require("floaterm").toggle()
    return
  end

  if not was_active then
    volt_redraw(state.sidebuf, "bufs")
    return
  end

  -- A zmx session owns the process in this shared terminal buffer. Once that
  -- process exits, start the next session in a fresh buffer.
  state.zmx_buf = api.nvim_create_buf(false, true)
  for _, terminal in ipairs(state.terminals) do
    terminal.buf = state.zmx_buf
  end

  local next_index = math.min(entry[1], #state.terminals)
  state.active_terminal = nil
  M.switch_term(state.terminals[next_index])
end

M.set_termwin_hl = function()
  if state.config.border then
    vim.wo[state.win].winhl = "Normal:normal,floatborder:comment"
  else
    vim.wo[state.win].winhl = "Normal:exdarkbg,floatBorder:exdarkborder"
  end
end

M.switch_buf = function(buf, term)
  state.buf = buf

  term = term or M.get_term_by_key(buf)[2]
  if zmx.enabled() then
    state.active_terminal = term
  end

  volt_redraw(state.sidebuf, "bufs")
  volt_redraw(state.barbuf, "bar")

  if not api.nvim_win_is_valid(state.win) then
    state.win = api.nvim_open_win(state.buf, true, state.term_win_opts)
    M.set_termwin_hl()
  end

  api.nvim_set_current_win(state.win)
  api.nvim_set_current_buf(buf)

  local starts_terminal = vim.bo[buf].buftype ~= "terminal"
  if starts_terminal then
    vim.bo[buf].ft = "Floaterm"
    M.convert_buf2term(zmx.enabled() and zmx.attach_command(term.session) or term.cmd, zmx.enabled() and {
      on_exit = function()
        vim.schedule(function()
          if api.nvim_buf_is_valid(buf) then
            local entry = M.get_term_by_key(vim.b[buf].floaterm_zmx_session, "session")
            M.remove_zmx_term(entry and entry[2])
          end
        end)
      end,
    } or nil)
    volt_redraw(state.barbuf, "bar")

    map({ "t", "n" }, "<C-h>", function()
      require("floaterm.api").switch_wins()
    end, { buffer = state.buf })

    map({ "t", "n" }, "<C-a>", function()
      require("floaterm.api").new_term()
    end, { buffer = state.buf })

    map({ "n", "t" }, "<C-j>", function()
      require("floaterm.api").cycle_term_bufs "next"
    end, { buffer = state.buf })

    map({ "n", "t" }, "<C-k>", function()
      require("floaterm.api").cycle_term_bufs "prev"
    end, { buffer = state.buf })

    require("volt").mappings {
      bufs = { state.buf, state.sidebuf, state.barbuf },
      after_close = function()
        M.close_timers()
        state.volt_set = false
        state.terminals = nil
        state.buf = nil
        state.zmx_buf = nil
        state.active_terminal = nil
        state.sidebuf = nil
        state.barbuf = nil
        api.nvim_del_augroup_by_name "FloatermAu"
      end,
    }

    if state.config.mappings.term then
      state.config.mappings.term(state.buf)
    end
  end

  if zmx.enabled() and not starts_terminal and vim.b[buf].floaterm_zmx_session ~= term.session then
    local job_id = vim.b[buf].terminal_job_id
    vim.api.nvim_chan_send(job_id, "\28") -- zmx's Ctrl-\\ detach shortcut
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].terminal_job_id == job_id then
        vim.api.nvim_chan_send(job_id, zmx.attach_command(term.session) .. "\r")
      end
    end, 30)
  end
  if zmx.enabled() and vim.bo[buf].buftype == "terminal" then
    vim.b[buf].floaterm_zmx_session = term.session
  end

  if state.config.autoinsert then
    vim.cmd.startinsert()
  end
end

M.get_term_by_key = function(tocompare, name)
  name = name or "buf"

  for i, v in ipairs(state.terminals or {}) do
    if tocompare == v[name] then
      return { i, v }
    end
  end
end

M.get_buf_on_cursor = function()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  if zmx.enabled() then
    row = row - 1
  end

  if not state.terminals[row] then
    vim.notify("place cursor on the terminal name", vim.log.levels.WARN)
    return
  end

  return row
end

M.close_timers = function()
  state.bar_redraw_timer:stop()
  state.bar_redraw_timer:close()
  state.bar_redraw_timer = nil
end

return M
