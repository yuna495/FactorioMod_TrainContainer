-- Engine-driven blinking; only status detection is sampled once per second.
local lamps = {}
local interval = 60
local colors = {
	green = { 0.12, 1, 0.18, 1 },
	yellow = { 1, 0.65, 0.04, 1 },
	red = { 1, 0.06, 0.025, 1 } -- Reserved for future errors; never used by normal states.
}

local function state()
	storage.train_status_lamps = storage.train_status_lamps or { entities = {}, registrations = {}, count = 0 }
	return storage.train_status_lamps
end

local function set_display(record, color, blinking)
	local blink_interval = blinking and 30 or 0
	if record.color == color and record.blink_interval == blink_interval then return end
	for _, object in ipairs(record.objects) do
		if object.valid then
			object.color = colors[color]
			object.blink_interval = blink_interval
		end
	end
	record.color = color
	record.blink_interval = blink_interval
end

local function refresh_record(record)
	local transfer = MergingChests.train_transfer
	if transfer.get_mode(record.entity) == 'off' then
		-- Do not carry activity across disabling/re-enabling direct transfer.
		record.last_transfer_tick = nil
		set_display(record, 'yellow', false)
		return
	end
	local active = record.last_transfer_tick and game.tick - record.last_transfer_tick < interval
	if active then
		set_display(record, 'green', true)
		return
	end
	local adjacent = transfer.has_adjacent_wagon(record.entity)
	set_display(record, adjacent and 'yellow' or 'green', adjacent)
end

function lamps.refresh(entity)
	if not entity or not entity.valid then return end
	local data = storage.train_status_lamps
	local record = data and data.entities[entity.unit_number]
	if record then refresh_record(record) end
end

local function update_handler()
	local data = storage.train_status_lamps
	script.on_nth_tick(interval, data and data.count > 0 and lamps.update or nil)
end

local function remove(unit_number)
	local data = state()
	local record = data.entities[unit_number]
	if not record then return end
	for _, object in ipairs(record.objects) do
		if object.valid then object.destroy() end
	end
	data.registrations[record.registration] = nil
	data.entities[unit_number] = nil
	data.count = data.count - 1
	update_handler()
end

function lamps.register(entity)
	if not entity or not entity.valid or not entity.unit_number then return end
	local chest, width, height = MergingChests.get_merged_chest_info(entity.name)
	if chest ~= MergingChests.chest_names.steel and chest ~= MergingChests.chest_names.infinity then return end
	local length = math.max(width, height)
	-- Only J modules have a beacon. End-cap yellow tabs remain safety markings.
	if math.min(width, height) ~= 1 or length < 13 or (length + 1) % 7 ~= 0 then return end
	local data = state()
	if data.entities[entity.unit_number] then return end
	local record = { entity = entity, objects = {}, registration = script.register_on_object_destroyed(entity) }
	local vertical = width == 1
	for i = 0, (length + 1) / 7 - 2 do
		local position = -length / 2 + i * 7 + 6.5
		table.insert(record.objects, rendering.draw_sprite({
			sprite = 'train-container-status-lamp-'..(vertical and 'high' or 'wide'),
			target = { entity = entity, offset = vertical and { 0, position } or { position, 0 } },
			surface = entity.surface,
			tint = colors.yellow,
			blink_interval = 0,
			render_layer = 'higher-object-above',
		}))
	end
	data.entities[entity.unit_number] = record
	data.registrations[record.registration] = entity.unit_number
	data.count = data.count + 1
	refresh_record(record)
	update_handler()
end

function lamps.note_transfer(entity)
	local data = storage.train_status_lamps
	local record = data and data.entities[entity.unit_number]
	if record then
		record.last_transfer_tick = game.tick
		set_display(record, 'green', true)
	end
end

function lamps.update()
	local data = state()
	local invalid = {}
	local recreate = {}
	for unit_number, record in pairs(data.entities) do
		if record.entity.valid then
			local intact = true
			for _, object in ipairs(record.objects) do intact = intact and object.valid end
			if intact then
				refresh_record(record)
			else
				-- The engine destroys entity-targeted drawings on surface changes.
				table.insert(invalid, unit_number)
				table.insert(recreate, record.entity)
			end
		else table.insert(invalid, unit_number) end
	end
	for _, unit_number in ipairs(invalid) do remove(unit_number) end
	for _, entity in ipairs(recreate) do lamps.register(entity) end
end

function lamps.on_object_destroyed(event)
	local data = storage.train_status_lamps
	local unit_number = data and data.registrations[event.registration_number]
	if unit_number then remove(unit_number) end
end

function lamps.rebuild()
	local old = storage.train_status_lamps
	if old then
		for _, record in pairs(old.entities) do
			for _, object in ipairs(record.objects) do
				if object.valid then object.destroy() end
			end
		end
	end
	storage.train_status_lamps = nil
	state()
	for _, surface in pairs(game.surfaces) do
		for _, entity in ipairs(surface.find_entities_filtered({ type = { 'container', 'infinity-container' } })) do
			lamps.register(entity)
		end
	end
	update_handler()
end

lamps.on_load = update_handler
script.on_event({ defines.events.on_built_entity, defines.events.on_robot_built_entity,
	defines.events.script_raised_built, defines.events.script_raised_revive }, function(event)
	lamps.register(event.entity)
end)
script.on_event(defines.events.on_entity_cloned, function(event) lamps.register(event.destination) end)
return lamps
