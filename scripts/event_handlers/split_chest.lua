--- @param event chest_merged_event
local function raise_on_chest_split(event)
	script.raise_event(MergingChests.on_chest_split_event_name, event)
end

--- @param merged_chest LuaEntity
--- @param split_chest_name string
--- @param width integer
--- @param height integer
--- @param player LuaPlayer
--- @param is_ghost boolean
--- @param total_bar integer
--- @return LuaEntity[]
local function create_split_chest(merged_chest, split_chest_name, width, height, player, is_ghost, total_bar)
	local left_top = {
		x = merged_chest.position.x - (width - 1) / 2,
		y = merged_chest.position.y - (height - 1) / 2
	}

	local bar_per_chest = math.ceil(total_bar / width / height)
	local split_chests = { }
	for dX = 0, width - 1 do
		for dY = 0, height - 1 do
			local bar = math.min(bar_per_chest, total_bar)
			total_bar = total_bar - bar
			local entity_data = {
				position = { x = left_top.x + dX, y = left_top.y + dY },
				force = player.force,
				raise_built = true,
				bar = bar,
				quality = merged_chest.quality
			}

			if is_ghost then
				entity_data.name = "entity-ghost"
				entity_data.inner_name = split_chest_name
			else
				entity_data.name = split_chest_name
			end
			table.insert(split_chests, merged_chest.surface.create_entity(entity_data))
		end
	end

	return split_chests
end

--- @param entities LuaEntity[]
local function destroy_entities(entities)
	for _, entity in ipairs(entities) do
		if entity and entity.valid then
			entity.destroy({ raise_destroy = true })
		end
	end
end

--- @param split_chests LuaEntity[]
--- @return boolean
local function all_split_chests_created(split_chests)
	for _, split_chest in ipairs(split_chests) do
		if split_chest == nil or not split_chest.valid then
			return false
		end
	end
	return true
end

--- @param merged_chest LuaEntity
--- @param player LuaPlayer
--- @param player_index integer
--- @return boolean
function MergingChests.try_split_merged_chest(merged_chest, player, player_index)
	local is_ghost = merged_chest.name == 'entity-ghost'
	local merged_chest_name = is_ghost and merged_chest.ghost_name or merged_chest.name
	local split_chest_name, width, height = MergingChests.get_merged_chest_info(merged_chest_name)
	if split_chest_name == nil or width == nil or height == nil then
		return false
	end

	if MergingChests.is_infinity_chest_name(merged_chest_name) then
		player.create_local_flying_text({
			text = { 'flying-text.'..MergingChests.prefix_with_modname('infinity-split-disabled') },
			position = merged_chest.position
		})
		return false
	end

	local required_chests = width * height
	local quality = merged_chest.quality
	local has_required_chests = is_ghost or MergingChests.get_player_item_count(player, split_chest_name, quality) >= required_chests
	local source_inventory = merged_chest.get_inventory(defines.inventory.chest)
	local source_has_items = source_inventory and not source_inventory.is_empty()

	if not has_required_chests and source_has_items then
		player.create_local_flying_text({
			text = { 'flying-text.'..MergingChests.prefix_with_modname('items-would-be-deleted-split-missing-chests') },
			position = merged_chest.position
		})
		return false
	end

	if not is_ghost and has_required_chests and not MergingChests.remove_player_items(player, split_chest_name, required_chests, quality) then
		return false
	end

	if not is_ghost and has_required_chests and not MergingChests.can_move_inventories({ merged_chest }, split_chest_name, required_chests) then
		MergingChests.refund_player_items(player, split_chest_name, required_chests, quality)
		player.create_local_flying_text({
			text = { 'flying-text.'..MergingChests.prefix_with_modname('items-would-be-deleted-split') },
			position = merged_chest.position
		})
		return false
	end

	local total_bar = MergingChests.get_total_bar({ merged_chest }, is_ghost)
	local split_chests = create_split_chest(merged_chest, split_chest_name, width, height, player, is_ghost or not has_required_chests, total_bar)
	if not all_split_chests_created(split_chests) then
		destroy_entities(split_chests)
		if not is_ghost and has_required_chests then
			MergingChests.refund_player_items(player, split_chest_name, required_chests, quality)
		end
		return false
	end

	if not is_ghost and has_required_chests then
		for _, split_chest in ipairs(split_chests) do
			split_chest.last_user = player
		end
		if not MergingChests.move_inventories({ merged_chest }, split_chests) then
			destroy_entities(split_chests)
			MergingChests.refund_player_items(player, split_chest_name, required_chests, quality)
			return false
		end
	end
	MergingChests.reconnect_circuits({ merged_chest }, split_chests, false, true)

	raise_on_chest_split({
		player_index = player_index,
		surface = merged_chest.surface,
		merged_chest = merged_chest,
		split_chests = split_chests,
		is_ghost = is_ghost or not has_required_chests,
	})
	merged_chest.destroy({ raise_destroy = true })

	return true
end

local function on_player_alt_selected_area(event)
	if event.item and event.item == MergingChests.merge_selection_tool_name then
		local player = game.players[event.player_index]

		if #event.entities == 1 then
			MergingChests.try_split_merged_chest(event.entities[1], player, event.player_index)
		end
	end
end

script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)
