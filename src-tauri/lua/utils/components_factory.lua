-- lua/utils/component_factory.lua
-- Fábrica de nodos UI para Tauri

local M = {}

-- Text
function M.TextNode(id, text, opts)
  opts = opts or {}
  return {
    type = "text",
    id = id,
    text = text,
    styles = opts.styles or {},
  }
end

-- Input de texto
function M.InputTextNode(id, hint, opts)
  opts = opts or {}
  return {
    type = "input_text",
    id = id,
    hint = hint,
    value = opts.value or "",
    styles = opts.styles or {},
  }
end

-- Input de password
function M.InputPasswordNode(id, hint, opts)
  opts = opts or {}
  return {
    type = "input_password",
    id = id,
    hint = hint,
    value = opts.value or "",
    styles = opts.styles or {},
  }
end

-- Spacer
function M.SpacerNode(id, height)
  return {
    type = "spacer",
    id = id,
    height = height or 8,
  }
end

-- Botón
function M.ButtonNode(id, text, opts)
  opts = opts or {}
  return {
    type = "button",
    id = id,
    text = text,
    action = opts.action or nil, -- ej: "login"
    styles = opts.styles or {},
  }
end

-- NUEVO: Imagen en base64
function M.ImageNode(id, base64, opts)
  opts = opts or {}
  return {
    type = "image",
    id = id,
    base64 = base64,
    width = opts.width,
    height = opts.height,
    styles = opts.styles or {},
  }
end

return M
