-- Lua 5.2+; lifecycle/status logic independent of a running Factorio instance.
storage = {}
game = { tick = 0, surfaces = {} }
local handlers, periodic, objects = {}, {}, {}
local adjacency_checks, property_writes = 0, 0
defines = { events = { on_built_entity = 1, on_robot_built_entity = 2,
	script_raised_built = 3, script_raised_revive = 4, on_entity_cloned = 5 } }
script = {
	on_event = function(events, handler)
		if type(events) ~= 'table' then events = { events } end
		for _, event in ipairs(events) do handlers[event] = handler end
	end,
	on_nth_tick = function(tick, handler) periodic[tick] = handler end,
	register_on_object_destroyed = function(entity) return entity.unit_number end
}
rendering = { draw_sprite = function(options)
	local properties = { valid = true, color = options.tint, blink_interval = options.blink_interval,
		target = options.target, sprite = options.sprite }
	properties.destroy = function() properties.valid = false end
	local object = setmetatable({}, {
		__index = properties,
		__newindex = function(_, key, value)
			assert(key == 'color' or key == 'blink_interval' or key == 'valid', 'Invalid render property: '..key)
			property_writes = property_writes + 1
			properties[key] = value
		end
	})
	table.insert(objects, object)
	return object
end }
MergingChests = {
	chest_names = { steel = 'steel-chest', infinity = 'infinity' },
	get_merged_chest_info = function(name)
		local width, height = name:match('^(%d+)x(%d+)$')
		if width then return 'steel-chest', tonumber(width), tonumber(height) end
	end,
	train_transfer = {
		get_mode = function(entity) return entity.mode or 'off' end,
		has_adjacent_wagon = function(entity)
			adjacency_checks = adjacency_checks + 1
			assert(entity.mode ~= 'off' and entity.mode ~= nil, 'OFF lamp must not scan wagons')
			return entity.adjacent or false
		end
	}
}
local lamps = require('scripts.train_status_lamps')
local function entity(id, name)
	return { unit_number = id, name = name, valid = true, surface = {} }
end
local a = entity(1, '13x1')
local function expect(target, color, blinking)
	local record = storage.train_status_lamps.entities[target.unit_number]
	assert(record.color == color, 'Unexpected lamp color')
	assert(record.blink_interval == (blinking and 30 or 0), 'Unexpected blink state')
	for _, object in ipairs(record.objects) do
		assert(object.blink_interval == record.blink_interval)
		local expected = color == 'green' and { .12, 1, .18, 1 } or { 1, .65, .04, 1 }
		for i = 1, 4 do assert(object.color[i] == expected[i], 'Actual render tint mismatch') end
	end
end
handlers[1]({ entity = a })
assert(storage.train_status_lamps.count == 1 and #objects == 1 and periodic[60])
assert(objects[1].target.entity == a)
expect(a, 'yellow', false)
periodic[60]()
assert(adjacency_checks == 0)
lamps.register(a)
assert(#objects == 1, 'Duplicate construction notification duplicated a lamp')
a.mode = 'load'; lamps.refresh(a)
expect(a, 'green', false)
a.adjacent = true
game.tick = 60; periodic[60]()
expect(a, 'yellow', true)
lamps.note_transfer(a)
expect(a, 'green', true)
game.tick = 90; lamps.note_transfer(a)
game.tick = 120; periodic[60]()
expect(a, 'green', true)
game.tick = 180; periodic[60]()
expect(a, 'yellow', true)
lamps.note_transfer(a)
a.adjacent = false
game.tick = 240; periodic[60]()
expect(a, 'green', false)
local writes = property_writes
lamps.refresh(a)
assert(property_writes == writes, 'Unchanged display rewrote rendering properties')
assert(#objects == 1, 'State transitions recreated the render object')
lamps.note_transfer(a)
local scans = adjacency_checks
a.mode = 'off'; lamps.refresh(a)
expect(a, 'yellow', false)
assert(adjacency_checks == scans)
a.adjacent = true; a.mode = 'load'; lamps.refresh(a)
expect(a, 'yellow', true) -- OFF discarded the earlier successful-transfer timestamp.
a.mode = 'unload'; lamps.refresh(a); lamps.note_transfer(a)
expect(a, 'green', true)
a.mode = 'off'; lamps.refresh(a)
expect(a, 'yellow', false)
local b = entity(2, '1x20')
handlers[5]({ destination = b })
assert(#storage.train_status_lamps.entities[2].objects == 2)
assert(storage.train_status_lamps.entities[2].objects[1].target.offset[2] == -3.5)
lamps.register(entity(3, '6x1')); lamps.register(entity(4, '12x1')); lamps.register(entity(5, 'steel-chest'))
assert(storage.train_status_lamps.count == 2)
lamps.on_load()
assert(storage.train_status_lamps.count == 2 and #objects == 3)
objects[1].valid = false -- Engine invalidates drawings on cross-surface teleport.
lamps.update()
assert(storage.train_status_lamps.entities[1].objects[1].valid)
lamps.on_object_destroyed({ registration_number = 1 })
assert(storage.train_status_lamps.count == 1)
b.valid = false; lamps.update()
assert(storage.train_status_lamps.count == 0 and periodic[60] == nil)
game.surfaces = { { find_entities_filtered = function() return { a } end } }
lamps.rebuild(); lamps.rebuild()
assert(storage.train_status_lamps.count == 1)
local valid = 0
for _, object in ipairs(objects) do if object.valid then valid = valid + 1 end end
assert(valid == 1, 'Rebuild leaked drawings')

-- Exercise the real set_mode entry point, not a test-only mode setter.
script.on_init = function() end
script.on_configuration_changed = function() end
script.on_load = function() end
for index, event in ipairs({ 'on_train_changed_state', 'on_train_created', 'on_object_destroyed',
	'on_surface_deleted', 'on_surface_cleared' }) do defines.events[event] = index + 5 end
prototypes = { entity = {} }
local transfer = require('scripts.train_transfer')
local previous_adjacency = MergingChests.train_transfer.has_adjacent_wagon
transfer.has_adjacent_wagon = function(target)
	adjacency_checks = adjacency_checks + 1
	assert(transfer.get_mode(target) ~= 'off')
	return target.adjacent or false
end
a.surface = { find_entities_filtered = function() return {} end }
a.selection_box = { left_top = { x = -6.5, y = -.5 }, right_bottom = { x = 6.5, y = .5 } }
a.adjacent = false
assert(transfer.set_mode(a, 'load')); expect(a, 'green', false)
lamps.note_transfer(a); expect(a, 'green', true)
scans = adjacency_checks
assert(transfer.set_mode(a, 'off')); expect(a, 'yellow', false)
assert(adjacency_checks == scans, 'set_mode OFF triggered a lamp adjacency scan')
a.adjacent = true
assert(transfer.set_mode(a, 'load')); expect(a, 'yellow', true)
scans = adjacency_checks
assert(transfer.set_mode(a, 'off')); expect(a, 'yellow', false)
assert(adjacency_checks == scans)
assert(transfer.set_mode(a, 'load')); expect(a, 'yellow', true)
assert(transfer.set_mode(a, 'unload')); expect(a, 'yellow', true)
lamps.note_transfer(a); expect(a, 'green', true)
assert(transfer.set_mode(a, 'off')); expect(a, 'yellow', false)
transfer.has_adjacent_wagon = previous_adjacency
print('PASS: four display states, OFF scan avoidance, actual set_mode immediate refresh, transfer timeout, lifecycle, no redraws, empty registry handler.')
