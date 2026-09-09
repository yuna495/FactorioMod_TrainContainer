-- Lua 5.2+; lifecycle/status logic independent of a running Factorio instance.
storage = {}
game = { tick = 0, surfaces = {} }
local handlers, periodic, objects = {}, {}, {}
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
	options.valid = true
	options.destroy = function() options.valid = false end
	table.insert(objects, options)
	return options
end }
MergingChests = {
	chest_names = { steel = 'steel-chest', infinity = 'infinity' },
	get_merged_chest_info = function(name)
		local width, height = name:match('^(%d+)x(%d+)$')
		if width then return 'steel-chest', tonumber(width), tonumber(height) end
	end,
	train_transfer = { has_adjacent_wagon = function(entity) return entity.adjacent or false end }
}
local lamps = require('scripts.train_status_lamps')
local function entity(id, name)
	return { unit_number = id, name = name, valid = true, surface = {} }
end
local a = entity(1, '13x1')
handlers[1]({ entity = a })
assert(storage.train_status_lamps.count == 1 and #objects == 1 and periodic[60])
assert(objects[1].blink_interval == 30 and objects[1].target.entity == a)
assert(storage.train_status_lamps.entities[1].color == 'green')
lamps.register(a)
assert(#objects == 1, 'Duplicate construction notification duplicated a lamp')
a.adjacent = true
game.tick = 60; periodic[60]()
assert(storage.train_status_lamps.entities[1].color == 'yellow')
lamps.note_transfer(a)
assert(storage.train_status_lamps.entities[1].color == 'red')
game.tick = 90; lamps.note_transfer(a)
game.tick = 120; periodic[60]()
assert(storage.train_status_lamps.entities[1].color == 'red')
game.tick = 180; periodic[60]()
assert(storage.train_status_lamps.entities[1].color == 'yellow', 'Activity did not expire')
a.adjacent = false
game.tick = 240; periodic[60]()
assert(storage.train_status_lamps.entities[1].color == 'green')
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
print('PASS: lamp colors, activity timeout, duplicate events, clone, reload, rebuild, deletion, surface change, idle handler.')
