require "util"

--- @class MergingChests
MergingChests = MergingChests or { }

MergingChests.mod_name = 'TrainContainer'
MergingChests.prototype_prefix = 'train-container-'
MergingChests.prototype_pattern_prefix = 'train%-container%-'
MergingChests.unlimited_mod_name = 'TrainContainerUnlimited'

function MergingChests.is_mod_active(mod)
	return not not (mods or script.active_mods)[mod]
end

--- @param value string
function MergingChests.prefix_with_modname(value)
	return MergingChests.prototype_prefix..value
end

--- @param setting_name string
--- @param chest_name string
--- @return string
function MergingChests.chest_specific_setting_name(setting_name, chest_name)
    return setting_name..'-'..chest_name
end

MergingChests.custom_input_names = {
	rotate_blueprint_clockwise = MergingChests.prefix_with_modname('rotate-blueprint-clockwise'),
	rotate_blueprint_counterclockwise = MergingChests.prefix_with_modname('rotate-blueprint-counterclockwise'),
	merge_tool = MergingChests.prefix_with_modname('merge-tool')
}

MergingChests.item_group_names = {
	merged_chests = MergingChests.prefix_with_modname('merged-chests'),
	wide_chests = MergingChests.prefix_with_modname('wide-chests'),
	high_chests = MergingChests.prefix_with_modname('high-chests'),
	warehouses = MergingChests.prefix_with_modname('warehouses'),
	trashdumps = MergingChests.prefix_with_modname('trashdumps'),
}

MergingChests.merge_selection_tool_name = MergingChests.prefix_with_modname('merge-chest-selector')

MergingChests.merge_shortcut_name = MergingChests.prefix_with_modname('merge-chest-selector')

MergingChests.setting_names = {
	max_length = MergingChests.prefix_with_modname('max-chest-length'),
	inventory_size_limit = MergingChests.prefix_with_modname('inventory-size-limit'),
	warehouse_threshold = MergingChests.prefix_with_modname('warehouse-threshold'),
	circuit_connector_position = MergingChests.prefix_with_modname('circuit-connector-position'),
	allow_delete_items = MergingChests.prefix_with_modname('allow-delete-items'),
}

MergingChests.chest_names = {
	wooden = 'wooden-chest',
	iron = 'iron-chest',
	steel = 'steel-chest',
	infinity = MergingChests.prefix_with_modname('infinity-chest')
}

--- @alias circuit_connector_position
--- | 'right-top'
--- | 'right-middle'
--- | 'right-bottom'
--- | 'center-center'
--- | 'left-top'
--- | 'left-middle'
--- | 'left-bottom'
--- | 'bottom-right'
--- | 'bottom-middle'
--- | 'bottom-left'

--- @alias mod_settings
--- | { chest_name: string | nil }
--- | { max_length: number }
--- | { inventory_size_limit: number }
--- | { warehouse_threshold: number }
--- | { circuit_connector_position: circuit_connector_position }

--- @param chest_name string | nil
--- @return mod_settings
local function parse_settings(chest_name)
	local function get_startup_setting_value(setting_name)
		local setting = chest_name and settings.startup[MergingChests.chest_specific_setting_name(setting_name, chest_name)] or nil
		setting = setting or settings.startup[setting_name]
		return setting and setting.value
	end

	--- @type mod_settings
	local mod_settings = {
		chest_name = chest_name,
		max_length = get_startup_setting_value(MergingChests.setting_names.max_length),
		inventory_size_limit = get_startup_setting_value(MergingChests.setting_names.inventory_size_limit),
		warehouse_threshold = get_startup_setting_value(MergingChests.setting_names.warehouse_threshold),
		circuit_connector_position = get_startup_setting_value(MergingChests.setting_names.circuit_connector_position),
	}

	if not MergingChests.is_mod_active(MergingChests.unlimited_mod_name) then
		mod_settings.max_length = math.min(mod_settings.max_length, 42)
	end
	return mod_settings
end

--- @type { [string]: mod_settings | nil }
local cached_mod_settings = {
	default = nil
}

--- @param chest_name string | nil
--- @return mod_settings
function MergingChests.get_mod_settings(chest_name)
	local chest_name_or_default = chest_name or 'default'
	if cached_mod_settings[chest_name_or_default] == nil then
		cached_mod_settings[chest_name_or_default] = parse_settings(chest_name)
		if chest_name then
			log('Merging chests mod settings for "'..chest_name..'": '..serpent.line(cached_mod_settings[chest_name_or_default]))
		else
			log('Default merging chests mod settings: '..serpent.line(cached_mod_settings[chest_name_or_default]))
		end
	end
	return cached_mod_settings[chest_name_or_default]
end

--- Checks if width and height is allowed for line-shaped train containers.
--- @param width integer
--- @param height integer
--- @param chest_name string | nil
function MergingChests.is_size_allowed(width, height, chest_name)
    local mod_settings = MergingChests.get_mod_settings(chest_name)

	return (
		width <= mod_settings.max_length and
		height <= mod_settings.max_length and
		(width == 1 or height == 1)
	)
