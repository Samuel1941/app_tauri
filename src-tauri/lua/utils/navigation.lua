local M = {}

local TRANSITIONS = {
  {
    event = "login_exitoso",
    from  = "login",
    to    = "home",
    mode  = "replace",
  },
  {
    event = "ir_a_registro",
    from  = "login",
    to    = "registro",
    mode  = "push",
  },
  {
    event = "registro_completo",
    from  = "registro",
    to    = "home",
    mode  = "replace",
  },
  {
    event = "ir_a_login",
    from  = "registro",
    to    = "login",
    mode  = "replace",
  },
  {
    event = "ir_a_login",
    from  = "home",
    to    = "login",
    mode  = "replace",
  },
}

function M.resolve(current_screen, event_name)
  for _, t in ipairs(TRANSITIONS) do
    if t.from == current_screen and t.event == event_name then
      return t.to, t.mode
    end
  end

  return current_screen, nil
end

return M
