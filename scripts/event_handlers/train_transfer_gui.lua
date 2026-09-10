local train_transfer = require('scripts.train_transfer')

local frame_name = MergingChests.prefix_with_modname('direct-transfer-frame')
local dropdown_name = MergingChests.prefix_with_modname('direct-transfer-mode')
local filter_flow_name = MergingChests.prefix_with_modname('direct-transfer-filter-flow')
local filter_name = MergingChests.prefix_with_modname('direct-transfer-filter')
local filter_mode_name = MergingChests.prefix_with_modname('direct-transfer-filter-mode')
local filter_slots_name = MergingChests.prefix_with_modname('direct-transfer-filter-slots')
local status_label_name = MergingChests.prefix_with_modname('direct-transfer-status')
local circuit_panel_name = MergingChests.prefix_with_modname('direct-transfer-circuit')
local circuit_toggle_name = MergingChests.prefix_with_modname('direct-transfer-circuit-filters')
local circuit_status_name = MergingChests.prefix_with_modname('direct-transfer-circuit-status')
local refresh_open_guis
local gui_refresh_interval = 15

function train_transfer.restore_gui_handler()
	local any = false
	local data = storage.train_transfer
	for _, state in pairs(data and data.players or {}) do
		if state.opened_entity then any = true; break end
	end
	script.on_nth_tick(gui_refresh_interval, any and refresh_open_guis or nil)
end

local function update_circuit_controls(player, entity)
	local frame = player.gui.relative[frame_name]
	local panel = frame and frame[circuit_panel_name]
	if not panel then return end
	local configuration = train_transfer.get_filter_configuration(entity)
	local connected = train_transfer.has_green_connection(entity)
	local toggle = panel[circuit_toggle_name]
	toggle.state = configuration.circuit_set_filters
	toggle.enabled = connected
	panel[circuit_status_name].caption = { 'gui.'..MergingChests.prefix_with_modname(
		connected and 'direct-transfer-green-connected' or 'direct-transfer-green-disconnected') }
	local manual = not (connected and configuration.circuit_set_filters)
	local filters = frame[filter_flow_name]
	filters[filter_mode_name].enabled = manual
	for slot = 1, train_transfer.filter_slot_count do
		filters[filter_slots_name][filter_name..'-'..slot].enabled = manual
	end
end
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
	local frame = player.gui.relative[frame_name]
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
	-- Remove panels left in saves made before relative anchoring.
	local legacy_frame = player.gui.left[frame_name]
	if legacy_frame then legacy_frame.destroy() end
	local frame = player.gui.relative[frame_name]
	if frame then
		frame.destroy()
	end

	if storage.train_transfer and storage.train_transfer.players then
		destroy_search_area(storage.train_transfer.players[player.index])
		storage.train_transfer.players[player.index] = nil
	end
	train_transfer.restore_gui_handler()
end

