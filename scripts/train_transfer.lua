local train_transfer = {}

MergingChests.train_transfer = train_transfer

train_transfer.modes = {
	off = 'off',
	load = 'load',
	unload = 'unload',
}

train_transfer.mode_order = {
	train_transfer.modes.off,
	train_transfer.modes.load,
	train_transfer.modes.unload,
}

train_transfer.nth_tick = 10
train_transfer.items_per_container_cycle = 64
train_transfer.wagon_search_radius = 5.0
train_transfer.long_side_center_min_distance = 0.55
train_transfer.long_side_center_max_distance = 2.35
train_transfer.long_side_south_center_max_distance = 2.1
train_transfer.long_axis_end_margin = 0.25
train_transfer.minimum_long_axis_overlap = 0.5
train_transfer.cybersyn2_shim_spacing = 5
train_transfer.cybersyn2_shim_rail_search_width = 1.5

local epsilon = 0.05
local cached_train_container_names = nil
local rail_types = { 'straight-rail', 'curved-rail-a', 'curved-rail-b', 'half-diagonal-rail' }

local function ensure_storage()
	storage.train_transfer = storage.train_transfer or {}
	local data = storage.train_transfer
	data.modes = data.modes or {}
	data.filters = data.filters or {}
	data.players = data.players or {}
	data.active_trains = data.active_trains or {}
	data.container_registrations = data.container_registrations or {}
	data.destroyed_registrations = data.destroyed_registrations or {}
	data.cybersyn2_shims = data.cybersyn2_shims or {}
	data.active_transfer_count = data.active_transfer_count or 0
	return data
end

local function set_nth_tick_handler(enabled)
	script.on_nth_tick(train_transfer.nth_tick, enabled and train_transfer.on_nth_tick or nil)
end

local function update_nth_tick_handler()
	local data = ensure_storage()
	set_nth_tick_handler(data.active_transfer_count > 0)
end

local function box_width(box)
	return box.right_bottom.x - box.left_top.x
end

local function box_height(box)
	return box.right_bottom.y - box.left_top.y
end

local function expand_box(box, amount)
	return {
		left_top = { x = box.left_top.x - amount, y = box.left_top.y - amount },
		right_bottom = { x = box.right_bottom.x + amount, y = box.right_bottom.y + amount },
	}
end

local function get_transfer_box(entity)
	return entity.selection_box or entity.bounding_box
end

local function interval_overlap(a_min, a_max, b_min, b_max)
	return math.min(a_max, b_max) - math.max(a_min, b_min)
end

local function format_number(value)
	if value == nil then
		return 'nil'
	end

	return string.format('%.2f', value)
end

local function is_direct_transfer_train_container(entity)
	if entity == nil or not entity.valid or entity.name == 'entity-ghost' then
		return false
	end

	local chest_name, width, height = MergingChests.get_merged_chest_info(entity.name)
	if width == nil or height == nil then
		return false
	end
	if chest_name ~= MergingChests.chest_names.steel and chest_name ~= MergingChests.chest_names.infinity then
		return false
	end

	return true, width, height
end

local function get_train_container_names()
	if cached_train_container_names ~= nil then
		return cached_train_container_names
	end

	cached_train_container_names = {}
	for name, _ in pairs(prototypes.entity) do
		local chest_name = MergingChests.get_merged_chest_info(name)
		if chest_name == MergingChests.chest_names.steel or chest_name == MergingChests.chest_names.infinity then
			table.insert(cached_train_container_names, name)
		end
	end

	return cached_train_container_names
end

local is_wagon_in_long_side_search_area

local function get_long_side_center_distance(container, wagon, horizontal)
	local delta = horizontal
		and (wagon.position.y - container.position.y)
		or (wagon.position.x - container.position.x)
	local max_distance = delta > 0
		and train_transfer.long_side_south_center_max_distance
		or train_transfer.long_side_center_max_distance

	return math.abs(delta), max_distance
