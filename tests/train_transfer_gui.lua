-- GUI event tests: native controls, immediate edits and two-player synchronization.
local configuration = require('scripts.train_filter_configuration')
prototypes = { item = { iron = {}, copper = {} }, quality = { normal = {}, rare = {} } }
storage = { train_transfer = { players = {} } }
local events = {}
defines = { events = {}, relative_gui_type = { container_gui = 1 }, relative_gui_position = { left = 1 } }
for i, name in ipairs({ 'on_gui_opened', 'on_gui_closed', 'on_gui_selection_state_changed',
	'on_gui_elem_changed', 'on_gui_switch_state_changed', 'on_selected_entity_changed' }) do defines.events[name] = i end
script = { on_event = function(event, handler) events[event] = handler end }
local function node(options, parent)
	local element = { valid = true, style = {}, children = {}, parent = parent }
	for k, v in pairs(options) do if k ~= 'style' then element[k] = v end end
	element.style_name = options.style
	element.elem_value = options['item-with-quality']
	element.add = function(child_options)
		local child = node(child_options, element)
		element.children[#element.children + 1] = child
		if child.name then element[child.name] = child end
		return child
	end
	element.destroy = function()
		element.valid = false
		for _, child in ipairs(element.children) do child.destroy() end
		if parent and element.name then parent[element.name] = nil end
	end
	return element
end
local players = {}
for i = 1, 2 do players[i] = { index = i, gui = { left = node({}), relative = node({}) } } end
game = { get_player = function(index) return players[index] end }
local config = configuration.normalize(nil)
local writes = 0
local transfer = {
	modes = { off = 'off', load = 'load', unload = 'unload' }, filter_slot_count = 5,
	get_mode = function() return 'off' end,
	get_status = function() return 'off', 0 end,
	get_wagon_search_areas = function() return {} end,
	get_filter_configuration = function() return configuration.normalize(config) end,
	set_filter = function(_, slot, filter) config.slots[slot] = configuration.normalize_slot(filter); writes = writes + 1 end,
	set_filter_mode = function(_, mode) config.mode = mode; writes = writes + 1 end
}
package.loaded['scripts.train_transfer'] = transfer
MergingChests = { chest_names = { steel = 'steel', infinity = 'infinity' },
	prefix_with_modname = function(name) return 'train-container-'..name end,
	get_merged_chest_info = function(name) if name == 'container' then return 'steel', 13, 1 end end }
require('scripts.event_handlers.train_transfer_gui')
local entity = { valid = true, name = 'container', unit_number = 1 }
local prefix = 'train-container-direct-transfer-'
local function panel(index) return players[index].gui.relative[prefix..'frame'][prefix..'filter-flow'] end
local function slot(index, number) return panel(index)[prefix..'filter-slots'][prefix..'filter-'..number] end
local function emit(name, index, element)
	events[defines.events[name]]({ player_index = index, element = element, entity = entity })
end
local legacy = players[1].gui.left.add({ type = 'frame', name = prefix..'frame' })
emit('on_gui_opened', 1); emit('on_gui_opened', 2)
assert(not legacy.valid and players[1].gui.left[prefix..'frame'] == nil)
local anchor = players[1].gui.relative[prefix..'frame'].anchor
assert(anchor.gui == defines.relative_gui_type.container_gui and anchor.position == defines.relative_gui_position.left)
assert(anchor.name == entity.name)
assert(panel(1).style_name == 'inside_shallow_frame_with_padding_and_vertical_spacing')
assert(panel(1)[prefix..'filter-slots'].column_count == 5)
assert(panel(1)[prefix..'filter-mode'].type == 'switch' and not panel(1)[prefix..'filter-mode'].allow_none_state)
assert(panel(1)[prefix..'filter-mode'].left_label_caption[1] == 'gui-inserter.whitelist')
for i = 1, 5 do assert(slot(1, i).elem_type == 'item-with-quality' and slot(1, i).style_name == 'slot_button') end
slot(1, 1).elem_value = { name = 'iron', quality = 'rare' }
emit('on_gui_elem_changed', 1, slot(1, 1))
assert(config.slots[1].quality == 'rare' and slot(2, 1).elem_value.quality == 'rare')
slot(2, 3).elem_value = { name = 'copper', quality = 'normal' }
emit('on_gui_elem_changed', 2, slot(2, 3))
assert(config.slots[1].name == 'iron' and config.slots[2] == nil and config.slots[3].name == 'copper')
local switch = panel(1)[prefix..'filter-mode']; switch.switch_state = 'right'
emit('on_gui_switch_state_changed', 1, switch)
assert(config.mode == 'blacklist' and panel(2)[prefix..'filter-mode'].switch_state == 'right')
slot(2, 1).elem_value = nil; emit('on_gui_elem_changed', 2, slot(2, 1))
assert(config.slots[1] == nil and slot(1, 1).elem_value == nil)
local old_slot = slot(1, 3)
local before = writes
emit('on_gui_closed', 1)
assert(writes == before, 'Closing GUI wrote stale settings')
emit('on_gui_opened', 1)
assert(slot(1, 3).elem_value.name == 'copper' and panel(1)[prefix..'filter-mode'].switch_state == 'right')
emit('on_gui_elem_changed', 1, old_slot)
assert(writes == before, 'Old invalid GUI event mutated configuration')
transfer.rebuild_open_guis()
assert(slot(2, 3).elem_value.name == 'copper' and writes == before)
entity.valid = false
emit('on_gui_elem_changed', 1, slot(1, 3))
emit('on_gui_closed', 1)
assert(writes == before)
print('PASS: standard five-slot/switch layout, immediate edits while OFF, sparse/quality values, two-player sync, close/reopen and stale-event safety.')
