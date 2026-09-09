-- Module images are centered on their ground origin, including transparent
-- padding. Keep dimensions synchronized with graphics-source/train-loading/build.py.
local path = '__TrainContainer__/graphics/entity/train-container/train-loading/'

local function orientation(name, vertical)
	local modules = {}
	for module, length in pairs({ t6 = 512, j = 192, l = 160, r = 160 }) do
		modules[module] = {
			filename = path..name..'-'..module..'.png',
			shadow_filename = path..name..'-'..module..'-shadow.png',
			width = vertical and 192 or length,
			height = vertical and length or 192,
			scale = 0.5
		}
	end
	return modules
end

return { wide = orientation('wide', false), high = orientation('high', true) }
