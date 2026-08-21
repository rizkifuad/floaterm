local M = {
  ns = vim.api.nvim_create_namespace "Floaterm",
  terminals = nil,
  bar_redraw_timeout = 10000,
  prev_win_focussed = 0,

  config = {
    border = false,
    autoinsert = true,
    size = { h = 60, w = 70 },

    -- { row , col } or fn() returning the table
    position = nil,

    -- must be functions
    mappings = { sidebar = nil, term = nil },
    -- Reuse one Neovim terminal buffer and keep the actual shells in zmx.
    -- Session names are $VIM_SESSION.1, $VIM_SESSION.2, ... (or abc.*).
    zmx = {
      enabled = false,
      command = "zmx",
      session_prefix = nil,
    },
    terminals = {
      { name = "Terminal" },
    },
  },
}

return M