end

--- @param merged_chest_name string Possible merged chest name
--- @return string | nil chest_name Split chest name
--- @return integer | nil width Chest width
--- @return integer | nil height Chest height
function MergingChests.get_merged_chest_info(merged_chest_name)
	local chest_name, width, height
	_, _, width, height = string.find(merged_chest_name, '^'..MergingChests.prototype_pattern_prefix..'infinity%-([1-9][0-9]*)x([1-9][0-9]*)$')
	if width and height then
		return MergingChests.chest_names.infinity, tonumber(width), tonumber(height)
	end

	_, _, chest_name, width = string.find(merged_chest_name, '^'..MergingChests.prototype_pattern_prefix..'wide%-(.*)%-([1-9][0-9]*)$')
	if chest_name and width then
		return chest_name, tonumber(width), 1
	end

	_, _, chest_name, height = string.find(merged_chest_name, '^'..MergingChests.prototype_pattern_prefix..'high%-(.*)%-([1-9][0-9]*)$')
	if chest_name and height then
		return chest_name, 1, tonumber(height)
	end

	_, _, chest_name, width, height = string.find(merged_chest_name, '^'..MergingChests.prototype_pattern_prefix..'(.*)%-warehouse%-([1-9][0-9]*)x([1-9][0-9]*)$')
	if chest_name and width and height then
		return chest_name, tonumber(width), tonumber(height)
	end

	_, _, chest_name, width, height = string.find(merged_chest_name, '^'..MergingChests.prototype_pattern_prefix..'(.*)%-trashdump%-([1-9][0-9]*)x([1-9][0-9]*)$')
	if chest_name and width and height then
		return chest_name, tonumber(width), tonumber(height)
	end

	return nil, nil, nil
end

--- @param chest_name string
--- @param width integer
--- @param height integer
--- @return string
function MergingChests.get_merged_chest_name(chest_name, width, height)
	if chest_name == MergingChests.chest_names.infinity then
		return MergingChests.prefix_with_modname('infinity-'..width..'x'..height)
	end

    if width > 1 and height > 1 then
        local mod_settings = MergingChests.get_mod_settings(chest_name)
        if width > mod_settings.warehouse_threshold and height > mod_settings.warehouse_threshold then
            return MergingChests.get_trashdump_name(chest_name, width, height)
        else
            return MergingChests.get_warehouse_name(chest_name, width, height)
        end
    elseif width > 1 then
        return MergingChests.get_wide_chest_name(chest_name, width)
    else
        return MergingChests.get_high_chest_name(chest_name, height)
    end
end

--- @param chest_name string
--- @param width integer
--- @return string
function MergingChests.get_wide_chest_name(chest_name, width)
    return MergingChests.prefix_with_modname('wide-'..chest_name..'-'..width)
end

--- @param chest_name string
--- @param height integer
--- @return string
function MergingChests.get_high_chest_name(chest_name, height)
    return MergingChests.prefix_with_modname('high-'..chest_name..'-'..height)
end

--- @param chest_name string
--- @param width integer
--- @param height integer
--- @return string
function MergingChests.get_warehouse_name(chest_name, width, height)
    return MergingChests.prefix_with_modname(chest_name..'-warehouse-'..width..'x'..height)
end

--- @param chest_name string
--- @param width integer
--- @param height integer
--- @return string
function MergingChests.get_trashdump_name(chest_name, width, height)
    return MergingChests.prefix_with_modname(chest_name..'-trashdump-'..width..'x'..height)
end

--- @param merged_chest_name string
--- @return boolean
function MergingChests.is_infinity_chest_name(merged_chest_name)
	local chest_name = MergingChests.get_merged_chest_info(merged_chest_name)
	return chest_name == MergingChests.chest_names.infinity
end

--- Returns final inventory size of the chest, modified by mod settings
--- @param default_inventory_size integer
--- @param tiles integer
--- @param chest_name string | nil
--- @return integer
function MergingChests.get_inventory_size(default_inventory_size, tiles, chest_name)
	local mod_settings = MergingChests.get_mod_settings(chest_name)
	return util.clamp(
		math.floor(default_inventory_size * tiles),
		1,
		math.min(mod_settings.inventory_size_limit, 65536)
	)
end

--- @alias Grid
--- | LuaEntity[][]
--- | { min_x: integer, min_y: integer, max_x: integer, max_y: integer }

--- @param entities LuaEntity
--- @return Grid
function MergingChests.entities_to_grid(entities)
	--- @type Grid
	local grid = {
		min_x = math.huge,
		min_y = math.huge,
		max_x = -math.huge,
		max_y = -math.huge,
	}
	for _, entity in ipairs(entities) do
		local x = math.floor(entity.position.x)
		local y = math.floor(entity.position.y)

		grid[x] = grid[x] or { }
		grid[x][y] = entity

		grid.min_x = math.min(grid.min_x, x)
		grid.min_y = math.min(grid.min_y, y)
		grid.max_x = math.max(grid.max_x, x)
		grid.max_y = math.max(grid.max_y, y)
	end

	return grid
end
