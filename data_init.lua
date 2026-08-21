local create_sprite = require('scripts.sprite_generation')

local function copy(value)
	return value and table.deepcopy(value) or nil
end

--- @param chest_name string
--- @param width number
--- @param height number
local function get_circuit_connector(chest_name, width, height)
	local mod_settings = MergingChests.get_mod_settings(chest_name)
	local variation, x, y
	local _, _, side, position = string.find(mod_settings.circuit_connector_position, '([^-]+)[-]([^-]+)')

	if side == 'right' then
		variation = 24
		x = -width / 2
	elseif side == 'left' then
		variation = 28
		x = width / 2
	elseif side == 'bottom' then
		variation = 26
		y = height / 2 - 0.5
	elseif side == 'center' then
		if width >= height then
			variation = 26
			x = 0
			y = height / 2 - 0.5
		else
			variation = 24
			x = -width / 2
			y = 0
		end
	end

	if position == 'top' then
		y = -height / 2 + 0.5
	elseif position == 'middle' then
		if x == nil then
			x = 0
		else
			y = 0
		end
	elseif position == 'bottom' then
		y = height / 2 - 0.75
	elseif position == 'right' then
		x = -width / 2 + 0.5
	elseif position == 'left' then
		x = width / 2 - 0.5
	end

	return circuit_connector_definitions.create_vector(
		universal_connector_template,
		{{
			variation = variation,
			main_offset = { x, y },
			shadow_offset = { x + 0.1, y + 0.1 },
			show_shadow = false
		}}
	)
end

--- @alias entity_data
--- | { chest_name: string, override_prototype_properties?: table }

--- @param entity_data entity_data
--- @param loc_name table
--- @param subgroup string
--- @param width number
--- @param height number
--- @param segment_data entity_sprite
local function create_entity(entity_data, loc_name, subgroup, width, height, segment_data)
	local base_entity_name = entity_data.base_entity_name or entity_data.chest_name
	local prototype_type = entity_data.prototype_type
	local base_chest = prototype_type == 'infinity-container'
		and data.raw['infinity-container'][base_entity_name]
		or data.raw['logistic-container'][base_entity_name] or data.raw.container[base_entity_name]

	if base_chest == nil then
		error('Chest with name '..base_entity_name..' not found')
	end

	local sprite = create_sprite(width, height, segment_data)
	local connector = get_circuit_connector(entity_data.chest_name, width, height)

	local type_specific_properties
	if prototype_type == 'infinity-container' then
		type_specific_properties = {
			type = 'infinity-container',
			gui_mode = base_chest.gui_mode or 'all',
			erase_contents_when_mined = true,
			preserve_contents_when_created = true,
			infinity_settings = copy(base_chest.infinity_settings),
			picture = {
				layers = sprite
			}
		}
	elseif base_chest.logistic_mode then
		type_specific_properties = {
			type = 'logistic-container',
			logistic_mode = base_chest.logistic_mode,
			animation_sound = base_chest.animation_sound,
			trash_inventory_size = base_chest.trash_inventory_size,
			opened_duration = 7,
			animation = {
				layers = sprite
			}
		}

		if base_chest.logistic_mode == 'storage' then
			type_specific_properties.max_logistic_slots = 1
		end
	else
		type_specific_properties = {
			type = 'container',
			picture = {
				layers = sprite
			}
		}
	end

	local merged_chest_name = MergingChests.get_merged_chest_name(entity_data.chest_name, width, height)

	table.insert(data.raw['selection-tool'][MergingChests.merge_selection_tool_name].alt_select.entity_filters, merged_chest_name)
	table.insert(data.raw['selection-tool'][MergingChests.merge_selection_tool_name].select.entity_filters, merged_chest_name)

	local minable = entity_data.minable
	if type(minable) == 'function' then
		minable = minable(width, height)
	end
	minable = minable or { mining_time = 2, result = entity_data.chest_name, count = width * height }

	local placeable_by = entity_data.placeable_by
	if type(placeable_by) == 'function' then
		placeable_by = placeable_by(width, height)
	end
	placeable_by = placeable_by or { item = entity_data.placeable_by_item or entity_data.chest_name, count = width * height }

	local inventory_size = entity_data.inventory_size
	if type(inventory_size) == 'function' then
		inventory_size = inventory_size(base_chest, width, height)
	end
	inventory_size = inventory_size or MergingChests.get_inventory_size(base_chest.inventory_size or 48, width * height, entity_data.chest_name)

	return util.merge({
		type_specific_properties,
		{
			name = merged_chest_name,
			localised_name = loc_name,
			icon = base_chest.icon,
			icons = base_chest.icons,
			icon_size = base_chest.icon_size,
			open_sound = base_chest.open_sound,
			close_sound = base_chest.close_sound,
			max_health = base_chest.max_health * math.min(width * height, 10),
			inventory_size = inventory_size,
			inventory_type = prototype_type ~= 'infinity-container' and 'normal' or nil,
			flags = { 'placeable-player', 'player-creation' },
			minable = minable,
			placeable_by = placeable_by,
			corpse = 'medium-remnants',
			dying_explosion = 'medium-explosion',
			vehicle_impact_sound = { filename = '__base__/sound/car-metal-impact.ogg', volume = 0.65 },
			collision_box = { { -width / 2 + 0.15, -height / 2 + 0.15 }, { width / 2 - 0.15, height / 2 - 0.15 } },
			selection_box = { { -width / 2, -height / 2 }, { width / 2, height / 2 } },
			subgroup = entity_data.subgroup or subgroup,
			circuit_connector = connector,
			circuit_wire_max_distance = default_circuit_wire_max_distance + math.min(width, height) - 1,
			hidden = entity_data.hidden,
			hidden_in_factoriopedia = true,
			surface_conditions = base_chest.surface_conditions
		},
		entity_data.override_prototype_properties or {}
	})
