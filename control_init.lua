--- @alias chest_merged_event { player_index: number, surface: LuaSurface, split_chests: LuaEntity[], merged_chest: LuaEntity }

--- @param entity LuaEntity
--- @return integer
local function non_blank_inventory_slots_count(entity)
	local count = 0
	local inventory = entity.get_inventory(defines.inventory.chest)
	if inventory then
		for i = 1, #inventory do
			if inventory[i].valid_for_read then
				count = count + 1
			end
		end
	end

	return count
end

--- @param from_entities LuaEntity[]
--- @param to_entity_name string
--- @param to_entity_count integer
--- @return boolean
function MergingChests.can_move_inventories(from_entities, to_entity_name, to_entity_count)
	local from_item_count = 0
	for _, from_entity in ipairs(from_entities) do
		from_item_count = from_item_count + non_blank_inventory_slots_count(from_entity)
	end
	local quality = MergingChests.get_minimum_quality(from_entities)

	local to_inventory_size = prototypes.entity[to_entity_name].get_inventory_size(defines.inventory.chest, quality) or 0

	local split_chest_name, _, _ = MergingChests.get_merged_chest_info(to_entity_name)

	if split_chest_name then
		return from_item_count <= to_inventory_size
	end

	return from_item_count <= to_inventory_size * to_entity_count
end

--- @param from_entities LuaEntity[]
--- @param to_entities LuaEntity[]
--- @return boolean
function MergingChests.move_inventories(from_entities, to_entities)
	local to_entity_index = 1
	local to_inventory_index = 1
	local moved_count = 0
	local source_count = 0

	for _, from_entity in ipairs(from_entities) do
		local from_inventory = from_entity.get_inventory(defines.inventory.chest)
		if from_inventory then
			for i = 1, #from_inventory do
				local item = from_inventory[i]
				if item.valid_for_read then
					source_count = source_count + 1
					local to_inventory = to_entities[to_entity_index].get_inventory(defines.inventory.chest)
					while to_inventory and to_inventory_index <= #to_inventory and to_inventory[to_inventory_index].valid_for_read do
						to_inventory_index = to_inventory_index + 1
					end
					while to_inventory and to_inventory_index > #to_inventory do
						to_entity_index = to_entity_index + 1
						if to_entity_index > table_size(to_entities) then
							return false
						end
						to_inventory = to_entities[to_entity_index].get_inventory(defines.inventory.chest)
						to_inventory_index = 1
					end
					if to_inventory and to_inventory[to_inventory_index].set_stack(item) then
						moved_count = moved_count + 1
						to_inventory_index = to_inventory_index + 1
					else
						return false
					end
				end
			end
		end
	end

	return moved_count == source_count
end

---@param entity LuaEntity
---@param blueprint_entities BlueprintEntity[]
---@return integer | nil
local function get_blueprint_entities_bar(entity, blueprint_entities)
	for _, blueprint_entity in ipairs(blueprint_entities) do
		if entity.ghost_name == blueprint_entity.name and math.abs(entity.position.x - blueprint_entity.position.x) < 1e-6 and math.abs(entity.position.y - blueprint_entity.position.y) < 1e-6 then
			return blueprint_entity.bar
		end
	end
	return nil
end

---@param entity LuaEntity
---@return integer | nil
local function get_ghost_bar(entity)
	local inventory = game.create_inventory(1)
	inventory.insert({name = "blueprint"})
	inventory[1].create_blueprint{
	  surface = entity.surface,
	  force = entity.force,
	  area = {
		{ entity.position.x - 0.01, entity.position.y - 0.01 },
		{ entity.position.x + 0.01, entity.position.y + 0.01 }
	  }
	}

	local blueprint_entities = inventory[1].get_blueprint_entities() or {}
	local bar = get_blueprint_entities_bar(entity, blueprint_entities)

	inventory.destroy()
	return bar
end

---@param entity LuaEntity
---@return integer | nil
local function get_entity_bar(entity)
	local inventory = entity.get_inventory(defines.inventory.chest)
	if inventory and inventory.supports_bar() then
		return inventory.get_bar() - 1
	end
	return nil
end

--- @param entities LuaEntity[]
--- @param is_ghost boolean
--- @return integer
function MergingChests.get_total_bar(entities, is_ghost)
	local bar_count = 0
	for _, entity in ipairs(entities) do
		local bar = (is_ghost and entity.ghost_prototype or entity.prototype).get_inventory_size(defines.inventory.chest, entity.quality) or 0
		if is_ghost then
			bar = get_ghost_bar(entity) or bar
		else
			bar = get_entity_bar(entity) or bar
		end
		bar_count = bar_count + bar
	end

	return bar_count
