require('init')

data:extend(
{
	{
		name = MergingChests.setting_names.max_length,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 2,
		default_value = 27,
		order = '01'
	},
	{
		name = MergingChests.setting_names.inventory_size_limit,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 1,
		maximum_value = 65535,
		default_value = 65535,
		order = '02'
	},
	{
		name = MergingChests.setting_names.warehouse_threshold,
		type = 'int-setting',
		setting_type = 'startup',
		minimum_value = 2,
		default_value = 28,
		hidden = true,
		order = '03'
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
		order = '04'
	},
	{
		name = MergingChests.setting_names.allow_delete_items,
		type = 'bool-setting',
		setting_type = 'runtime-per-user',
		default_value = false,
		order = '05'
	}
})
