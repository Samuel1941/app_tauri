-- src-tauri/lua/utils/ui_rules.lua

local ui         = require("ui")                    -- src-tauri/lua/ui.lua
local factory    = require("utils.component_factory")
local validation = require("utils.validation")
local navigation = require("utils.navigation")

local M = {}

-- ========================================
-- SPEC estático de la UI (estructura)
-- ========================================
local SPEC = ui.get_ui_spec()

-- ========================================
-- STATE global (vive en Lua)
-- ========================================
local STATE = nil

local function new_state()
  return {
    screen          = SPEC.initial_screen or "login",
    values          = {},   -- [input_id] = "valor"
    errors          = {},   -- [input_id] = "mensaje error"
    enabled_buttons = {},   -- [button_id] = boolean
  }
end

-- Devuelve el STATE actual, inicializando si hace falta
local function get_state()
  if not STATE then
    STATE = new_state()
  end
  return STATE
end

-- API pública: inicializa (si no existe) y devuelve STATE
function M.init_state()
  return get_state()
end

-- API pública: resetea STATE por completo
function M.reset_state()
  STATE = new_state()
  return STATE
end

-- ========================================
-- Helpers de screens / componentes
-- ========================================

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
  for _, comp in ipairs(screen_spec.components or {}) do
    if comp.id then
      idx[comp.id] = comp
    end
  end
  return idx
end

-- ========================================
-- build_current_view:
--  Devuelve la vista actual + estado
-- ========================================
-- Estructura:
-- {
--   screen = { id, title, layout, components = [...] },
--   state  = { screen, values, errors, enabled_buttons }
-- }
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

    -- Inyectar value y error en inputs
    if comp.kind == "input" then
      comp.value = state.values[comp.id]
      comp.error = state.errors[comp.id]
    end

    -- Inyectar enabled en botones
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
      title      = screen_spec.title,
      layout     = screen_spec.layout,
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

-- ========================================
-- on_input_change:
--  React → Tauri → Lua para cambios de input
-- ========================================
function M.on_input_change(screen_id, field_id, value)
  local state = get_state()
  state.screen = screen_id
  state.values[field_id] = value

  local screen_spec = find_screen(screen_id)
  if not screen_spec then
    return state
  end

  local components_index = index_components(screen_spec)
  local field_spec = components_index[field_id]

  -- Validación de ese campo
  if field_spec and field_spec.type == "text_input" then
    local comp = factory.create_component(field_spec)
    local ok, err = validation.validate_field(comp, value)

    if ok then
      state.errors[field_id] = nil
    else
      state.errors[field_id] = err
    end
  end

  -- Ejemplo: habilitar botón de login si correo y contraseña están OK
  if screen_id == "login" then
    local correo_spec = components_index["correo"]
    local pass_spec   = components_index["contrasena"]

    if correo_spec and pass_spec then
      local correo_comp = factory.create_component(correo_spec)
      local pass_comp   = factory.create_component(pass_spec)

      local correo_val  = state.values["correo"]
      local pass_val    = state.values["contrasena"]

      local correo_ok,_ = validation.validate_field(correo_comp, correo_val)
      local pass_ok,_   = validation.validate_field(pass_comp, pass_val)

      state.enabled_buttons["btn_iniciar"] = (correo_ok and pass_ok)
    end
  end

  return state
end

-- ========================================
-- on_button_click:
--  React → Tauri → Lua al hacer click
-- ========================================
function M.on_button_click(screen_id, button_id)
  local state = get_state()
  state.screen = screen_id

  local screen_spec = find_screen(screen_id)
  if not screen_spec then
    return state, nil
  end

  local components_index = index_components(screen_spec)
  local nav_event = nil

  -- ------------------
  -- Lógica por pantalla
  -- ------------------

  -- LOGIN
  if screen_id == "login" and button_id == "btn_iniciar" then
    local fields = { "correo", "contrasena" }
    local ok, errors = validation.validate_fields(components_index, state.values, fields, factory)
    state.errors = errors or {}

    if not ok then
      return state, nil
    end

    -- Aquí podrías hacer invoke_lua externo (login real con backend)
    local login_ok = true
    if login_ok then
      nav_event = "login_exitoso"
    else
      state.errors["contrasena"] = "Usuario o contraseña incorrectos"
    end

  elseif screen_id == "login" and button_id == "btn_ir_registro" then
    nav_event = "ir_a_registro"

  -- REGISTRO
  elseif screen_id == "registro" and button_id == "btn_crear_cuenta" then
    local fields = { "correo_registro", "contrasena_registro" }
    local ok, errors = validation.validate_fields(components_index, state.values, fields, factory)
    state.errors = errors or {}

    if not ok then
      return state, nil
    end

    local registro_ok = true
    if registro_ok then
      nav_event = "registro_completo"
    end

  elseif screen_id == "registro" and button_id == "btn_ir_login" then
    nav_event = "ir_a_login"

  -- HOME
  elseif screen_id == "home" and button_id == "btn_logout" then
    nav_event = "ir_a_login"
  end

  -- Aplicar navegación según transitions
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
