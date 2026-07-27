local base_chest = data.raw.container["steel-chest"]

if not base_chest then
  error("Train Container requires the base steel-chest prototype.")
end

local function train_container_length(wagons)
  return 6 * wagons + (wagons - 1)
end

local definitions = {
  { wagons = 1, length = train_container_length(1), inventory_size = 96 },
  { wagons = 2, length = train_container_length(2), inventory_size = 192 },
  { wagons = 3, length = train_container_length(3), inventory_size = 288 },
  { wagons = 4, length = train_container_length(4), inventory_size = 384 },
}

local entity_graphics_path = "__TrainContainer__/graphics/entity/train-container"

local horizontal_segments = {
  entity = {
    filename = entity_graphics_path .. "/wide-chest/wide-chest.png",
    scale = 0.5,
    shift = { x = -0.25, y = -4.5 },
    left = { x = 0, y = 0, width = 64, height = 80 },
    middle = { x = 32, y = 0, width = 64, height = 80 },
    right = { x = 64, y = 0, width = 64, height = 80 },
  },
  shadow = {
    filename = entity_graphics_path .. "/wide-chest/wide-chest-shadow.png",
    scale = 0.5,
    shift = { x = 0.75, y = 12.5 },
    draw_as_shadow = true,
    right = { x = 60, y = 0, width = 50, height = 46, shift = { x = 30, y = 0 } },
  },
}

local vertical_segments = {
  entity = {
    filename = entity_graphics_path .. "/high-chest/high-chest.png",
    scale = 0.5,
    shift = { x = -0.25, y = -9.5 },
    top = { x = 0, y = 0, width = 64, height = 54, shift = { x = 0, y = 5 } },
    middle = { x = 0, y = 22, width = 64, height = 64 },
    bottom = { x = 0, y = 54, width = 64, height = 90 },
  },
  shadow = {
    filename = entity_graphics_path .. "/high-chest/high-chest-shadow.png",
    scale = 0.5,
    shift = { x = 0.75, y = 6 },
    draw_as_shadow = true,
    top = { x = 0, y = 0, width = 110, height = 55, shift = { x = 0, y = 6.5 } },
    middle = { x = 0, y = 18, width = 110, height = 64 },
    bottom = { x = 0, y = 45, width = 110, height = 55 },
  },
}

local function copy(value)
  return value and table.deepcopy(value) or nil
end

local function prototype_names(definition, is_infinity)
  local base_name = "train-container-" .. definition.wagons
  local root_name = is_infinity and (base_name .. "-infinity") or base_name

  return {
    base = base_name,
    root = root_name,
    horizontal = root_name,
    vertical = root_name .. "-vertical",
    placeable = root_name .. "-placeable",
  }
end

local function icon_reference(is_infinity)
  if is_infinity and data.raw.item["infinity-chest"] then
    return data.raw.item["infinity-chest"]
  end

  if data.raw.item["steel-chest"] then
    return data.raw.item["steel-chest"]
  end

  return base_chest
end

local function tile_layer(segment_set, segment, tile_x, tile_y)
  local segment_shift = segment.shift or {}
  local set_shift = segment_set.shift or { x = 0, y = 0 }
  local scale = segment.scale or segment_set.scale or 1

  return {
    filename = segment.filename or segment_set.filename,
    priority = "medium",
    x = segment.x or 0,
    y = segment.y or 0,
    width = segment.width,
    height = segment.height,
    shift = {
      tile_x + ((segment.width / 2) * scale + (segment_shift.x or 0) + (set_shift.x or 0)) / 32,
      tile_y + ((segment.height / 2) * scale + (segment_shift.y or 0) + (set_shift.y or 0)) / 32,
    },
    scale = scale,
    draw_as_shadow = segment_set.draw_as_shadow or false,
  }
end

