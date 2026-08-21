local map = vim.keymap.set
local state = require "floaterm.state"
local api = require "floaterm.api"
local zmx = require "floaterm.zmx"

return function()
  map("n", "a", api.new_term, { buffer = state.sidebuf })
  if zmx.enabled() then
    map("n", "d", api.kill_term, { buffer = state.sidebuf })
  else
    map("n", "e", api.edit_name, { buffer = state.sidebuf })
    map("n", "d", api.delete_term, { buffer = state.sidebuf })
  end
  map("n", "<C-l>", api.switch_wins, { buffer = state.sidebuf })

  if state.config.mappings.sidebar then
    state.config.mappings.sidebar(state.sidebuf)
  end
end
