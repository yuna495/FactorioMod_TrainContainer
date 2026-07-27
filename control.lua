local definitions = { 1, 2, 3, 4 }
local variants = { "", "-infinity" }
local infinity_setting = settings.startup["train-container-show-infinity-containers"]
local show_infinity_containers = infinity_setting and infinity_setting.value or false
local placeable_entities = {}
local blueprint_rotate_targets = {}
local infinity_to_normal = {}

for _, wagons in ipairs(definitions) do
  local base_name = "train-container-" .. wagons

  for _, suffix in ipairs(variants) do
    local root_name = base_name .. suffix
    local horizontal_name = root_name
    local vertical_name = root_name .. "-vertical"

    placeable_entities[root_name .. "-placeable"] = {
      horizontal = horizontal_name,
      vertical = vertical_name,
    }

    blueprint_rotate_targets[horizontal_name] = vertical_name
    blueprint_rotate_targets[vertical_name] = horizontal_name
  end

  infinity_to_normal[base_name .. "-infinity"] = base_name
  infinity_to_normal[base_name .. "-infinity-vertical"] = base_name .. "-vertical"
  infinity_to_normal[base_name .. "-infinity-placeable"] = base_name .. "-placeable"
end

local function entity_from_event(event)
  return event.entity or event.created_entity
end

local function quality_name(entity)
  return entity.quality and entity.quality.name or "normal"
end

local function is_horizontal_direction(direction)
  return direction == defines.direction.east or direction == defines.direction.west
end

local function replacement_name_for_placeable(entity)
  local variants = placeable_entities[entity.name]

  if not variants then
    return nil
  end

  local target_name = is_horizontal_direction(entity.direction) and variants.horizontal or variants.vertical

  if not show_infinity_containers then
    return infinity_to_normal[target_name] or target_name
  end

  return target_name
end

local function replace_placeable(entity)
  local target_name = replacement_name_for_placeable(entity)

  if not target_name then
    return
  end

  local surface = entity.surface
  local position = entity.position
  local force = entity.force
  local direction = entity.direction
  local source_name = entity.name
  local quality = quality_name(entity)

  entity.destroy()

  local created = surface.create_entity({
    name = target_name,
    position = position,
    force = force,
    quality = quality,
    create_build_effect_smoke = false,
    raise_built = true,
  })

  if not created then
    surface.create_entity({
      name = source_name,
      position = position,
      direction = direction,
      force = force,
      quality = quality,
      create_build_effect_smoke = false,
    })
  end
end

local function replace_placeable_ghost(entity)
  if entity.name ~= "entity-ghost" then
    return false
  end

  local variants = placeable_entities[entity.ghost_name]

  if not variants then
    return false
  end

  local surface = entity.surface
  local target_name = is_horizontal_direction(entity.direction) and variants.horizontal or variants.vertical
  local position = entity.position
  local direction = entity.direction
  local force = entity.force
  local quality = quality_name(entity)

  if not show_infinity_containers then
    target_name = infinity_to_normal[target_name] or target_name
  end

  entity.destroy()

  surface.create_entity({
    name = "entity-ghost",
    inner_name = target_name,
    position = position,
    direction = direction,
    force = force,
    quality = quality,
    create_build_effect_smoke = false,
  })

  return true
end

local function replace_hidden_infinity_ghost(entity)
  if show_infinity_containers or entity.name ~= "entity-ghost" then
    return false
  end

  local target_name = infinity_to_normal[entity.ghost_name]

  if not target_name then
    return false
  end

  local surface = entity.surface
  local position = entity.position
  local direction = entity.direction
  local force = entity.force
  local quality = quality_name(entity)

  entity.destroy()

  surface.create_entity({
    name = "entity-ghost",
    inner_name = target_name,
    position = position,
    direction = direction,
    force = force,
    quality = quality,
    create_build_effect_smoke = false,
  })

  return true
end

local function blueprint_in_cursor(player)
  local cursor = player.cursor_stack

  if not cursor or not cursor.valid_for_read or not player.is_cursor_blueprint() then
    return nil
  end

  if cursor.is_blueprint_book and cursor.active_index then
    local inventory = cursor.get_inventory(defines.inventory.item_main)

    if not inventory or inventory.get_item_count() == 0 then
      return nil
    end

    cursor = inventory[cursor.active_index]
  end

  return cursor
end

local function swap_blueprint_container_names(player)
  local blueprint = blueprint_in_cursor(player)

  if not blueprint then
    return false
  end

  local entities = blueprint.get_blueprint_entities()

  if not entities then
    return false
  end

  local changed = false

  for _, entity in ipairs(entities) do
    local target_name = blueprint_rotate_targets[entity.name]

    if target_name then
      entity.name = target_name
      changed = true
    end
  end

  if changed then
    blueprint.set_blueprint_entities(entities)
  end

  return changed
end

local function normalize_infinity_blueprint_entities(blueprint)
  if not blueprint or not blueprint.valid_for_read or not blueprint.is_blueprint then
    return false
  end

  local entities = blueprint.get_blueprint_entities()

  if not entities then
    return false
  end

  local changed = false

  for _, entity in ipairs(entities) do
    local target_name = infinity_to_normal[entity.name]

    if target_name then
      entity.name = target_name
      changed = true
    end
  end

  if changed then
    blueprint.set_blueprint_entities(entities)
  end

  return changed
end

local function blueprint_from_setup_event(event)
  if event.stack and event.stack.valid_for_read and event.stack.is_blueprint then
    return event.stack
  end

  local player = game.get_player(event.player_index)

  if player and player.blueprint_to_setup and player.blueprint_to_setup.valid_for_read and player.blueprint_to_setup.is_blueprint then
    return player.blueprint_to_setup
  end

  return nil
end

local function on_created_entity(event)
  local entity = entity_from_event(event)

  if not entity or not entity.valid then
    return
  end

  if replace_placeable_ghost(entity) then
    return
  end

  if replace_hidden_infinity_ghost(entity) then
    return
  end

  replace_placeable(entity)
end

local function on_blueprint_setup(event)
  normalize_infinity_blueprint_entities(blueprint_from_setup_event(event))
end

local function on_rotate_input(event)
  local player = game.get_player(event.player_index)

  if not player then
    return
  end

  if swap_blueprint_container_names(player) then
    return
  end
end

local build_events = {
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}

if defines.events.on_space_platform_built_entity then
  table.insert(build_events, defines.events.on_space_platform_built_entity)
end

script.on_event(build_events, on_created_entity)
script.on_event("train-container-rotate", on_rotate_input)
script.on_event("train-container-reverse-rotate", on_rotate_input)
script.on_event(defines.events.on_player_setup_blueprint, on_blueprint_setup)
script.on_event(defines.events.on_player_configured_blueprint, on_blueprint_setup)
