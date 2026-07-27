local definitions = { 1, 2, 3, 4 }
local variants = { "", "-infinity" }
local placeable_entities = {}
local real_entity_placeables = {}
local real_entity_name_filter = {}
local blueprint_rotate_targets = {}
local train_container_tag = "train-container"

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

    real_entity_placeables[horizontal_name] = {
      name = root_name .. "-placeable",
      direction = defines.direction.east,
    }
    real_entity_placeables[vertical_name] = {
      name = root_name .. "-placeable",
      direction = defines.direction.north,
    }

    table.insert(real_entity_name_filter, horizontal_name)
    table.insert(real_entity_name_filter, vertical_name)

    blueprint_rotate_targets[horizontal_name] = vertical_name
    blueprint_rotate_targets[vertical_name] = horizontal_name
  end
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

  return is_horizontal_direction(entity.direction) and variants.horizontal or variants.vertical
end

local function copy_position(position)
  return {
    x = position.x or position[1],
    y = position.y or position[2],
  }
end

local function copy_tags(tags)
  if not tags then
    return nil
  end

  local copied = {}

  for key, value in pairs(tags) do
    copied[key] = value
  end

  return copied
end

local function merge_tags(first, second)
  local merged = copy_tags(first)

  if second then
    merged = merged or {}

    for key, value in pairs(second) do
      merged[key] = value
    end
  end

  return merged and next(merged) and merged or nil
end

local function copy_infinity_filters(filters)
  if not filters then
    return nil
  end

  local copied = {}

  for _, filter in pairs(filters) do
    if filter and filter.name then
      local copied_filter = {
        name = filter.name,
      }

      if filter.quality then
        copied_filter.quality = filter.quality
      end

      if filter.count then
        copied_filter.count = filter.count
      end

      if filter.mode then
        copied_filter.mode = filter.mode
      end

      if filter.index then
        copied_filter.index = filter.index
      end

      table.insert(copied, copied_filter)
    end
  end

  return next(copied) and copied or nil
end

local function copy_infinity_settings(settings)
  if not settings then
    return nil
  end

  local copied = {}
  local filters = copy_infinity_filters(settings.filters)

  if filters then
    copied.filters = filters
  end

  if settings.remove_unfiltered_items ~= nil then
    copied.remove_unfiltered_items = settings.remove_unfiltered_items and true or false
  end

  return next(copied) and copied or nil
end

local function train_container_tags_from_entity(entity)
  local entity_name = entity.name == "entity-ghost" and entity.ghost_name or entity.name

  if not string.find(entity_name, "-infinity", 1, true) then
    return nil
  end

  local settings = {}
  local ok_filters, filters = pcall(function()
    return entity.infinity_container_filters
  end)

  if ok_filters then
    settings.filters = copy_infinity_filters(filters)
  end

  local ok_remove, remove_unfiltered_items = pcall(function()
    return entity.remove_unfiltered_items
  end)

  if ok_remove then
    settings.remove_unfiltered_items = remove_unfiltered_items and true or false
  end

  if not next(settings) then
    return nil
  end

  return {
    [train_container_tag] = {
      infinity = settings,
    },
  }
end

local function train_container_tags_from_blueprint_entity(entity)
  local settings = copy_infinity_settings(entity.infinity_settings)

  if not settings then
    return nil
  end

  return {
    [train_container_tag] = {
      infinity = settings,
    },
  }
end

local function tags_from_real_entity(entity)
  local tags = nil

  if entity.name == "entity-ghost" then
    local ok, ghost_tags = pcall(function()
      return entity.tags
    end)

    if ok then
      tags = copy_tags(ghost_tags)
    end
  end

  return merge_tags(tags, train_container_tags_from_entity(entity))
end

local function apply_train_container_tags(entity, tags)
  local train_container_tags = tags and tags[train_container_tag]

  if not train_container_tags or not train_container_tags.infinity then
    return
  end

  if not string.find(entity.name, "-infinity", 1, true) then
    return
  end

  local settings = train_container_tags.infinity

  if settings.filters then
    pcall(function()
      entity.infinity_container_filters = settings.filters
    end)
  end

  if settings.remove_unfiltered_items ~= nil then
    pcall(function()
      entity.remove_unfiltered_items = settings.remove_unfiltered_items
    end)
  end
end

