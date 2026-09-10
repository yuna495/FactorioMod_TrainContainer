local inputs = require('scripts.train_request_inputs')
-- Preserve the already-installed handlers (lamps and transfer cleanup).
local function append(event_id, handler)
  local previous = script.get_event_handler(event_id)
  script.on_event(event_id, function(event)
    if previous then previous(event) end
    handler(event)
  end)
end
for _, event_id in ipairs({ defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built, defines.events.script_raised_revive }) do
  append(event_id, function(event) inputs.register(event.entity) end)
end
append(defines.events.on_entity_cloned, function(event)
  -- Helpers are recreated for cloned owners, never independently cloned.
  if event.destination.name == inputs.name then event.destination.destroy()
  else inputs.register(event.destination) end
end)
append(defines.events.on_object_destroyed, inputs.on_object_destroyed)
append(defines.events.script_raised_teleported, function(event) inputs.register(event.entity) end)

-- Chests may not fire on_player_flipped_entity. Linked controls also follow
-- the player's remapped vanilla flip keys and fire once per operation.
local function flip_selected_input(event)
  local player = game.get_player(event.player_index)
  if not player or player.cursor_ghost or (player.cursor_stack and player.cursor_stack.valid_for_read) then return end
  inputs.flip(player.selected)
end
for _, axis in ipairs({ 'horizontal', 'vertical' }) do
  script.on_event('train-container-flip-request-input-'..axis, flip_selected_input)
end
