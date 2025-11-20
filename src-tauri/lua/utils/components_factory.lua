-- src-tauri/lua/utils/component_factory.lua

local M = {}

local function clone_table(t)
  local new = {}
  if t then
    for k, v in pairs(t) do
      new[k] = v
    end
  end
  return new
end

-- Crea un componente normalizado a partir del spec del meta (ui.lua)
function M.create_component(spec)
  if not spec then
    return nil
  end

  -- Campos comunes a todos los componentes
  local comp = {
    id          = spec.id,
    type        = spec.type,
    required    = spec.required == true,
    data_type   = spec.data_type or "string",
    validations = clone_table(spec.validations) or {},
  }

  -- ======== IMAGE =========
  if spec.type == "image" then
    comp.kind  = "image"
    comp.file  = spec.file
    comp.size  = spec.size or "medium"
    comp.align = spec.align or "center"

  -- ======== TEXT INPUT =========
  elseif spec.type == "text_input" then
    comp.kind        = "input"
    comp.label       = spec.label or ""
    comp.placeholder = spec.placeholder or ""
    comp.value       = spec.value or ""
    comp.required    = spec.required == true
    comp.data_type   = spec.data_type or "string"
    comp.validations = clone_table(spec.validations) or {}

  -- ======== BUTTON =========
  elseif spec.type == "button" then
    comp.kind              = "button"
    comp.text              = spec.text or ""
    comp.style             = spec.style or "primary"
    comp.width             = spec.width or "auto"
    comp.on_click          = spec.on_click or {}
    comp.enabled_by_default = (spec.enabled_by_default ~= false)

  -- ======== TEXT =========
  elseif spec.type == "text" then
    comp.kind    = "text"
    comp.content = spec.content or ""
    comp.align   = spec.align or "left"
    comp.size    = spec.size or 14

  -- ======== SPACER =========
  elseif spec.type == "spacer" then
    comp.kind   = "spacer"
    comp.height = spec.height or 8

  -- ======== TABLE (ejemplo base) =========
  elseif spec.type == "table" then
    comp.kind    = "table"
    comp.columns = clone_table(spec.columns) or {}
    comp.rows    = clone_table(spec.rows) or {}
  end

  return comp
end

return M