local function replace_placeable(entity, tags)
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

    return
  end

  apply_train_container_tags(created, tags)
end

local function replace_real_container_ghost(entity)
  if entity.name ~= "entity-ghost" then
    return false
  end

  local target = real_entity_placeables[entity.ghost_name]

  if not target then
    return false
  end

  local surface = entity.surface
  local position = entity.position
  local force = entity.force
  local quality = quality_name(entity)
  local tags = tags_from_real_entity(entity)

  entity.destroy()

  local ghost = surface.create_entity({
    name = "entity-ghost",
    inner_name = target.name,
    position = position,
    direction = target.direction,
    force = force,
    quality = quality,
    create_build_effect_smoke = false,
  })

  if ghost and tags then
    pcall(function()
      ghost.tags = tags
    end)
  end

  return true
end

local function active_blueprint_from_stack(stack)
  if not stack or not stack.valid_for_read then
    return nil
  end

  if stack.is_blueprint then
    return stack
  end

  if not stack.is_blueprint_book or not stack.active_index then
    return nil
  end

  local inventory = stack.get_inventory(defines.inventory.item_main)

  if not inventory or inventory.get_item_count() == 0 then
    return nil
  end

  local active = inventory[stack.active_index]

  if active and active.valid_for_read and active.is_blueprint then
    return active
  end

  return nil
end

local function blueprint_in_cursor(player)
  if not player.is_cursor_blueprint() then
    return nil
  end

  return active_blueprint_from_stack(player.cursor_stack)
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

local function get_blueprint_entities(blueprint)
  if not blueprint then
    return nil
  end

  local ok, entities = pcall(function()
    return blueprint.get_blueprint_entities()
  end)

  if not ok then
    return nil
  end

  return entities or {}
end

local function set_blueprint_entities(blueprint, entities)
  local ok = pcall(function()
    blueprint.set_blueprint_entities(entities)
  end)

  return ok
end

local function set_blueprint_tags(blueprint, entity_number, tags)
  if not tags then
    return
  end

  pcall(function()
    blueprint.set_blueprint_entity_tags(entity_number, tags)
  end)
end

local function blueprint_from_setup_event(event)
  local blueprint = active_blueprint_from_stack(event.stack)

  if blueprint then
    return blueprint
  end

  if event.record then
    local ok, record_type = pcall(function()
      return event.record.type
    end)

    if ok and record_type == "blueprint" then
      return event.record
    end
  end

  local player = game.get_player(event.player_index)

  if player then
    blueprint = active_blueprint_from_stack(player.blueprint_to_setup)

    if blueprint then
      return blueprint
    end
  end

  return nil
end

local function blueprint_mapping_from_event(event)
  if not event or not event.mapping then
    return nil
  end

  local ok, mapping = pcall(function()
    return event.mapping.get()
  end)

  return ok and mapping or nil
end

local function entity_source_key(entity)
  if not entity or not entity.valid then
    return nil
  end

  if entity.unit_number then
    return "unit:" .. entity.unit_number
  end

  local position = copy_position(entity.position)

  return entity.name .. ":" .. math.floor(position.x * 256 + 0.5) .. ":" .. math.floor(position.y * 256 + 0.5)
end

local function blueprint_entry_key(entity)
  local position = copy_position(entity.position)
  local direction = entity.direction or defines.direction.north

  return entity.name .. ":" .. direction .. ":" .. math.floor(position.x * 256 + 0.5) .. ":" .. math.floor(position.y * 256 + 0.5)
end

local function blueprint_entity_by_number(entities)
  local by_number = {}

  for index, entity in ipairs(entities) do
    by_number[entity.entity_number or index] = entity
  end

  return by_number
end

local function source_from_mapping(mapping, entity, index)
  if not mapping then
    return nil
  end

  return mapping[entity.entity_number or index] or mapping[index]
end

local function blueprint_offset_from_mapping(mapping, entities)
  if not mapping then
    return nil
  end

  local by_number = blueprint_entity_by_number(entities)

  for entity_number, source in pairs(mapping) do
    local entity = by_number[entity_number]

    if entity and entity.position and source and source.valid then
      local blueprint_position = copy_position(entity.position)
      local source_position = copy_position(source.position)

      return {
        x = blueprint_position.x - source_position.x,
        y = blueprint_position.y - source_position.y,
      }
    end
  end

  return nil
