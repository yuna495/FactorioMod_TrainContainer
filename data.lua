require('init')
require('data_init')

require('prototypes.custom_input')
require('prototypes.groups')
require('prototypes.item')
require('prototypes.shortcuts')

local graphics_path = '__TrainContainer__/graphics/entity/train-container'

--- @type segments_data
MergingChests.steel_chest_segments = {
	wide_segments = {
		entity = {
			filename = graphics_path..'/wide-chest/wide-chest.png',
			top_left = { x = 0, y = 0 },
			top = { x = 32, y = 0 },
			top_right = { x = 64, y = 0 },

			widths = { left = 64, middle = 64, right = 64 },
			heights = {
				top = 80,
				middle = 0,
				bottom = 0
			},
			shift = { x = -0.25, y = -4.5 },
			scale = 0.5
		},
		shadow = {
			filename = graphics_path..'/wide-chest/wide-chest-shadow.png',
			top_right = { x = 60, y = 0, shift = { x = 30 } },

			widths = { left = 0, middle = 0, right = 50 },
			heights = {
				top = 46,
				middle = 0,
				bottom = 0
			},
			shift = { x = 0.75, y = 12.5 },
			scale = 0.5,
			shadow = true
		}
	},
	high_segments = {
		entity = {
			filename = graphics_path..'/high-chest/high-chest.png',
			top_left = { x = 0, y = 0, shift = { y = 5 } },
			left = { x = 0, y = 22 },
			bottom_left = { x = 0, y = 54 },

			widths = { left = 64, middle = 0, right = 0 },
			heights = {
				top = 54,
				middle = 64,
				bottom = 90
			},
			shift = { x = -0.25, y = -9.5 },
			scale = 0.5
		},
		shadow = {
			filename = graphics_path..'/high-chest/high-chest-shadow.png',
			top_right = { x = 0, y = 0, shift = { y = 6.5 } },
			right = { x = 0, y = 18 },
			bottom_right = { x = 0, y = 45 },

			widths = { left = 0, middle = 0, right = 110 },
			heights = {
				top = 55,
				middle = 64,
				bottom = 55
			},
			shift = { x = 0.75, y = 6 },
			scale = 0.5,
			shadow = true
		}
	}
}

MergingChests.create_mergeable_chest(
	{
		chest_name = MergingChests.chest_names.steel
	},
	MergingChests.steel_chest_segments
)

MergingChests.create_mergeable_chest(
	{
		chest_name = MergingChests.chest_names.infinity,
		base_entity_name = 'infinity-chest',
		prototype_type = 'infinity-container',
		skip_selection_filter = true,
		hidden = true,
		placeable_by = function()
			return { item = 'infinity-chest', count = 1 }
		end,
		minable = { mining_time = 0.5 },
		localised_name = function(width, height)
			return { 'chest-name.'..MergingChests.prefix_with_modname('infinity'), ''..width, ''..height }
		end
	},
	MergingChests.steel_chest_segments
)

table.insert(data.raw['selection-tool'][MergingChests.merge_selection_tool_name].select.entity_filters, 'infinity-chest')

local function create_cybersyn2_inserter_shim()
	local base_inserter = data.raw.inserter.inserter
	if base_inserter == nil then
		return
	end

	local empty_sprite = {
		filename = '__core__/graphics/empty.png',
		priority = 'extra-high',
		width = 1,
		height = 1,
	}
	local shim = table.deepcopy(base_inserter)
	shim.name = MergingChests.cybersyn2_inserter_shim_name
	shim.localised_name = { 'entity-name.'..MergingChests.cybersyn2_inserter_shim_name }
	shim.icon = '__base__/graphics/icons/inserter.png'
	shim.flags = {
		'not-blueprintable',
		'not-deconstructable',
		'not-flammable',
		'not-on-map',
		'not-selectable-in-game',
		'hide-alt-info',
	}
	shim.hidden = true
	shim.hidden_in_factoriopedia = true
	shim.minable = nil
	shim.placeable_by = nil
	shim.collision_box = nil
	shim.selection_box = nil
	shim.collision_mask = { layers = {}, not_colliding_with_itself = true }
	shim.energy_source = { type = 'electric', usage_priority = 'secondary-input', drain = '0W' }
	shim.energy_per_movement = '0J'
	shim.energy_per_rotation = '0J'
	shim.max_health = 1
	shim.corpse = nil
	shim.dying_explosion = nil
	shim.damaged_trigger_effect = nil
	shim.open_sound = nil
	shim.close_sound = nil
	shim.working_sound = nil
	shim.hand_base_picture = empty_sprite
	shim.hand_closed_picture = empty_sprite
	shim.hand_open_picture = empty_sprite
	shim.hand_base_shadow = empty_sprite
	shim.hand_closed_shadow = empty_sprite
	shim.hand_open_shadow = empty_sprite
	shim.platform_picture = { sheet = empty_sprite }
	shim.circuit_connector = nil
	shim.circuit_wire_max_distance = 0
	shim.default_stack_control_input_signal = nil
	shim.allow_custom_vectors = true

	data:extend({ shim })
end

create_cybersyn2_inserter_shim()