local function create_gui(player, entity)
	destroy_gui(player)
	draw_search_area(player, entity)

	local mode = train_transfer.get_mode(entity)

	local frame = player.gui.relative.add({
		type = 'frame',
		name = frame_name,
		anchor = {
			gui = defines.relative_gui_type.container_gui,
			position = defines.relative_gui_position.left,
			name = entity.name,
		},
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
	local configuration = train_transfer.get_filter_configuration(entity)
	local filter_flow = frame.add({
		type = 'frame', name = filter_flow_name, direction = 'vertical',
		style = 'inside_shallow_frame_with_padding_and_vertical_spacing',
	})
	filter_flow.add({ type = 'label', style = 'heading_2_label',
		caption = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-filter') } })
	filter_flow.add({
		type = 'switch', name = filter_mode_name, style = 'switch',
		allow_none_state = false,
		left_label_caption = { 'gui-inserter.whitelist' },
		right_label_caption = { 'gui-inserter.blacklist' },
		switch_state = configuration.mode == 'blacklist' and 'right' or 'left',
		tooltip = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-filter-tooltip') },
	})
	local slots = filter_flow.add({ type = 'table', name = filter_slots_name,
		column_count = train_transfer.filter_slot_count, style = 'filter_slot_table' })
	for slot = 1, train_transfer.filter_slot_count do
		slots.add({
			type = 'choose-elem-button', name = filter_name..'-'..slot,
			style = 'slot_button', elem_type = 'item-with-quality',
			['item-with-quality'] = configuration.slots[slot],
		})
	end
	local circuit_panel = frame.add({ type = 'frame', name = circuit_panel_name, direction = 'vertical',
		style = 'inside_shallow_frame_with_padding_and_vertical_spacing' })
	circuit_panel.add({ type = 'label', style = 'heading_2_label', caption = { 'gui-control-behavior.circuit-network' } })
	circuit_panel.add({ type = 'checkbox', name = circuit_toggle_name,
		caption = { 'gui-control-behavior-modes.set-filters' }, state = configuration.circuit_set_filters,
		tooltip = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-circuit-tooltip') } })
	circuit_panel.add({ type = 'label', name = circuit_status_name })
	local input_help = circuit_panel.add({ type = 'label',
		caption = { 'gui.'..MergingChests.prefix_with_modname('direct-transfer-input-help') } })
	input_help.style.single_line = false
	input_help.style.maximal_width = 300
	frame.add({
		type = 'label',
		name = status_label_name,
		caption = get_status_caption(entity),
	})

	local player_state = get_player_state(player.index)
	player_state.opened_unit_number = entity.unit_number
	player_state.opened_entity = entity
	update_circuit_controls(player, entity)
	train_transfer.restore_gui_handler()
end

refresh_open_guis = function()
	local stale = {}
	for player_index, state in pairs(storage.train_transfer.players or {}) do
		if state.opened_entity then
			local player = game.get_player(player_index)
			if player and state.opened_entity.valid then
				update_circuit_controls(player, state.opened_entity)
			else stale[#stale + 1] = player_index end
		end
	end
	for _, player_index in ipairs(stale) do
		local player = game.get_player(player_index)
		if player then destroy_gui(player) else
			destroy_search_area(storage.train_transfer.players[player_index])
			storage.train_transfer.players[player_index] = nil
		end
	end
	train_transfer.restore_gui_handler()
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

-- Synchronize other viewers without ever saving a stale whole GUI snapshot.
local function sync_filter_guis(entity)
	local configuration = train_transfer.get_filter_configuration(entity)
	for player_index, player_state in pairs(storage.train_transfer.players or {}) do
		if player_state.opened_unit_number == entity.unit_number then
			local player = game.get_player(player_index)
			local frame = player and player.gui.relative[frame_name]
			local panel = frame and frame[filter_flow_name]
			if panel and panel[filter_slots_name] and panel[filter_mode_name] then
				panel[filter_mode_name].switch_state = configuration.mode == 'blacklist' and 'right' or 'left'
				for slot = 1, train_transfer.filter_slot_count do
					panel[filter_slots_name][filter_name..'-'..slot].elem_value = configuration.slots[slot]
				end
				update_status(player, entity)
				update_circuit_controls(player, entity)
			end
		end
	end
end

local function get_event_filter_panel(event)
	local player = game.get_player(event.player_index)
	local frame = player and player.gui.relative[frame_name]
	return frame and frame[filter_flow_name]
end

local function on_gui_elem_changed(event)
	local element = event.element
	if not element or not element.valid then return end
	local entity = get_opened_entity(event)
	local panel = get_event_filter_panel(event)
	local slots = panel and panel[filter_slots_name]
	if not entity or not slots then return end
	for slot = 1, train_transfer.filter_slot_count do
		if slots[filter_name..'-'..slot] == element then
			train_transfer.set_filter(entity, slot, element.elem_value)
			sync_filter_guis(entity)
			return
		end
	end
end

local function on_gui_switch_state_changed(event)
	local element = event.element
	if not element or not element.valid then return end
	local entity = get_opened_entity(event)
	local panel = get_event_filter_panel(event)
	if not entity or not panel or panel[filter_mode_name] ~= element then return end
	train_transfer.set_filter_mode(entity, element.switch_state == 'right' and 'blacklist' or 'whitelist')
	sync_filter_guis(entity)
end

local function on_gui_checked_state_changed(event)
	local entity = get_opened_entity(event)
	local player = game.get_player(event.player_index)
	local frame = player and player.gui.relative[frame_name]
	local panel = frame and frame[circuit_panel_name]
	if not entity or not panel or panel[circuit_toggle_name] ~= event.element then return end
	if train_transfer.has_green_connection(entity) then
		train_transfer.set_circuit_set_filters(entity, event.element.state)
	end
	sync_filter_guis(entity)
end

function train_transfer.rebuild_open_guis()
	local opened = {}
	for player_index, player_state in pairs(storage.train_transfer.players or {}) do
		if player_state.opened_entity and player_state.opened_entity.valid then
			opened[#opened + 1] = { player = game.get_player(player_index), entity = player_state.opened_entity }
		end
	end
	for _, entry in ipairs(opened) do
		if entry.player then create_gui(entry.player, entry.entity) end
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
script.on_event(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
