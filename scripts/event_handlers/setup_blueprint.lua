local function get_blueprint_entities(blueprint)
	if blueprint == nil then
		return nil
	end

	local ok, entities = pcall(function()
		return blueprint.get_blueprint_entities()
	end)
	if ok and entities ~= nil then
		return entities
	end

	return nil
end

local function get_blueprint(event)
	local player = game.players[event.player_index]

	local function try_blueprint(blueprint)
		if blueprint then
			local entities = get_blueprint_entities(blueprint)
			if entities ~= nil then
				return blueprint, entities
			end
		end
	end

	local blueprint, entities = try_blueprint(event.stack)
	if blueprint then
		return blueprint, entities
	end

	blueprint, entities = try_blueprint(player and player.cursor_stack)
	if blueprint then
		return blueprint, entities
	end

	blueprint, entities = try_blueprint(player and player.blueprint_to_setup)
	if blueprint then
		return blueprint, entities
	end

	blueprint, entities = try_blueprint(event.record)
	if blueprint then
		return blueprint, entities
	end

	return nil, nil
end

local function is_normal_train_container(entity)
	local split_chest_name, width, height = MergingChests.get_merged_chest_info(entity.name)
	if split_chest_name ~= MergingChests.chest_names.steel or width == nil or height == nil then
		return false
	end

	return true, width, height
end

local function copy_position(position)
	return { x = position.x, y = position.y }
end

local function create_split_blueprint_entities(entity, width, height)
	local left_top = {
		x = entity.position.x - (width - 1) / 2,
		y = entity.position.y - (height - 1) / 2
	}

	local total_bar = entity.bar
	local bar_per_chest = total_bar and math.ceil(total_bar / width / height) or nil
	local split_entities = {}
	for dX = 0, width - 1 do
		for dY = 0, height - 1 do
			local split_entity = {
				name = MergingChests.chest_names.steel,
				position = { x = left_top.x + dX, y = left_top.y + dY },
				quality = entity.quality
			}

			if total_bar and bar_per_chest then
				split_entity.bar = math.min(bar_per_chest, total_bar)
				total_bar = total_bar - split_entity.bar
			end

			table.insert(split_entities, split_entity)
		end
	end

	return split_entities
end

local function copy_blueprint_entity(entity)
	local copy = table.deepcopy(entity)
	copy.position = copy_position(entity.position)
	copy.wires = nil
	return copy
end

local function add_wire(all_wires, wire)
	local source_entity_number = wire[1]
	local source_connector_id = wire[2]
	local target_entity_number = wire[3]
	local target_connector_id = wire[4]

	if target_entity_number < source_entity_number then
		source_entity_number, target_entity_number = target_entity_number, source_entity_number
		source_connector_id, target_connector_id = target_connector_id, source_connector_id
	end

	local key = source_entity_number..'/'..source_connector_id..'/'..target_entity_number..'/'..target_connector_id
	if all_wires[key] == nil then
		all_wires[key] = {
			source_entity_number,
			source_connector_id,
			target_entity_number,
			target_connector_id
		}
	end
end

local function collect_original_wires(entities)
	local wires = {}
	for _, entity in ipairs(entities) do
		for _, wire in ipairs(entity.wires or {}) do
			add_wire(wires, wire)
		end
	end
	return wires
end

local function sorted_keys(table_to_sort)
	local keys = {}
	for key, _ in pairs(table_to_sort) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function rebuild_wires(original_wires, entity_number_mapping, entities_by_number)
	local rebuilt_wires = {}
	for _, key in ipairs(sorted_keys(original_wires)) do
		local wire = original_wires[key]
		local source_entities = entity_number_mapping[wire[1]]
		local target_entities = entity_number_mapping[wire[3]]
		if source_entities and target_entities then
			for _, source_entity_number in ipairs(source_entities) do
				for _, target_entity_number in ipairs(target_entities) do
					if source_entity_number ~= target_entity_number then
						add_wire(rebuilt_wires, {
							source_entity_number,
							wire[2],
							target_entity_number,
							wire[4]
						})
					end
				end
			end
		end
	end

	for _, key in ipairs(sorted_keys(rebuilt_wires)) do
		local wire = rebuilt_wires[key]
		local source_entity = entities_by_number[wire[1]]
		if source_entity then
			source_entity.wires = source_entity.wires or {}
			table.insert(source_entity.wires, wire)
		end
	end
end

local function replace_train_containers(entities)
	local changed = false
	local new_entities = {}
	local entities_by_number = {}
	local entity_number_mapping = {}
	local next_entity_number = 1

	for _, entity in ipairs(entities) do
		next_entity_number = math.max(next_entity_number, entity.entity_number + 1)
	end

	for _, entity in ipairs(entities) do
		local should_replace, width, height = is_normal_train_container(entity)
		local replacement_entities = should_replace
			and create_split_blueprint_entities(entity, width, height)
			or { copy_blueprint_entity(entity) }

		entity_number_mapping[entity.entity_number] = {}
		for index, replacement_entity in ipairs(replacement_entities) do
			if index == 1 then
				replacement_entity.entity_number = entity.entity_number
			else
				replacement_entity.entity_number = next_entity_number
				next_entity_number = next_entity_number + 1
			end

			table.insert(entity_number_mapping[entity.entity_number], replacement_entity.entity_number)
			table.insert(new_entities, replacement_entity)
			entities_by_number[replacement_entity.entity_number] = replacement_entity
		end

		changed = changed or should_replace
	end

	if not changed then
		return nil
	end

	rebuild_wires(collect_original_wires(entities), entity_number_mapping, entities_by_number)

	return new_entities
end

local function on_player_setup_blueprint(event)
	local blueprint, entities = get_blueprint(event)
	if blueprint == nil then
		return
	end

	local new_entities = replace_train_containers(entities)
	if new_entities ~= nil then
		blueprint.set_blueprint_entities(new_entities)
	end
end

script.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)
