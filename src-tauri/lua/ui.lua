-- src-tauri/lua/ui.lua
local M = {}
local LOGO_BASE64 = MAIN_LOGO_BASE64 or ""

local UI_SPEC = {
  initial_screen = "login",

  screens = {
    -- Pantalla LOGIN
    {
      id = "login",
      title = "Iniciar sesión",
      layout = {
        type = "vertical",
        align = "center",
        spacing = "medium",
      },
      components = {
        -- LOGO desde meta.json (via MAIN_LOGO_BASE64)
        {
          type = "image",
          id = "main_logo",
          file = LOGO_BASE64,
          size = "medium",
          align = "center",
        },
        {
          type = "spacer",
          id = "sp_logo",
          height = 16,
        },

        {
          type = "text",
          id = "title_login",
          content = "Login",
          align = "center",
          size = 22,
        },
        {
          type = "text_input",
          id = "correo",
          label = "Correo electrónico",
          placeholder = "ejemplo@correo.com",
          data_type = "email",
          required = true,
          validations = {
            min_length = 5,
          },
        },
        {
          type = "text_input",
          id = "contrasena",
          label = "Contraseña",
          placeholder = "••••••••",
          data_type = "password",
          required = true,
          validations = {
            min_length = 8,
          },
        },
        {
          type = "button",
          id = "btn_iniciar",
          text = "Iniciar sesión",
          style = "primary",
          width = "full",
          enabled_by_default = false,
          on_click = { "validar_y_login" },
        },
        {
          type = "button",
          id = "btn_ir_registro",
          text = "Crear cuenta",
          style = "text",
          width = "auto",
          on_click = { "ir_a_registro" },
        },
      },
    },

    -- Pantalla REGISTRO
    {
      id = "registro",
      title = "Registro",
      layout = {
        type = "vertical",
        align = "center",
        spacing = "medium",
      },
      components = {
        {
          type = "text_input",
          id = "correo_registro",
          label = "Correo electrónico",
          placeholder = "ejemplo@correo.com",
          data_type = "email",
          required = true,
        },
        {
          type = "text_input",
          id = "contrasena_registro",
          label = "Contraseña",
          placeholder = "••••••••",
          data_type = "password",
          required = true,
          validations = {
            min_length = 8,
          },
        },
        {
          type = "button",
          id = "btn_crear_cuenta",
          text = "Crear cuenta",
          style = "primary",
          width = "full",
          on_click = { "crear_cuenta" },
        },
        {
          type = "button",
          id = "btn_ir_login",
          text = "Ya tengo cuenta",
          style = "text",
          width = "auto",
          on_click = { "ir_a_login" },
        },
      },
    },

    -- Pantalla HOME
    {
      id = "home",
      title = "Home",
      layout = {
        type = "vertical",
        align = "start",
        spacing = "medium",
      },
      components = {
        {
          type = "text",
          id = "txt_bienvenida",
          content = "Bienvenido",
          align = "left",
          size = 18,
        },
        {
          type = "button",
          id = "btn_logout",
          text = "Cerrar sesión",
          style = "secondary",
          width = "auto",
          on_click = { "logout" },
        },
      },
    },
  },
}

function M.get_ui_spec()
  return UI_SPEC
end

return M
