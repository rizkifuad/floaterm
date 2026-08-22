local M = {}

local function config()
  return require("floaterm.state").config.zmx
end

function M.enabled()
  return config() and config().enabled
end

function M.prefix()
  local zmx = config()
  if zmx.session_prefix and zmx.session_prefix ~= "" then
    return zmx.session_prefix
  end

  if vim.env.VIM_SESSION and vim.env.VIM_SESSION ~= "" then
    return vim.env.VIM_SESSION
  end

  -- Neovim stores the loaded session as its full path. zmx names should be
  -- portable and readable, so use just its final component ("dotfiles" here).
  local session = vim.v.this_session
  if session and session ~= "" then
    return vim.fn.fnamemodify(session, ":t")
  end

  return "abc"
end

function M.command()
  return config().command or "zmx"
end

function M.attach_command(session)
  local escaped_session = vim.fn.shellescape(session)
  return M.command()
    .. " a "
    .. escaped_session
    .. "; "
    .. M.command()
    .. " l --short | grep -Fqx -- "
    .. escaped_session
    .. " || exit"
end

function M.display_name(session)
  local prefix = M.prefix() .. "."
  if vim.startswith(session, prefix) then
    return session:sub(#prefix + 1)
  end
  return session
end

function M.session_name(name)
  name = vim.trim(name)
  local prefix = M.prefix() .. "."
  return vim.startswith(name, prefix) and name or prefix .. name
end

function M.session_exists(session)
  for _, name in ipairs(M.list_sessions()) do
    if name == session then
      return true
    end
  end
  return false
end

function M.kill(session)
  vim.fn.system({ M.command(), "kill", session, "--force" })
  if vim.v.shell_error ~= 0 then
    vim.notify("floaterm: unable to kill zmx session " .. session, vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.list_sessions()
  local prefix = M.prefix() .. "."
  local output = vim.fn.systemlist({ M.command(), "l", "--short" })
  if vim.v.shell_error ~= 0 then
    vim.notify("floaterm: unable to list zmx sessions", vim.log.levels.WARN)
    return {}
  end

  local sessions, seen = {}, {}
  for _, line in ipairs(output) do
    -- --short emits one name per line. Taking the first field also supports
    -- older zmx versions whose list output includes metadata.
    local name = line:match("^%s*(%S+)")
    if name and vim.startswith(name, prefix) and not seen[name] then
      seen[name] = true
      table.insert(sessions, name)
    end
  end
  table.sort(sessions)
  return sessions
end

function M.next_session(terminals)
  local prefix = M.prefix()
  local used, highest = {}, 0
  for _, term in ipairs(terminals or {}) do
    local number = term.session and term.session:match("^" .. vim.pesc(prefix) .. "%.(%d+)$")
    if number then
      used[tonumber(number)] = true
      highest = math.max(highest, tonumber(number))
    end
  end
  for _, name in ipairs(M.list_sessions()) do
    local number = name:match("^" .. vim.pesc(prefix) .. "%.(%d+)$")
    if number then
      used[tonumber(number)] = true
      highest = math.max(highest, tonumber(number))
    end
  end
  return prefix .. "." .. highest + 1
end

function M.restore()
  local sessions = M.list_sessions()
  if #sessions == 0 then
    sessions = { M.prefix() .. ".1" }
  end

  local terminals = {}
  for _, session in ipairs(sessions) do
    table.insert(terminals, { name = M.display_name(session), session = session })
  end
  return terminals
end

return M
