-- A lamp has circuit input but no inventory and no circuit output at all.
local input = table.deepcopy(data.raw.lamp['small-lamp'])
input.name = 'train-container-request-input'
input.localised_name = { 'entity-name.train-container-request-input' }
input.localised_description = { 'entity-description.train-container-request-input' }
input.flags = { 'placeable-off-grid', 'not-blueprintable', 'not-deconstructable', 'not-flammable', 'not-on-map', 'hide-alt-info' }
input.hidden = true
input.hidden_in_factoriopedia = true
input.minable = nil
input.placeable_by = nil
input.next_upgrade = nil
input.fast_replaceable_group = nil
input.collision_mask = { layers = {} }
input.collision_box = {{0, 0}, {0, 0}}
input.selection_box = {{-0.3, -0.3}, {0.3, 0.3}}
input.selection_priority = 60
input.energy_source = { type = 'void' }
input.energy_usage_per_tick = '1W'
input.light = nil
input.light_when_colored = nil
input.glow_size = 0
input.corpse = nil
input.dying_explosion = nil
input.damaged_trigger_effect = nil
input.open_sound = nil
input.close_sound = nil
-- Keep the receiver invisible at either endpoint, independently of lamp state.
input.picture_off = { filename = '__core__/graphics/empty.png', width = 1, height = 1 }
input.picture_on = { filename = '__core__/graphics/empty.png', width = 1, height = 1 }
data:extend({ input })
