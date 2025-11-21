local M = {}

local meta = rawget(_G, "META") or {}

local function build_ui_spec_from_meta(root)
  local screens = root.screens or {}

  local initial_screen

  if root.operational_rules
    and root.operational_rules.access
    and root.operational_rules.access.login_screen
  then
    initial_screen = root.operational_rules.access.login_screen
  elseif #screens > 0 and screens[1].id then
    initial_screen = screens[1].id
  else
    initial_screen = "login"
  end

  return {
    initial_screen = initial_screen,
    screens = screens,
  }
end

local UI_SPEC = build_ui_spec_from_meta(meta)

function M.get_ui_spec()
  return UI_SPEC
end

return M
