-- Run from the repository root with Lua 5.2+. Real transfer/group code with
-- inventory doubles that enforce capacity, per-slot filters, quality and bars.
local configuration = require('scripts.train_filter_configuration')
prototypes = { item = {}, quality = { normal = {}, rare = {}, epic = {} }, entity = { container = {} } }
for _, name in ipairs({ 'iron', 'copper', 'steel', 'stone', 'chip', 'other' }) do
	prototypes.item[name] = { stack_size = 100 }
end
local function filter(name, quality) return { name = name, quality = quality or 'normal' } end
local function stack(name, quality) return { name = name, quality = { name = quality or 'normal' } } end
for _, mode in ipairs({ 'whitelist', 'blacklist' }) do
	assert(configuration.matches(stack('other'), { mode = mode, slots = {} }))
	local c = { mode = mode, slots = { filter('iron') } }
	assert(configuration.matches(stack('iron'), c) == (mode == 'whitelist'))
	assert(configuration.matches(stack('copper'), c) == (mode == 'blacklist'))
	assert(configuration.matches(stack('iron', 'rare'), c) == (mode == 'blacklist'))
	c.slots = { filter('iron'), filter('copper'), filter('steel'), filter('stone'), filter('chip', 'rare') }
	for _, f in ipairs(c.slots) do assert(configuration.matches(stack(f.name, f.quality), c) == (mode == 'whitelist')) end
	c.slots = { [1] = filter('iron'), [3] = filter('copper'), [5] = filter('chip', 'rare') }
	assert(configuration.matches(stack('chip', 'rare'), c) == (mode == 'whitelist'))
	c.slots[3] = filter('iron'); c.slots[5] = filter('iron')
	assert(configuration.matches(stack('iron'), c) == (mode == 'whitelist'))
end
local legacy = configuration.normalize(filter('chip', 'rare'))
assert(legacy.mode == 'whitelist' and legacy.slots[1].quality == 'rare' and legacy.slots[2] == nil)
assert(configuration.normalize('iron').slots[1].quality == 'normal')
assert(configuration.normalize(filter('missing')).slots[1] == nil)
assert(configuration.normalize(filter('iron', 'missing')).slots[1].quality == 'normal')

local events, lifecycle, periodic = {}, {}, {}
defines = { events = {}, train_state = { wait_station = 1 }, inventory = { chest = 1, cargo_wagon = 2 } }
for i, name in ipairs({ 'on_train_changed_state', 'on_train_created', 'on_object_destroyed', 'on_surface_deleted', 'on_surface_cleared' }) do
	defines.events[name] = i
end
local next_registration = 0
script = {
	on_event = function(event, handler) events[event] = handler end,
	on_init = function(handler) lifecycle.init = handler end,
	on_configuration_changed = function(handler) lifecycle.configuration = handler end,
	on_load = function(handler) lifecycle.load = handler end,
	on_nth_tick = function(tick, handler) periodic[tick] = handler end,
	register_on_object_destroyed = function(object)
		if not object.registration then next_registration = next_registration + 1; object.registration = next_registration end
		return object.registration
	end
}
local successful_notifications = 0
package.loaded['scripts.train_status_lamps'] = {
	rebuild = function() end, on_load = function() end, on_object_destroyed = function() end,
	refresh = function() end, note_transfer = function() successful_notifications = successful_notifications + 1 end
}
MergingChests = {
	chest_names = { steel = 'steel-chest', infinity = 'infinity' },
	get_merged_chest_info = function(name) if name == 'container' then return 'steel-chest', 13, 1 end end
}
local transfer = require('scripts.train_transfer')

local function inventory(entries, size, options)
	options = options or {}
	local inv = {}
	local function eligible(i, source)
		local f = options.filters and options.filters[i]
		return not options.reject and i < (options.bar or size + 1)
			and (not f or (f.name == source.name and f.quality == source.quality.name))
	end
	for i = 1, size do
		local entry = entries[i]
		local slot = { valid_for_read = entry ~= nil, count = entry and entry.count or 0 }
		if entry then
			slot.name, slot.quality = entry.name, { name = entry.quality or 'normal' }
			slot.prototype, slot.metadata = prototypes.item[entry.name], entry.metadata
		end
		slot.transfer_stack = function(source, amount)
			if not eligible(i, source) then return false end
			if slot.valid_for_read and (slot.name ~= source.name or slot.quality.name ~= source.quality.name
				or slot.metadata ~= source.metadata) then return false end
			local moved = math.min(amount, source.count, 100 - slot.count)
			if moved <= 0 then return false end
			slot.name, slot.quality, slot.prototype, slot.metadata = source.name, source.quality, source.prototype, source.metadata
			slot.count, slot.valid_for_read = slot.count + moved, true
			source.count = source.count - moved
			source.valid_for_read = source.count > 0
			return true
		end
		inv[i] = slot
	end
	inv.supports_bar = function() return true end
	inv.get_bar = function() return options.bar or size + 1 end
	inv.can_insert = function(source)
		for i, slot in ipairs(inv) do
			if eligible(i, source) and (not slot.valid_for_read or
				(slot.name == source.name and slot.quality.name == source.quality.name and slot.count < 100)) then return true end
		end
		return false
	end
	return inv
end
local function total(inv)
	local count = 0
	for _, slot in ipairs(inv) do count = count + slot.count end
	return count
