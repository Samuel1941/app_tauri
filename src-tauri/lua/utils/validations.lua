local M = {}

local function is_empty(value)
  return value == nil or value == ""
end

local function validate_required(comp, value)
  if comp.required and is_empty(value) then
    return false, "Este campo es requerido"
  end
  return true, nil
end

local function validate_min_length(comp, value)
  local rules = comp.validations or {}
  local min_len = rules.min_length

  if min_len and not is_empty(value) then
    if #tostring(value) < min_len then
      return false, "Debe tener al menos " .. tostring(min_len) .. " caracteres"
    end
  end
  return true, nil
end

local function validate_email_format(value)
  if is_empty(value) then
    return true, nil
  end
  local at_pos = string.find(value, "@")
  local dot_pos = at_pos and string.find(value, "%.", at_pos + 1) or nil
  if not (at_pos and dot_pos) then
    return false, "Correo electrónico inválido"
  end
  return true, nil
end

function M.validate_field(comp, value)
  local ok, err = validate_required(comp, value)
  if not ok then return false, err end

  if comp.data_type == "email" then
    ok, err = validate_email_format(value)
    if not ok then return false, err end
  end

  ok, err = validate_min_length(comp, value)
  if not ok then return false, err end

  return true, nil
end

function M.validate_fields(components_index, values, field_ids, component_factory)
  local errors = {}
  local all_ok = true

  for _, field_id in ipairs(field_ids or {}) do
    local spec = components_index[field_id]
    if spec then
      local comp = component_factory.create_component(spec)
      local value = values[field_id]
      local ok, err = M.validate_field(comp, value)
      if not ok then
        all_ok = false
        errors[field_id] = err
      end
    end
  end

  return all_ok, errors
end

return M
