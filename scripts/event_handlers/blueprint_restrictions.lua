local function get_event_entity(event)
	return event.created_entity or event.entity
end

local function reject_infinity_entity(event)
	local entity = get_event_entity(event)
	if not entity or not entity.valid then
		return
	end

	local entity_name = entity.name == 'entity-ghost' and entity.ghost_name or entity.name
	if not MergingChests.is_infinity_chest_name(entity_name) then
		return
	end

	local player = event.player_index and game.get_player(event.player_index) or nil
	if player and MergingChests.can_player_use_infinity(player) then
		return
	end

	local position = entity.position
	entity.destroy({ raise_destroy = true })

	if player then
		player.create_local_flying_text({
			text = { 'flying-text.'..MergingChests.prefix_with_modname('infinity-requires-cheat-mode') },
			position = position
		})
	end
end

local function register(event_name)
	if event_name then
		script.on_event(event_name, reject_infinity_entity)
	end
end

register(defines.events.on_built_entity)
register(defines.events.on_robot_built_entity)
register(defines.events.script_raised_built)
register(defines.events.script_raised_revive)