end
local function setup(mode, entries, destination_options, wagon_count)
	storage = {}
	game = { tick = 0, surfaces = {} }
	lifecycle.init()
	local source = inventory(entries, math.max(#entries, 1))
	local target = inventory({}, 10, destination_options)
	local train = { id = 50, valid = true, state = 1, station = {}, cargo_wagons = {} }
	local surface = {}
	local container = { name = 'container', unit_number = 1, valid = true, position = { x = 0, y = 0 }, surface = surface,
		selection_box = { left_top = { x = -6.5, y = -.5 }, right_bottom = { x = 6.5, y = .5 } },
		get_inventory = function() return mode == 'load' and source or target end }
	for i = 1, wagon_count or 1 do
		local inv = i == 1 and (mode == 'load' and target or source) or inventory({}, 10)
		train.cargo_wagons[i] = { name = 'cargo-wagon', type = 'cargo-wagon', valid = true, unit_number = 10 + i,
			position = { x = 0, y = 1.5 }, surface = surface, train = train,
			selection_box = { left_top = { x = -3, y = .5 }, right_bottom = { x = 3, y = 2.5 } },
			get_inventory = function() return inv end }
	end
	surface.find_entities_filtered = function(query)
		if query.name then return { container } end
		if query.type == 'cargo-wagon' then return train.cargo_wagons end
		return {}
	end
	game.surfaces = { surface }
	return container, train, source, target
end
local function cycle(tick) game.tick = tick; transfer.on_nth_tick() end
local entries = { { name = 'iron', count = 10 }, { name = 'iron', quality = 'rare', count = 20, metadata = 'retained' },
	{ name = 'copper', count = 30 } }
for _, direction in ipairs({ 'load', 'unload' }) do
	for _, mode in ipairs({ 'whitelist', 'blacklist' }) do
		local c, train, source, target = setup(direction, entries)
		transfer.set_filter(c, 3, filter('iron', 'rare'))
		transfer.set_filter_mode(c, mode)
		assert(transfer.get_mode(c) == 'off')
		transfer.set_mode(c, direction)
		cycle(10)
		assert(total(target) == (mode == 'whitelist' and 20 or 40))
		assert(total(source) + total(target) == 60)
		if mode == 'whitelist' then assert(target[1].quality.name == 'rare' and target[1].metadata == 'retained') end
		transfer.set_mode(c, 'off')
		assert(transfer.get_filter_mode(c) == mode and transfer.get_filter_configuration(c).slots[3].quality == 'rare')
	end
end

local c, train, source, target = setup('load', entries)
transfer.set_filter(c, 1, filter('stone')); transfer.set_mode(c, 'load'); cycle(10)
local old = storage.train_transfer.active_trains[50].groups[1]
assert(old.retry_after_tick == 70 and total(target) == 0)
transfer.set_filter(c, 1, filter('iron', 'rare'))
local new = storage.train_transfer.active_trains[50].groups[1]
assert(new ~= old and new.retry_after_tick == nil and new.filter_configuration.slots[1].name == 'iron')
local returned = transfer.get_filter_configuration(c); returned.slots[1].name = 'stone'
assert(new.filter_configuration.slots[1].name == 'iron')
cycle(20); assert(total(target) == 20)
transfer.set_filter_mode(c, 'blacklist')
assert(storage.train_transfer.active_trains[50].groups[1] ~= new)
cycle(30); assert(total(target) == 60)
assert(not transfer.set_filter(c, 6, filter('iron')) and not transfer.set_filter_mode(c, 'invalid'))
events[defines.events.on_object_destroyed]({ registration_number = c.registration })
assert(storage.train_transfer.filters[1] == nil and storage.train_transfer.modes[1] == nil)

-- Upgrade both persistent entity configuration and in-flight legacy snapshots.
c, train, source, target = setup('load', entries)
transfer.set_mode(c, 'load')
local data = storage.train_transfer
data.filters[1] = filter('iron', 'rare'); data.filters[2] = 'copper'; data.filter_schema_version = 2
local group = data.active_trains[50].groups[1]
group.filter = data.filters[1]; group.filter_configuration = nil; group.retry_after_tick = 1000
lifecycle.configuration()
assert(data.filter_schema_version == 3 and data.filters[1].mode == 'whitelist')
assert(data.filters[1].slots[1].quality == 'rare' and data.filters[2].slots[1].quality == 'normal')
assert(group.filter == nil and group.filter_configuration.slots[1].name == 'iron' and group.retry_after_tick == nil)
cycle(10); assert(total(target) == 20)

-- Existing rate, bar/filter safety, rejection safety, retry and round robin.
local bulk = {}; for i = 1, 8 do bulk[i] = { name = 'iron', count = 100 } end
c, train, source, target = setup('load', bulk); transfer.set_mode(c, 'load'); cycle(10)
assert(total(target) == 500 and total(source) == 300)
c, train, source, target = setup('load', entries, { bar = 2, filters = { [1] = filter('iron', 'rare') } })
transfer.set_mode(c, 'load'); cycle(10)
assert(total(target) == 20 and target[2].count == 0 and total(source) == 40)
c, train, source, target = setup('load', entries, { reject = true })
transfer.set_mode(c, 'load'); cycle(10); assert(total(source) == 60 and total(target) == 0)
assert(storage.train_transfer.active_trains[50].groups[1].retry_after_tick == 70)
cycle(20); assert(total(target) == 0)
c, train, source, target = setup('load', bulk, nil, 2)
transfer.set_mode(c, 'load'); cycle(10)
assert(total(target) == 300 and total(train.cargo_wagons[2].get_inventory()) == 200)
c, train, source, target = setup('load', entries)
train.state = 2; transfer.set_mode(c, 'load'); cycle(10); assert(total(target) == 0)
assert(successful_notifications > 0)
print('PASS: 5-slot allow/deny semantics, sparse/duplicate/quality filters, migration, group refresh, OFF/removal, both directions, safety/rate/retry/round robin.')
