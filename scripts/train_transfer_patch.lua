local train_transfer = require('scripts.train_transfer')

local retry_delay_ticks = 60

local function is_train_ready_for_transfer(train)
	return train ~= nil
		and train.valid
		and train.state == defines.train_state.wait_station
		and train.station ~= nil
end

local function stack_matches_filter(stack, filter)
	if filter == nil then
		return true
	end
	return stack.name == filter.name and stack.quality and stack.quality.name == filter.quality
end

local function get_transferable_slot_count(inventory)
	if inventory.supports_bar and inventory.supports_bar() then
		return math.min(#inventory, inventory.get_bar() - 1)
	end
	return #inventory
end

local function transfer_to_inventory(source_stack, target_inventory, limit)
	-- Factorio performs this check in native code. If the destination cannot
	-- accept any part of this stack, avoid scanning every destination slot in Lua.
	if not target_inventory.can_insert(source_stack) then
		return 0
	end

	local target_slot_count = get_transferable_slot_count(target_inventory)
	for target_index = 1, target_slot_count do
		local target_stack = target_inventory[target_index]
		local before_count = source_stack.count
		local target_space = source_stack.prototype.stack_size
		if target_stack.valid_for_read then
			target_space = math.max(target_stack.prototype.stack_size - target_stack.count, 0)
		end
		local amount = math.min(before_count, limit, target_space)
		if amount > 0 and target_stack.transfer_stack(source_stack, amount) then
			return before_count - (source_stack.valid_for_read and source_stack.count or 0)
		end
	end
	return 0
end

local function transfer_from_inventory(source_inventory, target_inventory, group, limit)
	if source_inventory == nil or target_inventory == nil or #source_inventory == 0 or limit <= 0 then
		return 0
	end

	local start_slot = group.source_slot or 1
	for offset = 0, #source_inventory - 1 do
		local index = ((start_slot + offset - 2) % #source_inventory) + 1
		local source_stack = source_inventory[index]
		if source_stack.valid_for_read and stack_matches_filter(source_stack, group.filter) then
			local moved = transfer_to_inventory(source_stack, target_inventory, limit)
			if moved > 0 then
				if source_stack.valid_for_read then
					group.source_slot = index
				else
					group.source_slot = (index % #source_inventory) + 1
				end
				return moved
			end
		end
	end

	return 0
end

local function remove_invalid_wagons(group)
	local wagons = {}
	for _, wagon in ipairs(group.wagons or {}) do
		if wagon.valid and is_train_ready_for_transfer(wagon.train) then
			table.insert(wagons, wagon)
		end
	end

	group.wagons = wagons
	if group.next_wagon > #group.wagons then
		group.next_wagon = 1
	end
end

local function process_group(group)
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

	if group.retry_after_tick and game.tick < group.retry_after_tick then
		return true
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
			moved = transfer_from_inventory(source_inventory, target_inventory, group, remaining)
			if moved > 0 then
				break
			end
		end

		if moved == 0 then
			-- A full or otherwise incompatible destination used to be rescanned every
			-- 10 ticks. Back off for one second while the train remains stopped.
			group.retry_after_tick = game.tick + retry_delay_ticks
			break
		end

		group.retry_after_tick = nil
		remaining = remaining - moved
	end

	return true
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
end

local function optimized_on_nth_tick()
	local data = storage.train_transfer
	if data == nil then
		return
	end

	local train_ids_to_stop = {}

	for train_id, active in pairs(data.active_trains or {}) do
		if not is_train_ready_for_transfer(active.train) then
			table.insert(train_ids_to_stop, train_id)
		else
			local groups = {}
			for _, group in ipairs(active.groups or {}) do
				if process_group(group) then
					table.insert(groups, group)
				end
			end

			active.groups = groups
			if #active.groups == 0 then
				table.insert(train_ids_to_stop, train_id)
			end
		end
	end

	for _, train_id in ipairs(train_ids_to_stop) do
		stop_active_train(data, train_id)
	end

	if (data.active_transfer_count or 0) == 0 then
		script.on_nth_tick(train_transfer.nth_tick, nil)
	end
end

-- Replace the original periodic handler. The original train state event handlers
-- continue to manage active groups and will register this function on future
-- state changes because they read train_transfer.on_nth_tick dynamically.
train_transfer.on_nth_tick = optimized_on_nth_tick

local data = storage.train_transfer
script.on_nth_tick(
	train_transfer.nth_tick,
	data ~= nil and (data.active_transfer_count or 0) > 0 and optimized_on_nth_tick or nil
)

return train_transfer
