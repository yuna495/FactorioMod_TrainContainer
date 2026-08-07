require('init')
require('setting_init')

MergingChests.create_mergeable_chest_setting(MergingChests.chest_names.steel, {
	default_value = 'chest',
	disable_warehouse = true,
	disable_trashdump = true,
	order = '1'
})

data:extend(
{
	{
		name = MergingChests.setting_names.max_length,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 2,
		default_value = 27,
		order = '02'
	},
	{
		name = MergingChests.setting_names.inventory_size_multiplier,
		type = 'double-setting',
		setting_type = 'startup',
		minimum_value = 0,
		default_value = 1.0,
		order = '03'
	},
	{
		name = MergingChests.setting_names.inventory_size_limit,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 1,
		maximum_value = 65535,
		default_value = 65535,
		order = '04'
	},
	{
		name = MergingChests.setting_names.inventory_type,
		type = 'string-setting',
		setting_type = 'startup',
		default_value = 'normal',
		allowed_values = {
			'normal',
			'with_bar',
			'with_filters_and_bar'
		},
		order = '05'
	},
	{
		name = MergingChests.setting_names.sprite_decal_chance,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 0,
		maximum_value = 100,
		default_value = 15,
		order = '06'
	},
	{
		name = MergingChests.setting_names.warehouse_threshold,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 2,
		default_value = 28,
		hidden = true,
		order = '07'
	},
	{
		name = MergingChests.setting_names.circuit_connector_position,
		type = 'string-setting',
		setting_type = 'startup',
		default_value = 'center-center',
		allowed_values = {
			'center-center',
			'right-top',
			'right-middle',
			'right-bottom',
			'left-top',
			'left-middle',
			'left-bottom',
			'bottom-right',
			'bottom-middle',
			'bottom-left'
		},
		order = '08'
	},
	{
		name = MergingChests.setting_names.allow_delete_items,
		type = 'bool-setting',
		setting_type = 'runtime-per-user',
		default_value = false,
		order = '09'
	},
	{
		name = MergingChests.setting_names.enable_upgrading_merged_chests,
		type = 'bool-setting',
		setting_type = 'startup',
		default_value = false,
		order = '10'
	}
})