end

--- @param entities LuaEntity[]
--- @return LuaQualityPrototype
function MergingChests.get_minimum_quality(entities)
	local min_quality = nil
	for _, entity in ipairs(entities) do
		if min_quality == nil or min_quality.level > entity.quality.level then
			min_quality = entity.quality
		end
	end

	return min_quality or prototypes.quality['normal']
end

--- @param from_entities LuaEntity[]
--- @param to_entities LuaEntity[]
--- @param require_all_sources_per_color boolean | nil
--- @param connect_all_targets boolean | nil
function MergingChests.reconnect_circuits(from_entities, to_entities, require_all_sources_per_color, connect_all_targets)
	local from_entities_set = { }
	for _, from_entity in ipairs(from_entities) do
		from_entities_set[from_entity] = from_entity
	end

	local outside_connectors = { }
	local source_has_color = { }
	for _, from_entity in ipairs(from_entities) do
		source_has_color[from_entity] = { }
		for _, connector in pairs(from_entity.get_wire_connectors(false)) do
			for _, connection in ipairs(connector.connections) do
				source_has_color[from_entity][connector.wire_connector_id] = true
				if not from_entities_set[connection.target.owner] then
					outside_connectors[connector.wire_connector_id] = outside_connectors[connector.wire_connector_id] or {}
					local owner = connection.target.owner
					local owner_key = owner.unit_number or (owner.name..'/'..owner.position.x..'/'..owner.position.y)
					outside_connectors[connector.wire_connector_id][owner_key..'/'..connection.target.wire_connector_id] = connection.target
				end
			end
		end
	end

	if require_all_sources_per_color then
		for wire_connector_id, _ in pairs(outside_connectors) do
			for _, from_entity in ipairs(from_entities) do
				if not source_has_color[from_entity][wire_connector_id] then
					outside_connectors[wire_connector_id] = nil
					break
				end
			end
		end
	end

	if next(outside_connectors) ~= nil then
		for wire_connector_id, connectors in pairs(outside_connectors) do
			for _, connector in pairs(connectors) do
				if connect_all_targets then
					for _, to_entity in ipairs(to_entities) do
						to_entity.get_wire_connector(wire_connector_id, true).connect_to(connector, false)
					end
				else
					local closest_entity = nil
					local min = nil

					for _, to_entity in ipairs(to_entities) do
						local diffX = to_entity.position.x - connector.owner.position.x
						local diffY = to_entity.position.y - connector.owner.position.y

						if not min or (diffX * diffX + diffY * diffY < min) then
							min = diffX * diffX + diffY * diffY
							closest_entity = to_entity
						end
					end

					if closest_entity then
						closest_entity.get_wire_connector(wire_connector_id, true).connect_to(connector, false)
					end
				end
			end
		end
	end
end

--- @param player LuaPlayer
--- @param item_name string
--- @param quality LuaQualityPrototype
--- @return integer
function MergingChests.get_player_item_count(player, item_name, quality)
	local inventory = player.get_main_inventory()
	if inventory == nil then
		return 0
	end

	local counts = inventory.get_item_quality_counts(item_name)
	return counts[quality.name] or 0
end

--- @param player LuaPlayer
--- @param item_name string
--- @param count integer
--- @param quality LuaQualityPrototype
--- @return boolean
function MergingChests.remove_player_items(player, item_name, count, quality)
	local inventory = player.get_main_inventory()
	if inventory == nil then
		return false
	end

	return inventory.remove({ name = item_name, count = count, quality = quality.name }) == count
end

--- @param player LuaPlayer
--- @param item_name string
--- @param count integer
--- @param quality LuaQualityPrototype
function MergingChests.refund_player_items(player, item_name, count, quality)
	local inventory = player.get_main_inventory()
	if inventory then
		inventory.insert({ name = item_name, count = count, quality = quality.name })
	end
end

function MergingChests.get_merge_target_chest_name(source_chest_name)
	if source_chest_name == 'infinity-chest' then
		return MergingChests.chest_names.infinity
	end

	return source_chest_name
end

MergingChests.on_chest_merged_event_name = script.generate_event_name()
MergingChests.on_chest_split_event_name = script.generate_event_name()

local function get_chest_merged_event_name()
	return MergingChests.on_chest_merged_event_name
end

local function get_chest_split_event_name()
	return MergingChests.on_chest_split_event_name
end

remote.add_interface('TrainContainer', {
	get_chest_merged_event_name = get_chest_merged_event_name,
	get_chest_split_event_name = get_chest_split_event_name
})
