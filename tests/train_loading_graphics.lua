-- Run from the mod root with Lua 5.2+; exercises real data.lua segment wiring.
local function deepcopy(value)
	if type(value) ~= 'table' then return value end
	local result = {}
	for k, v in pairs(value) do result[k] = deepcopy(v) end
	return result
end
table.deepcopy = deepcopy
for _, name in ipairs({ 'init', 'data_init', 'prototypes.custom_input',
	'prototypes.groups', 'prototypes.item', 'prototypes.shortcuts' }) do
	package.loaded[name] = true
end
local registrations = {}
MergingChests = {
	chest_names = { steel = 'steel-chest', infinity = 'train-container-infinity-chest' },
	merge_selection_tool_name = 'selector',
	create_mergeable_chest = function(entity, segments)
		table.insert(registrations, { entity = entity, segments = segments })
	end
}
data = { raw = { ['selection-tool'] = { selector = { select = { entity_filters = {} } } }, inserter = {} } }
function data:extend() end
dofile('data.lua')
assert(#registrations == 2, 'Steel and infinity must both be registered')
local create = require('scripts.sprite_generation')
local function equal(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= 'table' then return a == b end
	for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local checked = 0
for _, registration in ipairs(registrations) do
	for _, vertical in ipairs({ false, true }) do
		local segments = registration.segments[vertical and 'high_segments' or 'wide_segments']
		local ordinary = deepcopy(segments)
		ordinary.train_loading = nil
		for length = 2, 83 do
			local width, height = vertical and 1 or length, vertical and length or 1
			local layers = create(width, height, segments)
			if length >= 6 and (length + 1) % 7 == 0 then
				local k = (length + 1) / 7
				assert(#layers == 2 * (2 * k + 1), 'Wrong module count')
				local covered = 0
				for i = 1, 2 * k - 1 do
					local layer = layers[i]
					local span = i % 2 == 1 and 6 or 1
					local position = layer.shift[vertical and 2 or 1]
					assert(math.abs(position - span / 2 - (-length / 2 + covered)) < 1e-8,
						'Gap or overlap in logical footprint')
					covered = covered + span
				end
				assert(covered == length)
				for i, layer in ipairs(layers) do
					assert(layer.draw_as_shadow == (i <= #layers / 2))
					assert(layer.scale == 1 / 3)
					assert(layer.filename:find('/train%-loading/'))
					assert(layer.shift[vertical and 1 or 2] == 0)
					local file = assert(io.open(layer.filename:gsub('__TrainContainer__/', ''), 'rb'))
					file:close()
				end
			else
				assert(equal(layers, create(width, height, ordinary)), 'Ordinary graphics changed')
			end
			checked = checked + 1
		end
	end
end
-- Do not select the dedicated path for a rectangular footprint.
local s = registrations[1].segments.wide_segments
local original = deepcopy(s)
original.train_loading = nil
assert(equal(create(6, 2, s), create(6, 2, original)))
print('PASS: ' .. checked .. ' steel/infinity/orientation/length combinations; ordinary fallback unchanged.')

-- Optional exact runtime layer manifest for visual QA (Python/Pillow preview).
if arg[1] then
	local file = assert(io.open(arg[1], 'w'))
	for _, vertical in ipairs({ false, true }) do
		for _, length in ipairs({ 6, 13, 20, 83 }) do
			local layers = create(vertical and 1 or length, vertical and length or 1,
				registrations[1].segments[vertical and 'high_segments' or 'wide_segments'])
			for _, layer in ipairs(layers) do
				file:write(table.concat({vertical and 'high' or 'wide', length,
					layer.filename:gsub('__TrainContainer__/', ''), layer.width, layer.height,
					layer.shift[1], layer.shift[2], layer.draw_as_shadow and 'shadow' or 'body'}, '\t'), '\n')
			end
		end
	end
	file:close()
end
