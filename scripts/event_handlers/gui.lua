local function has_merge_tool_in_cursor(player)
	local stack = player.cursor_stack
	return stack and stack.valid_for_read and stack.name == MergingChests.merge_selection_tool_name
end

local function destroy_merge_mode_gui(player)
	local frame = player.gui.left[MergingChests.gui_names.frame]
	if frame then
		frame.destroy()
	end
end

local function ensure_merge_mode_gui(player)
	local frame = player.gui.left[MergingChests.gui_names.frame]
	if not frame then
		frame = player.gui.left.add({
			type = 'frame',
			name = MergingChests.gui_names.frame,
			direction = 'horizontal'
		})
		frame.add({
			type = 'label',
			caption = { 'gui.'..MergingChests.prefix_with_modname('container-type') }
		})
		frame.add({
			type = 'button',
			name = MergingChests.gui_names.normal,
			caption = { 'gui.'..MergingChests.prefix_with_modname('normal') }
		})
		frame.add({
			type = 'button',
			name = MergingChests.gui_names.infinity,
			caption = { 'gui.'..MergingChests.prefix_with_modname('infinity') }
		})
	end

	return frame
end

function MergingChests.refresh_player_merge_mode_gui(player)
	if not player or not player.valid then
		return
	end

	if not MergingChests.can_player_use_infinity(player) then
		MergingChests.set_player_merge_mode(player, MergingChests.merge_modes.normal)
		destroy_merge_mode_gui(player)
		return
	end

	if not has_merge_tool_in_cursor(player) then
		destroy_merge_mode_gui(player)
		return
	end

	local frame = ensure_merge_mode_gui(player)
	local mode = MergingChests.get_player_merge_mode(player)
	frame[MergingChests.gui_names.normal].enabled = mode ~= MergingChests.merge_modes.normal
	frame[MergingChests.gui_names.infinity].enabled = mode ~= MergingChests.merge_modes.infinity
end

local function on_gui_click(event)
	local element = event.element
	if not element or not element.valid then
		return
	end

	if element.name ~= MergingChests.gui_names.normal and element.name ~= MergingChests.gui_names.infinity then
		return
	end

	local player = game.get_player(event.player_index)
	if not player then
		return
	end

	if element.name == MergingChests.gui_names.infinity then
		MergingChests.set_player_merge_mode(player, MergingChests.merge_modes.infinity)
	else
		MergingChests.set_player_merge_mode(player, MergingChests.merge_modes.normal)
	end

	MergingChests.refresh_player_merge_mode_gui(player)
end

local function on_player_cursor_stack_changed(event)
	local player = game.get_player(event.player_index)
	MergingChests.refresh_player_merge_mode_gui(player)
end

local function refresh_visible_guis(event)
	if event.tick % 60 ~= 0 then
		return
	end

	for _, player in pairs(game.connected_players) do
		MergingChests.refresh_player_merge_mode_gui(player)
	end
end

local function register_event(event_name, handler)
	if event_name then
		script.on_event(event_name, handler)
	end
end

register_event(defines.events.on_gui_click, on_gui_click)
register_event(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed)
register_event(defines.events.on_player_controller_changed, on_player_cursor_stack_changed)
register_event(defines.events.on_player_toggled_map_editor, on_player_cursor_stack_changed)
register_event(defines.events.on_player_cheat_mode_enabled, on_player_cursor_stack_changed)
register_event(defines.events.on_player_cheat_mode_disabled, on_player_cursor_stack_changed)
register_event(defines.events.on_player_joined_game, on_player_cursor_stack_changed)
register_event(defines.events.on_tick, refresh_visible_guis)