end

local function is_center_distance_in_range(distance, max_distance)
	return distance >= train_transfer.long_side_center_min_distance - epsilon
		and distance <= max_distance + epsilon
end

local function describe_center_distance_failure(distance, max_distance)
	if distance < train_transfer.long_side_center_min_distance - epsilon then
		return 'too-close center-distance='..format_number(distance)
	end
	if distance > max_distance + epsilon then
		return 'too-far center-distance='..format_number(distance)
	end

	return nil
end

local function is_adjacent_to_long_side(container, wagon)
	local is_container, width, height = is_direct_transfer_train_container(container)
	if not is_container or wagon == nil or not wagon.valid or wagon.name ~= 'cargo-wagon' then
		return false
	end

	local horizontal = width > height
	local container_box = get_transfer_box(container)
	local wagon_box = get_transfer_box(wagon)

	if not is_wagon_in_long_side_search_area(container, wagon) then
		return false
	end

	local overlap = horizontal
		and interval_overlap(container_box.left_top.x, container_box.right_bottom.x, wagon_box.left_top.x, wagon_box.right_bottom.x)
		or interval_overlap(container_box.left_top.y, container_box.right_bottom.y, wagon_box.left_top.y, wagon_box.right_bottom.y)
	if overlap < train_transfer.minimum_long_axis_overlap then
		return false
	end

	local center_distance, max_distance = get_long_side_center_distance(container, wagon, horizontal)
	return is_center_distance_in_range(center_distance, max_distance)
end

local function get_adjacency_status(container, wagon)
	local is_container, width, height = is_direct_transfer_train_container(container)
	if not is_container then
		return false, 'not-container'
	end
	if wagon == nil or not wagon.valid or wagon.name ~= 'cargo-wagon' then
		return false, 'not-cargo-wagon'
	end

	local horizontal = width > height
	local container_box = get_transfer_box(container)
	local wagon_box = get_transfer_box(wagon)

	if not is_wagon_in_long_side_search_area(container, wagon) then
		return false, 'outside-side-band'
	end

	local overlap = horizontal
		and interval_overlap(container_box.left_top.x, container_box.right_bottom.x, wagon_box.left_top.x, wagon_box.right_bottom.x)
		or interval_overlap(container_box.left_top.y, container_box.right_bottom.y, wagon_box.left_top.y, wagon_box.right_bottom.y)
	if overlap < train_transfer.minimum_long_axis_overlap then
		return false, 'short-side overlap='..format_number(overlap)
	end

	local center_distance, max_distance = get_long_side_center_distance(container, wagon, horizontal)
	local distance_failure = describe_center_distance_failure(center_distance, max_distance)
	if distance_failure ~= nil then
		return false, distance_failure
	end

	return true, 'adjacent'
end

local function register_destroyed_object(data, object, record)
	if object == nil or not object.valid then
		return nil
	end

	local registration_number = script.register_on_object_destroyed(object)
	data.destroyed_registrations[registration_number] = record
	return registration_number
end

local function register_container(data, container)
	if container.unit_number == nil or data.container_registrations[container.unit_number] ~= nil then
		return
	end

	data.container_registrations[container.unit_number] = register_destroyed_object(data, container, {
		kind = 'container',
		unit_number = container.unit_number,
	})
end

local function raise_script_built(entity)
	if entity and entity.valid then
		script.raise_event(defines.events.script_raised_built, { entity = entity })
	end
end

local function raise_script_destroy(entity)
	if entity and entity.valid then
		script.raise_event(defines.events.script_raised_destroy, { entity = entity })
	end
end

local function destroy_cybersyn2_shims(data, unit_number, raise_destroy)
	local shim_group = data.cybersyn2_shims[unit_number]
	if shim_group == nil then
		return
	end

	for _, shim in ipairs(shim_group.entities or {}) do
		if shim and shim.valid then
			if raise_destroy then
				raise_script_destroy(shim)
			end
			shim.destroy()
		end
	end
	data.cybersyn2_shims[unit_number] = nil