local function horizontal_layers(length)
  local layers = {}
  local first_tile_x = -length / 2

  table.insert(layers, tile_layer(horizontal_segments.entity, horizontal_segments.entity.left, first_tile_x, -0.5))

  for tile = 1, length - 2 do
    table.insert(layers, tile_layer(horizontal_segments.entity, horizontal_segments.entity.middle, first_tile_x + tile, -0.5))
  end

  table.insert(layers, tile_layer(horizontal_segments.entity, horizontal_segments.entity.right, length / 2 - 1, -0.5))
  table.insert(layers, tile_layer(horizontal_segments.shadow, horizontal_segments.shadow.right, length / 2 - 1, -0.5))

  return layers
end

local function vertical_layers(length)
  local layers = {}
  local first_tile_y = -length / 2

  table.insert(layers, tile_layer(vertical_segments.entity, vertical_segments.entity.top, -0.5, first_tile_y))

  for tile = 1, length - 2 do
    table.insert(layers, tile_layer(vertical_segments.entity, vertical_segments.entity.middle, -0.5, first_tile_y + tile))
  end

  table.insert(layers, tile_layer(vertical_segments.entity, vertical_segments.entity.bottom, -0.5, length / 2 - 1))
  table.insert(layers, tile_layer(vertical_segments.shadow, vertical_segments.shadow.top, -0.5, first_tile_y))

  for tile = 1, length - 2 do
    table.insert(layers, tile_layer(vertical_segments.shadow, vertical_segments.shadow.middle, -0.5, first_tile_y + tile))
  end

  table.insert(layers, tile_layer(vertical_segments.shadow, vertical_segments.shadow.bottom, -0.5, length / 2 - 1))

  return layers
end

local function vertical_collision_box(length)
  return {
    { -0.4, -length / 2 + 0.1 },
    { 0.4, length / 2 - 0.1 },
  }
end

local function horizontal_collision_box(length)
  return {
    { -length / 2 + 0.1, -0.4 },
    { length / 2 - 0.1, 0.4 },
  }
end

local function vertical_selection_box(length)
  return {
    { -0.5, -length / 2 },
    { 0.5, length / 2 },
  }
end

local function horizontal_selection_box(length)
  return {
    { -length / 2, -0.5 },
    { length / 2, 0.5 },
  }
end

local function create_container_entity(definition, orientation, is_infinity)
  local names = prototype_names(definition, is_infinity)
  local icon = icon_reference(is_infinity)
  local is_vertical = orientation == "vertical"
  local name = is_vertical and names.vertical or names.horizontal
  local picture = is_vertical and { layers = vertical_layers(definition.length) } or { layers = horizontal_layers(definition.length) }

  return {
    type = is_infinity and "infinity-container" or "container",
    name = name,
    hidden = true,
    hidden_in_factoriopedia = true,
    localised_name = { "entity-name." .. names.root },
    localised_description = { "entity-description." .. names.root },
    icon = icon.icon,
    icons = copy(icon.icons),
    icon_size = icon.icon_size or base_chest.icon_size or 64,
    flags = { "player-creation" },
    minable = { mining_time = 0.5, result = names.root },
    max_health = base_chest.max_health,
    corpse = base_chest.corpse,
    dying_explosion = base_chest.dying_explosion,
    damaged_trigger_effect = copy(base_chest.damaged_trigger_effect),
    open_sound = copy(base_chest.open_sound),
    close_sound = copy(base_chest.close_sound),
    impact_category = base_chest.impact_category,
    inventory_size = definition.inventory_size,
    inventory_type = "normal",
    quality_affects_inventory_size = false,
    collision_box = is_vertical and vertical_collision_box(definition.length) or horizontal_collision_box(definition.length),
    selection_box = is_vertical and vertical_selection_box(definition.length) or horizontal_selection_box(definition.length),
    tile_width = is_vertical and 1 or definition.length,
    tile_height = is_vertical and definition.length or 1,
    picture = picture,
    circuit_connector = copy(base_chest.circuit_connector),
    circuit_wire_max_distance = base_chest.circuit_wire_max_distance,
    gui_mode = is_infinity and "all" or nil,
    erase_contents_when_mined = is_infinity and true or nil,
    preserve_contents_when_created = is_infinity and true or nil,
    subgroup = "storage",
    order = "a[items]-d[train-container-" .. definition.wagons .. (is_infinity and "-infinity]" or "]"),
    surface_conditions = copy(base_chest.surface_conditions),
  }
