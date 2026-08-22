local train_transfer = require('scripts.train_transfer')

local frame_name = MergingChests.prefix_with_modname('direct-transfer-frame')
local dropdown_name = MergingChests.prefix_with_modname('direct-transfer-mode')
local filter_flow_name = MergingChests.prefix_with_modname('direct-transfer-filter-flow')
local filter_name = MergingChests.prefix_with_modname('direct-transfer-filter')
local status_label_name = MergingChests.prefix_with_modname('direct-transfer-status')
local search_area_color = { r = 1, g = 0.9, b = 0, a = 0.22 }

local mode_to_index = {
	[train_transfer.modes.off] = 1,
	[train_transfer.modes.load] = 2,
	[train_transfer.modes.unload] = 3,
}

local index_to_mode = {
	train_transfer.modes.off,
	train_transfer.modes.load,
	train_transfer.modes.unload,
}

local function get_status_caption(entity)
	local status, count, reason = train_transfer.get_status(entity)
	if status == 'active' then
		return { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-status-active'), count }
	end
	if status == 'off' then
		return { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-status-off') }
	end
	if status == 'no-wagon' then
		return { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-status-no-wagon') }
	end
	if status == 'not-stopped' then
		return { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-status-not-stopped') }
	end
	if status == 'unsupported' then
		return { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-status-unsupported') }
	end

	return { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-status-not-adjacent'), reason or 'unknown' }
end

local function update_status(player, entity)
	local frame = player.gui.left[frame_name]
	if frame == nil then
		return
	end

	local status_label = frame[status_label_name]
	if status_label then
		status_label.caption = get_status_caption(entity)
	end
end

local function is_direct_transfer_train_container(entity)
	if entity == nil or not entity.valid or entity.name == 'entity-ghost' then
		return false
	end

	local chest_name = MergingChests.get_merged_chest_info(entity.name)
	return chest_name == MergingChests.chest_names.steel or chest_name == MergingChests.chest_names.infinity
end

local function get_player_state(player_index)
	storage.train_transfer = storage.train_transfer or {}
	storage.train_transfer.players = storage.train_transfer.players or {}
	storage.train_transfer.players[player_index] = storage.train_transfer.players[player_index] or {}
	return storage.train_transfer.players[player_index]
end

local function destroy_search_area(player_state)
	if player_state == nil then
		return
	end

	for _, render_object in ipairs(player_state.search_area_render_objects or {}) do
		render_object.destroy()
	end
	player_state.search_area_render_objects = nil
end

local function save_filter_from_gui(player)
	local data = storage.train_transfer
	local player_state = data and data.players and data.players[player.index]
	local entity = player_state and player_state.opened_entity
	if entity == nil or not entity.valid or entity.unit_number ~= player_state.opened_unit_number then
		return
	end

	local frame = player.gui.left[frame_name]
	local filter_flow = frame and frame[filter_flow_name]
	local filter_button = filter_flow and filter_flow[filter_name]
	if filter_button and filter_button.valid then
		train_transfer.set_filter(entity, filter_button.elem_value)
	end
end

local function draw_search_area(player, entity)
	local player_state = get_player_state(player.index)
	destroy_search_area(player_state)

	local areas = train_transfer.get_wagon_search_areas(entity)
	if #areas == 0 then
		return
	end

	player_state.search_area_render_objects = {}
	for _, area in ipairs(areas) do
		table.insert(player_state.search_area_render_objects, rendering.draw_rectangle({
			color = search_area_color,
			width = 2,
			filled = true,
			left_top = area.left_top,
			right_bottom = area.right_bottom,
			surface = entity.surface,
			players = { player },
			draw_on_ground = true,
		}))
	end
end

local function destroy_gui(player)
	save_filter_from_gui(player)

	local frame = player.gui.left[frame_name]
	if frame then
		frame.destroy()
	end

	if storage.train_transfer and storage.train_transfer.players then
		destroy_search_area(storage.train_transfer.players[player.index])
		storage.train_transfer.players[player.index] = nil
	end
end

local function create_gui(player, entity)
	destroy_gui(player)
	draw_search_area(player, entity)

	local mode = train_transfer.get_mode(entity)
	if mode ~= train_transfer.modes.off then
		train_transfer.set_mode(entity, mode)
	end

	local frame = player.gui.left.add({
		type = 'frame',
		name = frame_name,
		direction = 'vertical',
		caption = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer') },
	})

	local flow = frame.add({
		type = 'flow',
		direction = 'horizontal',
	})
	flow.add({
		type = 'label',
		caption = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-mode') },
	})
	flow.add({
		type = 'drop-down',
		name = dropdown_name,
		items = {
			{ 'gui.'..MergingChests.prefix_with_modname('direct-transfer-off') },
			{ 'gui.'..MergingChests.prefix_with_modname('direct-transfer-load') },
			{ 'gui.'..MergingChests.prefix_with_modname('direct-transfer-unload') },
		},
		selected_index = mode_to_index[mode] or 1,
	})
	local filter_flow = frame.add({
		type = 'flow',
		name = filter_flow_name,
		direction = 'horizontal',
	})
	filter_flow.add({
		type = 'label',
		caption = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-filter') },
	})
	filter_flow.add({
		type = 'choose-elem-button',
		name = filter_name,
		elem_type = 'item',
		item = train_transfer.get_filter(entity),
	})
	frame.add({
		type = 'label',
		name = status_label_name,
		caption = get_status_caption(entity),
	})

	local player_state = get_player_state(player.index)
	player_state.opened_unit_number = entity.unit_number
	player_state.opened_entity = entity
end

local function on_gui_opened(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if is_direct_transfer_train_container(event.entity) then
		create_gui(player, event.entity)
	else
		destroy_gui(player)
	end
end

local function on_gui_closed(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if event.element and event.element.valid and event.element.name == frame_name then
		destroy_gui(player)
	elseif event.entity == nil or is_direct_transfer_train_container(event.entity) then
		destroy_gui(player)
	end
end

local function get_opened_entity(event)
	local data = storage.train_transfer
	local player_state = data and data.players and data.players[event.player_index]
	local entity = player_state and player_state.opened_entity
	if entity == nil or not entity.valid or entity.unit_number ~= player_state.opened_unit_number then
		return nil
	end

	return entity
end

local function on_gui_selection_state_changed(event)
	local element = event.element
	if element == nil or not element.valid or element.name ~= dropdown_name then
		return
	end

	local entity = get_opened_entity(event)
	if entity == nil then
		return
	end

	train_transfer.set_mode(entity, index_to_mode[element.selected_index] or train_transfer.modes.off)

	local player = game.get_player(event.player_index)
	if player then
		update_status(player, entity)
	end
end

local function on_gui_elem_changed(event)
	local element = event.element
	if element == nil or not element.valid or element.name ~= filter_name then
		return
	end

	local entity = get_opened_entity(event)
	if entity == nil then
		return
	end

	train_transfer.set_filter(entity, element.elem_value)

	local player = game.get_player(event.player_index)
	if player then
		update_status(player, entity)
	end
end

local function on_selected_entity_changed(event)
	local player = game.get_player(event.player_index)
	if player == nil then
		return
	end

	if is_direct_transfer_train_container(player.selected) then
		draw_search_area(player, player.selected)
	elseif storage.train_transfer and storage.train_transfer.players then
		local player_state = storage.train_transfer.players[event.player_index]
		if player_state and player_state.opened_entity and player_state.opened_entity.valid then
			draw_search_area(player, player_state.opened_entity)
		else
			destroy_search_area(player_state)
		end
	end
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
