-- Engine-driven blinking; only status detection is sampled once per second.
local lamps = {}
local interval = 60
local colors = {
	green = { 0.12, 1, 0.18, 1 },
	yellow = { 1, 0.65, 0.04, 1 },
	red = { 1, 0.06, 0.025, 1 }
}

local function state()
	storage.train_status_lamps = storage.train_status_lamps or { entities = {}, registrations = {}, count = 0 }
	return storage.train_status_lamps
end

local function set_color(record, color)
	if record.color == color then return end
	for _, object in ipairs(record.objects) do
		if object.valid then object.color = colors[color] end
	end
	record.color = color
end

local function refresh(record)
	local adjacent = MergingChests.train_transfer.has_adjacent_wagon(record.entity)
	local active = record.last_transfer_tick and game.tick - record.last_transfer_tick < interval
	set_color(record, adjacent and (active and 'red' or 'yellow') or 'green')
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
			tint = colors.green,
			blink_interval = 30,
			render_layer = 'higher-object-above',
		}))
	end
	data.entities[entity.unit_number] = record
	data.registrations[record.registration] = entity.unit_number
	data.count = data.count + 1
	refresh(record)
	update_handler()
end

function lamps.note_transfer(entity)
	local data = storage.train_status_lamps
	local record = data and data.entities[entity.unit_number]
	if record then
		record.last_transfer_tick = game.tick
		set_color(record, 'red')
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
				refresh(record)
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
