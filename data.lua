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
		force_enable_chest = true,
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
