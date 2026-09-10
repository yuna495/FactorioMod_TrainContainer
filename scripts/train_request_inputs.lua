local inputs = { name = 'train-container-request-input' }
local function state()
  storage.train_request_inputs = storage.train_request_inputs or { owners = {}, registrations = {} }
  return storage.train_request_inputs
end
local function position(entity, reversed)
  if not entity or not entity.valid or not entity.unit_number or entity.name == 'entity-ghost' then return end
  local name, width, height = MergingChests.get_merged_chest_info(entity.name)
  if name ~= MergingChests.chest_names.steel and name ~= MergingChests.chest_names.infinity then return end
  local sign = reversed and 1 or -1
  return { x = entity.position.x + sign * (width - 1) / 2, y = entity.position.y + sign * (height - 1) / 2 }
end
function inputs.get(entity)
  -- Also repairs script-created owners and follows moves when an active group
  -- or open GUI next reads the port, without scanning idle entities.
  return inputs.register(entity)
end
function inputs.remove(unit)
  local data = state()
  local record = data.owners[unit]
  if not record then return end
  data.owners[unit] = nil
  data.registrations[record.owner_registration] = nil
  data.registrations[record.input_registration] = nil
  if record.input.valid then record.input.destroy() end
end
function inputs.register(entity, reversed)
  local point = position(entity)
  if not point then return end
  local data = state()
  local record = data.owners[entity.unit_number]
  if reversed == nil then reversed = record and record.reversed == true or false end
  point = position(entity, reversed)
  if record and record.input.valid then
    record.reversed = reversed
    -- Lamps cannot use the surface-teleport overload, even on the same surface.
    if record.input.surface ~= entity.surface then
      inputs.remove(entity.unit_number)
      return inputs.register(entity, reversed)
    end
    if record.input.position.x ~= point.x or record.input.position.y ~= point.y then
      if not record.input.teleport(point) then
        inputs.remove(entity.unit_number)
        return inputs.register(entity, reversed)
      end
    end
    if record.input.force ~= entity.force then record.input.force = entity.force end
    return record.input
  end
  if record then inputs.remove(entity.unit_number) end
  local input = assert(entity.surface.create_entity { name = inputs.name, position = point,
    force = entity.force, create_build_effect_smoke = false }, 'Cannot create TrainContainer request input')
  input.destructible = false
  input.minable = false
  input.operable = false
  input.active = false
  record = { owner = entity, input = input, reversed = reversed,
    owner_registration = script.register_on_object_destroyed(entity),
    input_registration = script.register_on_object_destroyed(input) }
  data.owners[entity.unit_number] = record
  data.registrations[record.owner_registration] = { unit = entity.unit_number, owner = true }
  data.registrations[record.input_registration] = { unit = entity.unit_number }
  return input
end
function inputs.flip(entity)
  if not entity or not entity.valid then return false end
  if entity.name == inputs.name then
    local owner
    for _, record in pairs(state().owners) do
      if record.input == entity then owner = record.owner; break end
    end
    entity = owner
  end
  if not inputs.register(entity) then return false end
  return inputs.register(entity, not state().owners[entity.unit_number].reversed) ~= nil
end
function inputs.on_object_destroyed(event)
  local data = state()
  local destroyed = data.registrations[event.registration_number]
  if not destroyed then return end
  local record = data.owners[destroyed.unit]
  local owner = record and record.owner
  local reversed = record and record.reversed
  inputs.remove(destroyed.unit)
  if not destroyed.owner and owner and owner.valid then inputs.register(owner, reversed) end
end
function inputs.rebuild()
  local data = state()
  local stale = {}
  for unit, record in pairs(data.owners) do
    if not record.owner.valid then stale[#stale + 1] = unit end
  end
  for _, unit in ipairs(stale) do inputs.remove(unit) end
  for _, surface in pairs(game.surfaces) do
    local kept = {}
    for _, entity in ipairs(surface.find_entities_filtered { type = {'container', 'infinity-container'} }) do
      local input = inputs.register(entity)
      if input then kept[input.unit_number] = true end
    end
    for _, input in ipairs(surface.find_entities_filtered { name = inputs.name }) do
      if not kept[input.unit_number] then input.destroy() end
    end
  end
end
return inputs
