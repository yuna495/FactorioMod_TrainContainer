-- Module images are centered on their ground origin, including transparent
-- padding. Keep dimensions synchronized with graphics-source/train-loading/build.py.
local path = '__TrainContainer__/graphics/entity/train-container/train-loading/'

local function orientation(name, vertical)
	local modules = {}
	for module, length in pairs({ t6 = 768, j = 288, l = 240, r = 240 }) do
		modules[module] = {
			filename = path..name..'-'..module..'.png',
			shadow_filename = path..name..'-'..module..'-shadow.png',
			width = vertical and 288 or length,
			height = vertical and length or 288,
			scale = 1 / 3
		}
	end
	return modules
end

return { wide = orientation('wide', false), high = orientation('high', true) }