end

local function get_cybersyn2_shim_points(entity, width, height)
	local points = {}
	local horizontal = width > height
	local length = horizontal and width or height
	local start = horizontal
		and (entity.position.x - (width - 1) / 2)
		or (entity.position.y - (height - 1) / 2)

	for offset = 0, length - 1, train_transfer.cybersyn2_shim_spacing do
		if horizontal then
			table.insert(points, { x = start + offset, y = entity.position.y })
		else
			table.insert(points, { x = entity.position.x, y = start + offset })
		end
	end

	return points
end

local function squared_distance(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	return dx * dx + dy * dy
end

local function find_nearest_rail(surface, area, point)
	local nearest = nil
	local nearest_distance = nil
	for _, rail in ipairs(surface.find_entities_filtered({ area = area, type = rail_types })) do
		local distance = squared_distance(rail.position, point)
		if nearest_distance == nil or distance < nearest_distance then
			nearest = rail
			nearest_distance = distance
		end
	end
	return nearest
end

local function get_cybersyn2_side_rail_search_areas(container, point, horizontal)
	local half_width = train_transfer.cybersyn2_shim_rail_search_width / 2
	if horizontal then
		return {
			{
				left_top = {
					x = point.x - half_width,
					y = container.position.y - train_transfer.long_side_center_max_distance,
				},
				right_bottom = {
					x = point.x + half_width,
					y = container.position.y - train_transfer.long_side_center_min_distance,
				},
			},
			{
				left_top = {
					x = point.x - half_width,
					y = container.position.y + train_transfer.long_side_center_min_distance,
				},
				right_bottom = {
					x = point.x + half_width,
					y = container.position.y + train_transfer.long_side_south_center_max_distance,
				},
			},
		}
	end

	return {
		{
			left_top = {
				x = container.position.x - train_transfer.long_side_center_max_distance,
				y = point.y - half_width,
			},
			right_bottom = {
				x = container.position.x - train_transfer.long_side_center_min_distance,
				y = point.y + half_width,
			},
		},
		{
			left_top = {
				x = container.position.x + train_transfer.long_side_center_min_distance,
				y = point.y - half_width,
			},
			right_bottom = {
				x = container.position.x + train_transfer.long_side_south_center_max_distance,
				y = point.y + half_width,
			},
		},
	}
end

local function create_cybersyn2_shim_at(container, position, rail, direction)
	local shim = container.surface.create_entity({
		name = MergingChests.cybersyn2_inserter_shim_name,
		position = position,
		direction = direction,
		force = container.force,
		raise_built = false,
		create_build_effect_smoke = false,
	})
	if shim == nil then
		return nil
	end

	shim.active = false
	if rail and rail.valid then
		shim.pickup_position = rail.position
		shim.drop_position = position
	end
	raise_script_built(shim)
	return shim
end

local function rebuild_cybersyn2_shims(data, container)
	local is_container, width, height = is_direct_transfer_train_container(container)
	if not is_container or container.unit_number == nil or prototypes.entity[MergingChests.cybersyn2_inserter_shim_name] == nil then
		return
	end

	destroy_cybersyn2_shims(data, container.unit_number, true)

	local horizontal = width > height
	local directions = horizontal
		and { defines.direction.north, defines.direction.south }
		or { defines.direction.west, defines.direction.east }
	local entities = {}
	for _, point in ipairs(get_cybersyn2_shim_points(container, width, height)) do
		for side_index, area in ipairs(get_cybersyn2_side_rail_search_areas(container, point, horizontal)) do
			local rail = find_nearest_rail(container.surface, area, point)
			local direction = directions[side_index]
			local shim = rail and create_cybersyn2_shim_at(container, point, rail, direction)
			if shim then
				table.insert(entities, shim)
			end
		end
	end

	if #entities > 0 then
		data.cybersyn2_shims[container.unit_number] = {
			container = container,
			entities = entities,
		}
	end
end

local function unregister_container(data, unit_number)
	local registration_number = data.container_registrations[unit_number]
	if registration_number ~= nil then
		data.destroyed_registrations[registration_number] = nil
		data.container_registrations[unit_number] = nil
	end
end

function train_transfer.get_mode(entity)
	if entity == nil or not entity.valid or entity.unit_number == nil or not is_direct_transfer_train_container(entity) then
		return train_transfer.modes.off
	end

	local data = ensure_storage()
	return data.modes[entity.unit_number] or train_transfer.modes.off
end

function train_transfer.get_filter(entity)
	if entity == nil or not entity.valid or entity.unit_number == nil or not is_direct_transfer_train_container(entity) then
		return nil
	end

	local data = ensure_storage()
	return data.filters[entity.unit_number]
end

function train_transfer.get_wagon_search_area(entity)
	if entity == nil or not entity.valid or not is_direct_transfer_train_container(entity) then
		return nil
	end

	return expand_box(get_transfer_box(entity), train_transfer.wagon_search_radius)
end

function train_transfer.get_wagon_search_areas(entity)
	local is_container, width, height = is_direct_transfer_train_container(entity)
	if not is_container then
		return {}
	end

	local box = get_transfer_box(entity)
	local horizontal = width > height
	if horizontal then
		return {
			{
				left_top = {
					x = box.left_top.x - train_transfer.long_axis_end_margin,
					y = entity.position.y - train_transfer.long_side_center_max_distance,
				},
				right_bottom = {
					x = box.right_bottom.x + train_transfer.long_axis_end_margin,
					y = entity.position.y - train_transfer.long_side_center_min_distance,
				},
			},
			{
				left_top = {
					x = box.left_top.x - train_transfer.long_axis_end_margin,
					y = entity.position.y + train_transfer.long_side_center_min_distance,
				},
				right_bottom = {
					x = box.right_bottom.x + train_transfer.long_axis_end_margin,
					y = entity.position.y + train_transfer.long_side_south_center_max_distance,
				},
			},
		}
	end

	return {
		{
			left_top = {
				x = entity.position.x - train_transfer.long_side_center_max_distance,
				y = box.left_top.y - train_transfer.long_axis_end_margin,
			},
			right_bottom = {
				x = entity.position.x - train_transfer.long_side_center_min_distance,
				y = box.right_bottom.y + train_transfer.long_axis_end_margin,
			},
		},
		{
			left_top = {
				x = entity.position.x + train_transfer.long_side_center_min_distance,
				y = box.left_top.y - train_transfer.long_axis_end_margin,
			},
			right_bottom = {
				x = entity.position.x + train_transfer.long_side_south_center_max_distance,
				y = box.right_bottom.y + train_transfer.long_axis_end_margin,
			},
		},
	}
end

local function position_in_box(position, box)
	return position.x >= box.left_top.x
		and position.x <= box.right_bottom.x
		and position.y >= box.left_top.y
		and position.y <= box.right_bottom.y
end

is_wagon_in_long_side_search_area = function(container, wagon)
	for _, area in ipairs(train_transfer.get_wagon_search_areas(container)) do
		if position_in_box(wagon.position, area) then
			return true
		end
	end

	return false
end

local function remove_wagon_from_group(group, wagon_unit_number)
	local kept_wagons = {}
	for _, wagon in ipairs(group.wagons or {}) do
		if wagon.valid and wagon.unit_number ~= wagon_unit_number then
			table.insert(kept_wagons, wagon)
		end
	end
	group.wagons = kept_wagons
	if group.next_wagon > #group.wagons then
		group.next_wagon = 1
	end
end

local function stop_active_train(data, train_id)
	local active = data.active_trains[train_id]
	if active == nil then
		return
	end

	if active.train_registration then
		data.destroyed_registrations[active.train_registration] = nil
	end
	for _, registration_number in pairs(active.wagon_registrations or {}) do
		data.destroyed_registrations[registration_number] = nil
	end

	data.active_trains[train_id] = nil
	data.active_transfer_count = math.max((data.active_transfer_count or 1) - 1, 0)
	update_nth_tick_handler()
end

local function remove_container_from_active_trains(data, unit_number)
	local train_ids_to_stop = {}

	for train_id, active in pairs(data.active_trains) do
		local groups = {}
		for _, group in ipairs(active.groups or {}) do
			if group.container.valid and group.container.unit_number ~= unit_number then
				table.insert(groups, group)
			end
		end

		active.groups = groups
		if #active.groups == 0 then
			table.insert(train_ids_to_stop, train_id)
		end
	end

	for _, train_id in ipairs(train_ids_to_stop) do
		stop_active_train(data, train_id)
	end
end

local function cleanup_container(data, unit_number)
	data.modes[unit_number] = nil
	data.filters[unit_number] = nil
	destroy_cybersyn2_shims(data, unit_number, true)
	unregister_container(data, unit_number)
	remove_container_from_active_trains(data, unit_number)

	for player_index, player_state in pairs(data.players) do
		if player_state.opened_unit_number == unit_number then
			local player = game.get_player(player_index)
			if player then
				local frame = player.gui.left[MergingChests.prefix_with_modname('direct-transfer-frame')]
				if frame then
					frame.destroy()
				end
			end
			data.players[player_index] = nil
		end
	end
end

local function remove_wagon_from_active_train(data, train_id, wagon_unit_number)
	local active = data.active_trains[train_id]
	if active == nil then
		return
	end

	local registration_number = active.wagon_registrations and active.wagon_registrations[wagon_unit_number]
	if registration_number then
		data.destroyed_registrations[registration_number] = nil
		active.wagon_registrations[wagon_unit_number] = nil
	end

	local groups = {}
	for _, group in ipairs(active.groups or {}) do
		remove_wagon_from_group(group, wagon_unit_number)
		if #group.wagons > 0 then
			table.insert(groups, group)
		end
	end

	active.groups = groups
	if #active.groups == 0 then
		stop_active_train(data, train_id)
	end
end

local function sort_by_unit_number(entities)
	table.sort(entities, function(a, b)
		return (a.unit_number or 0) < (b.unit_number or 0)
	end)
end

local function add_wagon_to_container_group(groups_by_container, container, wagon, mode)
	local unit_number = container.unit_number
	if unit_number == nil then
		return
	end

	local group = groups_by_container[unit_number]
	if group == nil then
		group = {
			container = container,
			mode = mode,
			filter = train_transfer.get_filter(container),
			wagons = {},
			wagons_by_unit_number = {},
			next_wagon = 1,
			source_slot = 1,
		}
		groups_by_container[unit_number] = group
	end

	if wagon.unit_number ~= nil and group.wagons_by_unit_number[wagon.unit_number] == nil then
		group.wagons_by_unit_number[wagon.unit_number] = true
		table.insert(group.wagons, wagon)
	end
end

local function build_active_groups_for_train(data, train)
	local train_container_names = get_train_container_names()
	if #train_container_names == 0 then
		return {}
	end

	local groups_by_container = {}
	for _, wagon in ipairs(train.cargo_wagons) do
		if wagon.valid then
			for _, container in ipairs(wagon.surface.find_entities_filtered({
				area = expand_box(get_transfer_box(wagon), train_transfer.wagon_search_radius),
				name = train_container_names,
			})) do
				local mode = train_transfer.get_mode(container)
				if mode ~= train_transfer.modes.off and is_adjacent_to_long_side(container, wagon) then
					add_wagon_to_container_group(groups_by_container, container, wagon, mode)
					register_container(data, container)
				end
			end
		end
	end

	local groups = {}
	for _, group in pairs(groups_by_container) do
		sort_by_unit_number(group.wagons)
		group.wagons_by_unit_number = nil
		table.insert(groups, group)
	end
	table.sort(groups, function(a, b)
		return (a.container.unit_number or 0) < (b.container.unit_number or 0)
	end)

	return groups
end

local function start_train_transfer(train)
	if train == nil or not train.valid or train.state ~= defines.train_state.wait_station or train.station == nil then
		return
	end

	local data = ensure_storage()
	stop_active_train(data, train.id)

	local groups = build_active_groups_for_train(data, train)
	if #groups == 0 then
		return
	end

	local active = {
		train = train,
		groups = groups,
		wagon_registrations = {},
	}

	active.train_registration = register_destroyed_object(data, train, {
		kind = 'train',
		train_id = train.id,
	})

	for _, wagon in ipairs(train.cargo_wagons) do
		if wagon.valid and wagon.unit_number ~= nil then
			active.wagon_registrations[wagon.unit_number] = register_destroyed_object(data, wagon, {
				kind = 'wagon',
				train_id = train.id,
				unit_number = wagon.unit_number,
			})
		end
	end

	data.active_trains[train.id] = active
	data.active_transfer_count = (data.active_transfer_count or 0) + 1
	update_nth_tick_handler()
end

local function refresh_trains_near_container(container)
	if container == nil or not container.valid then
		return
	end

	local seen_trains = {}
	for _, wagon in ipairs(container.surface.find_entities_filtered({
		area = expand_box(get_transfer_box(container), train_transfer.wagon_search_radius),
		name = 'cargo-wagon',
	})) do
		if wagon.valid and wagon.train and wagon.train.valid then
			seen_trains[wagon.train.id] = wagon.train
		end
	end

	local data = ensure_storage()
	for train_id, train in pairs(seen_trains) do
		stop_active_train(data, train_id)
		start_train_transfer(train)
	end
end

function train_transfer.get_status(entity)
	if entity == nil or not entity.valid or not is_direct_transfer_train_container(entity) then
		return 'unsupported', 0
	end

	local mode = train_transfer.get_mode(entity)
	if mode == train_transfer.modes.off then
		return 'off', 0
	end

	local nearby_wagon_count = 0
	local stopped_wagon_count = 0
	local adjacent_wagon_count = 0
	local adjacency_failure = nil

	for _, wagon in ipairs(entity.surface.find_entities_filtered({
		area = expand_box(get_transfer_box(entity), train_transfer.wagon_search_radius),
		name = 'cargo-wagon',
	})) do
		nearby_wagon_count = nearby_wagon_count + 1
		if wagon.train and wagon.train.valid and wagon.train.state == defines.train_state.wait_station and wagon.train.station ~= nil then
			stopped_wagon_count = stopped_wagon_count + 1
			local adjacent, reason = get_adjacency_status(entity, wagon)
			if adjacent then
				adjacent_wagon_count = adjacent_wagon_count + 1
			else
				adjacency_failure = adjacency_failure or reason
			end
		end
	end

	if adjacent_wagon_count > 0 then
		return 'active', adjacent_wagon_count
	end
	if nearby_wagon_count == 0 then
		return 'no-wagon', 0
	end
	if stopped_wagon_count == 0 then
		return 'not-stopped', nearby_wagon_count
	end

	return 'not-adjacent', stopped_wagon_count, adjacency_failure or 'unknown'
end

function train_transfer.set_mode(entity, mode)
	if mode ~= train_transfer.modes.load and mode ~= train_transfer.modes.unload then
		mode = train_transfer.modes.off
	end
	if entity == nil or not entity.valid or entity.unit_number == nil or not is_direct_transfer_train_container(entity) then
		return false
	end

	local data = ensure_storage()
	if mode == train_transfer.modes.off then
		data.modes[entity.unit_number] = nil
		destroy_cybersyn2_shims(data, entity.unit_number, true)
		unregister_container(data, entity.unit_number)
	else
		data.modes[entity.unit_number] = mode
		register_container(data, entity)
		rebuild_cybersyn2_shims(data, entity)
	end

	remove_container_from_active_trains(data, entity.unit_number)
	refresh_trains_near_container(entity)
	return true
end

function train_transfer.set_filter(entity, item_name)
	if item_name ~= nil and prototypes.item[item_name] == nil then
		item_name = nil
	end
	if entity == nil or not entity.valid or entity.unit_number == nil or not is_direct_transfer_train_container(entity) then
		return false
	end

	local data = ensure_storage()
	data.filters[entity.unit_number] = item_name
	remove_container_from_active_trains(data, entity.unit_number)
	refresh_trains_near_container(entity)
	return true
end

local function transfer_from_inventory(source_inventory, target_inventory, group, temp_inventory, limit)
	if source_inventory == nil or target_inventory == nil or #source_inventory == 0 or limit <= 0 then
		return 0
	end

	local start_slot = group.source_slot or 1
	for offset = 0, #source_inventory - 1 do
		local index = ((start_slot + offset - 2) % #source_inventory) + 1
		local source_stack = source_inventory[index]
		if source_stack.valid_for_read and (group.filter == nil or source_stack.name == group.filter) then
			temp_inventory.clear()
			if temp_inventory[1].set_stack(source_stack) then
				local count_to_try = math.min(source_stack.count, limit)
				temp_inventory[1].count = count_to_try

				local inserted = target_inventory.insert(temp_inventory[1])
				if inserted > 0 then
					if inserted >= source_stack.count then
						source_stack.clear()
						group.source_slot = (index % #source_inventory) + 1
					else
						source_stack.count = source_stack.count - inserted
						group.source_slot = index
					end
					return inserted
				end
			end
		end
	end

	return 0
end

local function remove_invalid_wagons(group)
	local wagons = {}
	for _, wagon in ipairs(group.wagons or {}) do
		if wagon.valid and wagon.train and wagon.train.valid and wagon.train.state == defines.train_state.wait_station then
			table.insert(wagons, wagon)
		end
	end

	group.wagons = wagons
	if group.next_wagon > #group.wagons then
		group.next_wagon = 1
	end
end

local function process_group(group, temp_inventory)
	if group.container == nil or not group.container.valid then
		return false
	end

	remove_invalid_wagons(group)
	if #group.wagons == 0 then
		return false
	end

	local container_inventory = group.container.get_inventory(defines.inventory.chest)
	if container_inventory == nil then
		return false
	end

	local remaining = train_transfer.items_per_container_cycle
	while remaining > 0 do
		local moved = 0
		local attempts = #group.wagons

		for _ = 1, attempts do
			local wagon = group.wagons[group.next_wagon]
			group.next_wagon = (group.next_wagon % #group.wagons) + 1

			local wagon_inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
			local source_inventory = group.mode == train_transfer.modes.load and container_inventory or wagon_inventory
			local target_inventory = group.mode == train_transfer.modes.load and wagon_inventory or container_inventory
			moved = transfer_from_inventory(source_inventory, target_inventory, group, temp_inventory, remaining)
			if moved > 0 then
				break
			end
		end

		if moved == 0 then
			break
		end
		remaining = remaining - moved
	end

	return true
end

function train_transfer.on_nth_tick()
	local data = ensure_storage()
	local train_ids_to_stop = {}
	local temp_inventory = game.create_inventory(1)

	for train_id, active in pairs(data.active_trains) do
		if active.train == nil or not active.train.valid or active.train.state ~= defines.train_state.wait_station then
			table.insert(train_ids_to_stop, train_id)
		else
			local groups = {}
			for _, group in ipairs(active.groups or {}) do
				if process_group(group, temp_inventory) then
					table.insert(groups, group)
				end
			end

			active.groups = groups
			if #active.groups == 0 then
				table.insert(train_ids_to_stop, train_id)
			end
		end
	end

	temp_inventory.destroy()

	for _, train_id in ipairs(train_ids_to_stop) do
		stop_active_train(data, train_id)
	end
end

local function on_train_changed_state(event)
	local data = ensure_storage()
	if event.train and event.train.valid then
		stop_active_train(data, event.train.id)
		start_train_transfer(event.train)
	end
end

local function on_train_created(event)
	local data = ensure_storage()
	if event.old_train_id_1 then
		stop_active_train(data, event.old_train_id_1)
	end
	if event.old_train_id_2 then
		stop_active_train(data, event.old_train_id_2)
	end
	if event.train and event.train.valid then
		start_train_transfer(event.train)
	end
end

local function on_object_destroyed(event)
	local data = ensure_storage()
	local record = data.destroyed_registrations[event.registration_number]
	if record == nil then
		return
	end

	data.destroyed_registrations[event.registration_number] = nil
	if record.kind == 'container' then
		cleanup_container(data, record.unit_number)
	elseif record.kind == 'train' then
		stop_active_train(data, record.train_id)
	elseif record.kind == 'wagon' then
		remove_wagon_from_active_train(data, record.train_id, record.unit_number)
	end
end

local function cleanup_invalid_active_trains()
	local data = ensure_storage()
	local train_ids_to_stop = {}
	for train_id, active in pairs(data.active_trains) do
		if active.train == nil or not active.train.valid or active.train.state ~= defines.train_state.wait_station then
			table.insert(train_ids_to_stop, train_id)
		end
	end
	for _, train_id in ipairs(train_ids_to_stop) do
		stop_active_train(data, train_id)
	end
end

local function cleanup_invalid_cybersyn2_shims()
	local data = ensure_storage()
	for unit_number, shim_group in pairs(data.cybersyn2_shims) do
		if shim_group.container == nil or not shim_group.container.valid then
			destroy_cybersyn2_shims(data, unit_number, false)
		end
	end
end

local function rebuild_all_cybersyn2_shims()
	local data = ensure_storage()
	local unit_numbers = {}
	for unit_number, _ in pairs(data.cybersyn2_shims) do
		table.insert(unit_numbers, unit_number)
	end
	for _, unit_number in ipairs(unit_numbers) do
		destroy_cybersyn2_shims(data, unit_number, true)
	end

	local train_container_names = get_train_container_names()
	if #train_container_names == 0 then
		return
	end

	for _, surface in pairs(game.surfaces) do
		for _, container in ipairs(surface.find_entities_filtered({ name = train_container_names })) do
			if container.valid and container.unit_number ~= nil and data.modes[container.unit_number] ~= nil then
				register_container(data, container)
				rebuild_cybersyn2_shims(data, container)
			end
		end
	end
end

script.on_init(function()
	ensure_storage()
	update_nth_tick_handler()
end)

script.on_configuration_changed(function()
	ensure_storage()
	cleanup_invalid_cybersyn2_shims()
	rebuild_all_cybersyn2_shims()
	cleanup_invalid_active_trains()
	update_nth_tick_handler()
end)

script.on_load(function()
	local data = storage.train_transfer
	set_nth_tick_handler(data ~= nil and (data.active_transfer_count or 0) > 0)
end)

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_train_created, on_train_created)
script.on_event(defines.events.on_object_destroyed, on_object_destroyed)
script.on_event(defines.events.on_surface_deleted, function()
	cleanup_invalid_active_trains()
	cleanup_invalid_cybersyn2_shims()
end)
script.on_event(defines.events.on_surface_cleared, function()
	cleanup_invalid_active_trains()
	cleanup_invalid_cybersyn2_shims()
end)

return train_transfer