end

--- @param entity_data entity_data
--- @param segment_data entity_sprite
--- @param width number
local function create_wide_chest_entity(entity_data, segment_data, width)
	local loc_name = entity_data.localised_name and entity_data.localised_name(width, 1)
		or { 'chest-name.'..MergingChests.prefix_with_modname('wide-'..entity_data.chest_name), ''..width }

	return create_entity(
		entity_data,
		loc_name,
		MergingChests.item_group_names.wide_chests,
		width,
		1,
		segment_data
	)
end

--- @param entity_data entity_data
--- @param segment_data entity_sprite
--- @param height number
local function create_high_chest_entity(entity_data, segment_data, height)
	local loc_name = entity_data.localised_name and entity_data.localised_name(1, height)
		or { 'chest-name.'..MergingChests.prefix_with_modname('high-'..entity_data.chest_name), ''..height }

	return create_entity(
		entity_data,
		loc_name,
		MergingChests.item_group_names.high_chests,
		1,
		height,
		segment_data
	)
end

--- @param entity_data entity_data
--- @param segment_data entity_sprite
--- @param width number
--- @param height number
local function create_warehouse_entity(entity_data, segment_data, width, height)
	return create_entity(
		entity_data,
		{ 'chest-name.'..MergingChests.prefix_with_modname(entity_data.chest_name..'-warehouse'), ''..width, ''..height },
		MergingChests.item_group_names.warehouses,
		width,
		height,
		segment_data
	)
end

--- @param entity_data entity_data
--- @param segment_data entity_sprite
--- @param width number
--- @param height number
local function create_trashdump_entity(entity_data, segment_data, width, height)
	return create_entity(
		entity_data,
		{ 'chest-name.'..MergingChests.prefix_with_modname(entity_data.chest_name..'-trashdump'), ''..width, ''..height },
		MergingChests.item_group_names.trashdumps,
		width,
		height,
		segment_data
	)
end

--- Creates merged chest prototypes
---
--- @param entity_data entity_data
--- @param segments_data segments_data
function MergingChests.create_mergeable_chest(entity_data, segments_data)
	local mod_settings = MergingChests.get_mod_settings(entity_data.chest_name)
	local max_item_count = 0

	if segments_data.high_segments then
		for height = 2, mod_settings.max_length do
			if MergingChests.is_size_allowed(1, height, entity_data.chest_name) then
				data:extend({ create_high_chest_entity(entity_data, segments_data.high_segments, height) })
				max_item_count = math.max(max_item_count, height)
			end
		end
	end

	for width = 2, mod_settings.max_length do
		if segments_data.wide_segments then
			if MergingChests.is_size_allowed(width, 1, entity_data.chest_name) then
				data:extend({ create_wide_chest_entity(entity_data, segments_data.wide_segments, width) })
				max_item_count = math.max(max_item_count, width)
			end
		end
	end

	if entity_data.skip_selection_filter then
		return
	end

	table.insert(data.raw['selection-tool'][MergingChests.merge_selection_tool_name].select.entity_filters, entity_data.chest_name)
	if data.raw.item[entity_data.chest_name] then
		data.raw.item[entity_data.chest_name].stack_size = math.max(data.raw.item[entity_data.chest_name].stack_size, max_item_count)
	end
end