end

local function area_left_top(area)
  if not area then
    return nil
  end

  local left_top = area.left_top or area[1]

  if not left_top then
    return nil
  end

  return copy_position(left_top)
end

local function blueprint_position_for_source(source, event, offset)
  local position = copy_position(source.position)

  if offset then
    return {
      x = position.x + offset.x,
      y = position.y + offset.y,
    }
  end

  local left_top = area_left_top(event and event.area)

  if not left_top then
    return position
  end

  return {
    x = position.x - left_top.x,
    y = position.y - left_top.y,
  }
end

local function collect_selected_real_entities(event)
  if not event or not event.surface or not event.area then
    return {}
  end

  local ok, entities = pcall(function()
    return event.surface.find_entities_filtered({
      area = event.area,
      name = real_entity_name_filter,
    })
  end)

  if not ok or not entities then
    return {}
  end

  local selected = {}
  local seen = {}

  for _, entity in ipairs(entities) do
    if entity.valid and real_entity_placeables[entity.name] then
      local key = entity_source_key(entity)

      if key and not seen[key] then
        seen[key] = true
        table.insert(selected, entity)
      end
    end
  end

  return selected
end

local function mark_mapped_real_entities(mapping, entities)
  local represented = {}

  if not mapping then
    return represented
  end

  for index, entity in ipairs(entities) do
    local source = source_from_mapping(mapping, entity, index)

    if source and source.valid and real_entity_placeables[source.name] then
      local key = entity_source_key(source)

      if key then
        represented[key] = true
      end
    end
  end

  return represented
end

local function replace_blueprint_real_entities(event, blueprint)
  local entities = get_blueprint_entities(blueprint)

  if not entities then
    return false
  end

  local mapping = blueprint_mapping_from_event(event)
  local represented_sources = mark_mapped_real_entities(mapping, entities)
  local tags_to_set = {}
  local changed = false
  local max_entity_number = 0

  for index, entity in ipairs(entities) do
    max_entity_number = math.max(max_entity_number, entity.entity_number or index)

    local target = real_entity_placeables[entity.name]

    if target then
      local tags = merge_tags(entity.tags, train_container_tags_from_blueprint_entity(entity))
      local rewritten = {
        entity_number = entity.entity_number or index,
        name = target.name,
        position = entity.position,
        direction = target.direction,
        quality = entity.quality,
        tags = tags,
        wires = entity.wires,
      }

      entities[index] = rewritten

      if tags then
        table.insert(tags_to_set, { entity_number = rewritten.entity_number, tags = tags })
      end

      changed = true
    end
  end

  local existing_entries = {}

  for _, entity in ipairs(entities) do
    existing_entries[blueprint_entry_key(entity)] = true
  end

  local offset = blueprint_offset_from_mapping(mapping, entities)

  for _, source in ipairs(collect_selected_real_entities(event)) do
    local source_key = entity_source_key(source)
    local target = real_entity_placeables[source.name]

    if source_key and target and not represented_sources[source_key] then
      local entry = {
        name = target.name,
        position = blueprint_position_for_source(source, event, offset),
        direction = target.direction,
      }
      local entry_key = blueprint_entry_key(entry)

      if not existing_entries[entry_key] then
        max_entity_number = max_entity_number + 1
        entry.entity_number = max_entity_number

        local quality = quality_name(source)

        if quality ~= "normal" then
          entry.quality = quality
        end

        local tags = tags_from_real_entity(source)

        if tags then
          entry.tags = tags
          table.insert(tags_to_set, { entity_number = entry.entity_number, tags = tags })
        end

        table.insert(entities, entry)
        existing_entries[entry_key] = true
        represented_sources[source_key] = true
        changed = true
      end
    end
  end

  if changed and set_blueprint_entities(blueprint, entities) then
    for _, tagged in ipairs(tags_to_set) do
      set_blueprint_tags(blueprint, tagged.entity_number, tagged.tags)
    end
  end

  return changed
end

local function on_created_entity(event)
  local entity = entity_from_event(event)

  if not entity or not entity.valid then
    return
  end

  if replace_real_container_ghost(entity) then
    return
  end

  replace_placeable(entity, event.tags)
end

local function on_blueprint_setup(event)
  replace_blueprint_real_entities(event, blueprint_from_setup_event(event))
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
