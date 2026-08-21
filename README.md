# Floaterm

> [!WARNING]
> This fork contains AI generated code and only intended for my personal use. Use with caution.

A beautiful toggleable floating window for managing terminal buffers within Neovim

![floaterm-with-border](https://github.com/user-attachments/assets/8a51aeff-dcc5-477f-a282-9b48a1e5bf2b)
![floaterm-noborder](https://github.com/user-attachments/assets/15e19849-69e6-432b-8fd9-7ffaad872e28)

## Install 

```lua 
{
    "nvzone/floaterm",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = "FloatermToggle",
}          
```

## Default config

```lua
 {
    border = false,
    size = { h = 60, w = 70 },

    -- to use, make this func(buf)
    mappings = { sidebar = nil, term = nil},

    -- Default sets of terminals you'd like to open
    terminals = {
      { name = "Terminal" },
      -- cmd can be function too
      { name = "Terminal", cmd = "neofetch" },
      -- More terminals
    },
}
```

## Mappings

This are the mappings for sidebar 
- <kbd>a</kbd> -> add new terminal
- <kbd>e</kbd> -> edit terminal name
- Pressing any number within sidebar will switch to that terminal


Must be pressed in main terminal buffer
- <kbd>Ctrl + h</kbd> -> Switch to sidebar
- <kbd>Ctrl + j</kbd> -> Cycle to prev terminal
- <kbd>Ctrl + k</kbd> -> Cycle to next terminal

Add new mapping

```lua 
  {
     mappings = {
       term = function(buf)
         vim.keymap.set({ "n", "t" }, "<C-p>", function()
           require("floaterm.api").cycle_term_bufs "prev"
         end, { buffer = buf })
       end,
     },
  },
```

## zmx sessions

Set `zmx.enabled = true` to use [zmx](https://github.com/neurosnap/zmx) as the
terminal backend. Floaterm then keeps only one Neovim terminal buffer: switching
an entry detaches (`Ctrl + \\`) from the active zmx session and attaches that
buffer to the selected one.

```lua
{
  zmx = { enabled = true },
}
```

The session prefix is `$VIM_SESSION`, so new entries are named
`$VIM_SESSION.1`, `$VIM_SESSION.2`, and so on. If that variable is unset but a
Neovim session is loaded, Floaterm uses the session filename (for example,
`~/.local/share/nvim/sessions/dotfiles` becomes `dotfiles`). Otherwise the
prefix is `abc`. On a fresh Neovim instance Floaterm runs `zmx l --short` and
restores only sessions matching the current prefix; if there are none, it starts
with `<prefix>.1`. Set `zmx.session_prefix` to override this behavior.
