local ui         = require("ui")                   
local factory    = require("utils.component_factory")
local validation = require("utils.validations")
local navigation = require("utils.navigation")

local M = {}

local SPEC = ui.get_ui_spec()

local STATE = nil

local function new_state()
  local initial_screen = SPEC.initial_screen or "login"
  return {
    screen          = initial_screen,
    values          = {},   
    errors          = {},   
    enabled_buttons = {},   
  }
end

local function get_state()
  if not STATE then
    STATE = new_state()
  end
  return STATE
end

local function find_screen(screen_id)
  for _, screen in ipairs(SPEC.screens or {}) do
    if screen.id == screen_id then
      return screen
    end
  end
  return nil
end

local function index_components(screen_spec)
  local idx = {}
  for _, spec in ipairs(screen_spec.components or {}) do
    idx[spec.id] = spec
  end
  return idx
end

function M.init_state()
  STATE = new_state()
end

function M.build_current_view()
  local state = get_state()
  local screen_spec = find_screen(state.screen)

  if not screen_spec then
    return {
      error = "Pantalla no encontrada: " .. tostring(state.screen)
    }
  end

  local comps = {}
  local components_index = index_components(screen_spec)

  for _, spec in ipairs(screen_spec.components or {}) do
    local comp = factory.create_component(spec)

    if comp.kind == "input" then
      comp.value = state.values[comp.id]
      comp.error = state.errors[comp.id]
    end

    if comp.kind == "button" then
      local override = state.enabled_buttons[comp.id]
      if override ~= nil then
        comp.enabled = override
      else
        comp.enabled = comp.enabled_by_default
      end
    end

    table.insert(comps, comp)
  end

  return {
    screen = {
      id         = screen_spec.id,
      title      = screen_spec.title or screen_spec.id,
      layout     = screen_spec.layout or { type = "vertical", align = "center" },
      components = comps,
    },
    state = {
      screen          = state.screen,
      values          = state.values,
      errors          = state.errors,
      enabled_buttons = state.enabled_buttons,
    },
  }
end

function M.on_input_change(screen_id, field_id, new_value)
  local state = get_state()

  state.screen = screen_id or state.screen
  state.values[field_id] = new_value

  local screen_spec = find_screen(state.screen)
  if not screen_spec then
    return state
  end

  local components_index = index_components(screen_spec)
  local field_spec = components_index[field_id]

  if field_spec then
    local ok, err = validation.validate_field(field_spec, new_value)
    if not ok then
      state.errors[field_id] = err
    else
      state.errors[field_id] = nil
    end
  end

  state.enabled_buttons = validation.update_enabled_buttons(
    screen_spec,
    state.values,
    state.errors,
    state.enabled_buttons
  )

  return state
end

function M.on_button_click(screen_id, button_id)
  local state = get_state()
  state.screen = screen_id or state.screen

  local screen_spec = find_screen(state.screen)
  if not screen_spec then
    return state
  end

  local nav_event = nil

  if screen_spec.on_click_rules and screen_spec.on_click_rules[button_id] then
    local rules = screen_spec.on_click_rules[button_id]

    for _, rule in ipairs(rules) do
      if rule.type == "validate_before" then
        local components_index = index_components(screen_spec)
        local ok, errors = validation.validate_fields(
          components_index,
          state.values,
          rule.fields,
          factory
        )

        state.errors = errors

        if not ok then
          nav_event = nil
          break
        end
      elseif rule.type == "navigate" then
        nav_event = rule.event
      end
    end
  end

  state.enabled_buttons = validation.update_enabled_buttons(
    screen_spec,
    state.values,
    state.errors,
    state.enabled_buttons
  )

  if nav_event then
    local next_screen, _mode = navigation.resolve(screen_id, nav_event)
    if next_screen and next_screen ~= "" then
      state.screen          = next_screen
      state.values          = {}
      state.errors          = {}
      state.enabled_buttons = {}
    end
  end

  return state, nav_event
end

return M
