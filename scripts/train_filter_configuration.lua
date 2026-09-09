-- Plain per-entity filter data. Iterate numeric slots explicitly: holes matter.
local filters = { slot_count = 5, schema_version = 3 }

function filters.normalize_slot(value)
	if type(value) == 'string' then value = { name = value, quality = 'normal' } end
	if type(value) ~= 'table' or not value.name or not prototypes.item[value.name] then return nil end
	local quality = value.quality or 'normal'
	if not prototypes.quality[quality] then quality = 'normal' end
	return { name = value.name, quality = quality }
end

function filters.normalize(value)
	local result = { mode = 'whitelist', slots = {} }
	if type(value) == 'string' or (type(value) == 'table' and value.name) then
		result.slots[1] = filters.normalize_slot(value)
	elseif type(value) == 'table' then
		result.mode = value.mode == 'blacklist' and 'blacklist' or 'whitelist'
		if type(value.slots) == 'table' then
			for slot = 1, filters.slot_count do result.slots[slot] = filters.normalize_slot(value.slots[slot]) end
		end
	end
	return result
end

function filters.equal(a, b)
	if a.mode ~= b.mode then return false end
	for slot = 1, filters.slot_count do
		local left, right = a.slots[slot], b.slots[slot]
		if left == nil or right == nil then
			if left ~= right then return false end
		elseif left.name ~= right.name or left.quality ~= right.quality then return false end
	end
	return true
end

function filters.matches(stack, configuration)
	local any, matched = false, false
	for slot = 1, filters.slot_count do
		local filter = configuration.slots[slot]
		if filter then
			any = true
			if stack.name == filter.name and stack.quality and stack.quality.name == filter.quality then
				matched = true
				break
			end
		end
	end
	if not any then return true end
	if configuration.mode == 'blacklist' then return not matched end
	return matched
end

return filters
