local M = {}

local function clone_table(t)
  local new = {}
  if t then
    for k, v in pairs(t) do
      if type(v) == "table" then
        new[k] = clone_table(v)
      else
        new[k] = v
      end
    end
  end
  return new
end

function M.create_component(spec)
  if not spec then
    return nil
  end

  local comp = {
    id          = spec.id,
    type        = spec.type,
    kind        = nil,
    label       = spec.label,
    placeholder = spec.placeholder,
    required    = spec.required,
    validations = spec.validations and clone_table(spec.validations) or nil,
    data_type   = spec.data_type,
  }

  if spec.type == "text" then
    comp.kind    = "text"
    comp.content = spec.content or ""
    comp.align   = spec.align or "left"
    comp.size    = spec.size or 14

  elseif spec.type == "text_input" then
    comp.kind = "input"

  elseif spec.type == "button" then
    comp.kind               = "button"
    comp.text               = spec.text or spec.id or ""
    comp.style              = spec.style or "primary"
    comp.width              = spec.width or "auto"
    comp.enabled_by_default = (spec.enabled_by_default ~= false)

  elseif spec.type == "image" then
    comp.kind  = "image"
    comp.file  = spec.file or ""
    comp.size  = spec.size or "medium"
    comp.align = spec.align or "center"

  elseif spec.type == "spacer" then
    comp.kind   = "spacer"
    comp.height = spec.height or 8

  elseif spec.type == "table" then
    comp.kind    = "table"
    comp.columns = clone_table(spec.columns) or {}
    comp.rows    = clone_table(spec.rows) or {}

  else
    comp.kind = "unknown"
  end

  return comp
end

return M
