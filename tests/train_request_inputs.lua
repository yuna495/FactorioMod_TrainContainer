storage = {}
local events, previous_calls, serial = {}, 0, 0
defines = { events = {} }
for id, name in ipairs({ 'on_built_entity', 'on_robot_built_entity', 'script_raised_built',
  'script_raised_revive', 'on_entity_cloned', 'on_object_destroyed', 'script_raised_teleported' }) do
  defines.events[name] = id
  events[id] = function() previous_calls = previous_calls + 1 end
end
script = {
  register_on_object_destroyed = function(entity) return entity.unit_number end,
  get_event_handler = function(id) return events[id] end,
  on_event = function(id, fn) events[id] = fn end,
}
MergingChests = { chest_names = { steel = 'steel', infinity = 'infinity' },
  get_merged_chest_info = function(name)
    if name == 'horizontal' then return 'steel', 13, 1 end
    if name == 'vertical' then return 'infinity', 1, 20 end
  end }
local function surface()
  local s = { entities = {} }
  s.create_entity = function(options)
    serial = serial + 1
    local e = { name = options.name, position = options.position, force = options.force, surface = s,
      valid = true, unit_number = serial, type = options.name == 'train-container-request-input' and 'lamp' or 'container' }
    e.destroy = function() e.valid = false end
    e.teleport = function(point, target) assert(target == nil); e.position = point; return true end
    s.entities[#s.entities + 1] = e
    return e
  end
  s.find_entities_filtered = function(query)
    local result = {}
    for _, e in ipairs(s.entities) do
      if e.valid and ((query.name and e.name == query.name) or (query.type and e.type == 'container')) then
        result[#result + 1] = e
      end
    end
    return result
  end
  return s
end
local a, b = surface(), surface()
game = { surfaces = { a, b } }
local inputs = require('scripts.train_request_inputs')
require('scripts.event_handlers.train_request_inputs')
local function build(name, x, y)
  local owner = a.create_entity { name = name, position = {x = x, y = y}, force = 'player' }
  events[defines.events.on_built_entity] { entity = owner }
  return owner
end
local owner = build('horizontal', 0, 0)
local port = inputs.get(owner)
assert(previous_calls == 1)
assert(port.position.x == -6 and port.position.y == 0)
assert(not port.destructible and not port.minable and not port.operable and not port.active)
port.wire = 'preserved'
assert(inputs.register(owner) == port)
inputs.rebuild(); inputs.rebuild()
assert(inputs.get(owner) == port and port.wire == 'preserved')
local vertical = build('vertical', 20, 0)
assert(inputs.get(vertical).position.x == 20 and inputs.get(vertical).position.y == -9.5)
local ordinary = build('steel-chest', 30, 0)
assert(inputs.get(ordinary) == nil)

local player = { cursor_stack = { valid_for_read = false } }
game.get_player = function() return player end
for _, tested in ipairs({ owner, vertical }) do
  local original = inputs.get(tested)
  local x, y = original.position.x, original.position.y
  player.selected = tested
  for _, first in ipairs({ 'horizontal', 'vertical' }) do
    local other = first == 'horizontal' and 'vertical' or 'horizontal'
    events['train-container-flip-request-input-'..first] { player_index = 1 }
    assert(original.position.x == tested.position.x * 2 - x and original.position.y == tested.position.y * 2 - y)
    inputs.rebuild()
    assert(inputs.get(tested) == original and storage.train_request_inputs.owners[tested.unit_number].reversed)
    events['train-container-flip-request-input-'..other] { player_index = 1 }
    assert(original.position.x == x and original.position.y == y)
  end
end
player.selected = port
events['train-container-flip-request-input-horizontal'] { player_index = 1 }
assert(port.position.x == 6 and port.wire == 'preserved')
player.cursor_stack.valid_for_read = true
events['train-container-flip-request-input-vertical'] { player_index = 1 }
assert(port.position.x == 6, 'Blueprint/item cursor changed a placed port')
player.cursor_stack.valid_for_read = false; player.cursor_ghost = 'steel-chest'
events['train-container-flip-request-input-vertical'] { player_index = 1 }
assert(port.position.x == 6)
player.cursor_ghost = nil
events['train-container-flip-request-input-vertical'] { player_index = 1 }
assert(port.position.x == -6)

local flipped_owner = build('horizontal', 60, 0)
inputs.flip(flipped_owner)
local flipped_port = inputs.get(flipped_owner)
assert(flipped_port.position.x == 66)
flipped_port.destroy()
events[defines.events.on_object_destroyed] { registration_number = flipped_port.unit_number }
assert(inputs.get(flipped_owner).position.x == 66, 'Repair lost the chosen endpoint')
flipped_owner.destroy()
events[defines.events.on_object_destroyed] { registration_number = flipped_owner.unit_number }

-- An owner produced by a script without raise_built is repaired on demand.
local silent = a.create_entity { name = 'horizontal', position = {x = 40, y = 0}, force = 'player' }
assert(inputs.get(silent))
local orphan = a.create_entity { name = inputs.name, position = {x = 99, y = 99} }
inputs.rebuild(); assert(not orphan.valid)

-- Explicit clone events retain existing lamp/transfer handlers.
local clone = a.create_entity { name = 'horizontal', position = {x = 0, y = 20}, force = 'player' }
events[defines.events.on_entity_cloned] { destination = clone }
assert(inputs.get(clone) ~= port and not inputs.get(clone).wire)
local duplicate = a.create_entity { name = inputs.name, position = inputs.get(clone).position }
events[defines.events.on_entity_cloned] { destination = duplicate }
assert(not duplicate.valid and inputs.get(clone).valid)

owner.position = {x = 5, y = 10}; owner.surface = b; owner.force = 'other'
events[defines.events.script_raised_teleported] { entity = owner }
assert(not port.valid, 'Cross-surface move must recreate the non-teleportable lamp')
port = inputs.get(owner)
assert(port.surface == b and port.position.x == -1 and port.position.y == 10 and port.force == 'other')
owner.position.x = 6 -- A script omitting the event is handled on the next read.
assert(inputs.get(owner).position.x == 0)

-- Failed relocation must not leave a port reading a remote/old request network.
port.teleport = function() return false end
owner.position.x = 7
local relocated = inputs.get(owner)
assert(relocated ~= port and not port.valid and relocated.position.x == 1)
port = relocated

local old_registration = port.unit_number
port.destroy()
events[defines.events.on_object_destroyed] { registration_number = old_registration }
local replacement = inputs.get(owner)
assert(replacement ~= port and replacement.valid and not replacement.wire)
events[defines.events.on_object_destroyed] { registration_number = old_registration }
assert(inputs.get(owner) == replacement)

owner.destroy()
events[defines.events.on_object_destroyed] { registration_number = owner.unit_number }
assert(not replacement.valid and storage.train_request_inputs.owners[owner.unit_number] == nil)
assert(inputs.get(owner) == nil)
vertical.destroy(); silent.destroy(); clone.destroy()
inputs.rebuild()
assert(next(storage.train_request_inputs.owners) == nil)
assert(previous_calls >= 8, 'Existing event handlers were overwritten')
print('PASS: request-input 1:1 registration, orientation, migration/rebuild, wire retention, clone, teleport, destruction/recreation, orphan cleanup and handler chaining.')