end

local function create_placeable_entity(definition, is_infinity)
  local names = prototype_names(definition, is_infinity)
  local icon = icon_reference(is_infinity)
  local horizontal = { layers = horizontal_layers(definition.length) }
  local vertical = { layers = vertical_layers(definition.length) }

  return {
    type = "simple-entity-with-owner",
    name = names.placeable,
    hidden = true,
    localised_name = { "entity-name." .. names.root },
    localised_description = { "entity-description." .. names.root },
    icon = icon.icon,
    icons = copy(icon.icons),
    icon_size = icon.icon_size or base_chest.icon_size or 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = names.root },
    placeable_by = { item = names.root, count = 1 },
    max_health = base_chest.max_health,
    corpse = base_chest.corpse,
    dying_explosion = base_chest.dying_explosion,
    collision_box = vertical_collision_box(definition.length),
    selection_box = vertical_selection_box(definition.length),
    tile_width = 1,
    tile_height = definition.length,
    picture = {
      north = vertical,
      east = horizontal,
      south = vertical,
      west = horizontal,
    },
    subgroup = "storage",
    order = "a[items]-d[train-container-" .. definition.wagons .. (is_infinity and "-infinity]" or "]"),
    surface_conditions = copy(base_chest.surface_conditions),
  }
end

local function create_item(definition, is_infinity)
  local names = prototype_names(definition, is_infinity)
  local icon = icon_reference(is_infinity)

  return {
    type = "item",
    name = names.root,
    hidden = is_infinity or nil,
    icon = icon.icon,
    icons = copy(icon.icons),
    icon_size = icon.icon_size or base_chest.icon_size or 64,
    subgroup = is_infinity and "other" or "storage",
    order = is_infinity
      and ("c[item]-o[train-container-infinity]-" .. definition.wagons)
      or ("a[items]-d[train-container-" .. definition.wagons .. "]"),
    place_result = names.placeable,
    stack_size = 10,
    inventory_move_sound = copy(data.raw.item["steel-chest"] and data.raw.item["steel-chest"].inventory_move_sound),
    pick_sound = copy(data.raw.item["steel-chest"] and data.raw.item["steel-chest"].pick_sound),
    drop_sound = copy(data.raw.item["steel-chest"] and data.raw.item["steel-chest"].drop_sound),
  }
end

local function create_recipe(definition)
  local names = prototype_names(definition, false)

  return {
    type = "recipe",
    name = names.root,
    enabled = true,
    ingredients = {
      { type = "item", name = "steel-chest", amount = definition.length },
    },
    results = {
      { type = "item", name = names.root, amount = 1 },
    },
  }
end

local prototypes = {}

for _, definition in ipairs(definitions) do
  table.insert(prototypes, create_container_entity(definition, "horizontal", false))
  table.insert(prototypes, create_container_entity(definition, "vertical", false))
  table.insert(prototypes, create_placeable_entity(definition, false))
  table.insert(prototypes, create_item(definition, false))
  table.insert(prototypes, create_recipe(definition))

  table.insert(prototypes, create_container_entity(definition, "horizontal", true))
  table.insert(prototypes, create_container_entity(definition, "vertical", true))
  table.insert(prototypes, create_placeable_entity(definition, true))
  table.insert(prototypes, create_item(definition, true))
end

table.insert(prototypes, {
  type = "custom-input",
  name = "train-container-rotate",
  key_sequence = "",
  linked_game_control = "rotate",
  consuming = "none",
})

table.insert(prototypes, {
  type = "custom-input",
  name = "train-container-reverse-rotate",
  key_sequence = "",
  linked_game_control = "reverse-rotate",
  consuming = "none",
})

data:extend(prototypes)
