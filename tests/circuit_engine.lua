-- Isolated engine fixture. Loaded ONLY by tests/run_circuit_engine.ps1's mod copy.
-- Real circuit networks, constant combinator, inventories and stack transfer;
-- station readiness is stubbed to exercise the transfer group in isolation.
local transfer = require('scripts.train_transfer')
local request = require('scripts.train_circuit_request')
local key = request.key('iron-plate')
local inputs = require('scripts.train_request_inputs')
local function command(combinator, count)
  local behavior = combinator.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  section.set_slot(1, { value = { type = 'item', name = 'iron-plate', quality = 'normal', comparator = '=' }, min = count })
end
local function process(c, inventory, mode)
  local train = { valid = true, state = defines.train_state.wait_station, station = {} }
  local wagon = { valid = true, train = train, get_inventory = function() return inventory end }
  local group = { container = c, wagons = { wagon }, next_wagon = 1, mode = mode,
    filter_configuration = transfer.get_filter_configuration(c) }
  assert(transfer._test_process_group(group, {}))
end
script.on_nth_tick(7, function()
  local n = game.tick / 7
  if n == 1 then
    local s = game.surfaces[1]
    s.request_to_generate_chunks({0, 0}, 1); s.force_generate_chunk_requests()
    local c = assert(s.create_entity { name = 'train-container-wide-steel-chest-13', position = {0, 0}, force = 'player' })
    local combinator = assert(s.create_entity { name = 'constant-combinator', position = {-6, 3}, force = 'player' })
    c.get_or_create_control_behavior().read_contents = true
    local input = inputs.register(c)
    assert(input.get_inventory(defines.inventory.chest) == nil)
    assert(input.get_wire_connector(defines.wire_connector_id.circuit_green, true).connect_to(
      combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true), false))
    local pole = s.create_entity { name = 'small-electric-pole', position = {3, 3}, force = 'player' }
    assert(c.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red, true), false))
    assert(c.insert { name = 'iron-plate', count = 15000 } == 15000)
    command(combinator, 12000)
    for y = -6, 6, 2 do s.create_entity { name = 'straight-rail', position = {20, y}, direction = defines.direction.north, force = 'player' } end
    local wagon = assert(s.create_entity { name = 'cargo-wagon', position = {20, 0}, direction = defines.direction.north, force = 'player' })
    storage.circuit_engine = { container = c, combinator = combinator, target = game.create_inventory(200), wagon = wagon }
  elseif n == 2 then
    local f = storage.circuit_engine
    assert(request.connected(f.container))
    assert(request.read(f.container, f.container.get_inventory(defines.inventory.chest))[key] == 12000)
    process(f.container, f.target, 'load')
    assert(f.target.get_item_count('iron-plate') == 12000, 'Real stack bulk load failed')
    assert(f.container.get_item_count('iron-plate') == 3000)
    command(f.combinator, 700)
  elseif n == 3 then
    local f = storage.circuit_engine
    assert(request.read(f.container, f.container.get_inventory(defines.inventory.chest))[key] == 700)
    -- Current body inventory changes cannot alter the sampled external quota.
    f.container.insert { name = 'iron-plate', count = 100 }
    assert(request.read(f.container)[key] == 700)
    f.container.remove_item { name = 'iron-plate', count = 300 }
    assert(request.read(f.container)[key] == 700)
    f.container.insert { name = 'iron-plate', count = 200 }
    assert(f.container.get_signal({ name = 'iron-plate' }, defines.wire_connector_id.circuit_red) == 3000)
    process(f.container, f.target, 'unload')
    assert(f.container.get_item_count('iron-plate') == 3700 and f.target.get_item_count('iron-plate') == 11300)
    f.container.get_control_behavior().read_contents = false
  elseif n == 4 then
    local f = storage.circuit_engine
    assert(request.read(f.container, f.container.get_inventory(defines.inventory.chest))[key] == 700)
    process(f.container, f.target, 'load')
    assert(f.container.get_item_count('iron-plate') == 3000)
    command(f.combinator, 0)
  elseif n == 5 then
    local f = storage.circuit_engine
    process(f.container, f.target, 'load')
    assert(f.container.get_item_count('iron-plate') == 3000)
    f.container.get_control_behavior().read_contents = true
    command(f.combinator, 700)
    f.target.destroy()
    f.target = f.wagon.get_inventory(defines.inventory.cargo_wagon)
    f.target.set_bar(3)
    f.target.set_filter(1, 'copper-plate')
  elseif n == 6 then
    local f = storage.circuit_engine
    process(f.container, f.target, 'load')
    assert(not f.target[1].valid_for_read, 'Destination slot filter was bypassed')
    assert(f.target.get_item_count('iron-plate') == 100, 'Destination bar was bypassed')
    inputs.get(f.container).get_wire_connector(defines.wire_connector_id.circuit_green, false).disconnect_all()
    inputs.get(f.container).get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(f.combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    f.container.get_wire_connector(defines.wire_connector_id.circuit_green, true).connect_to(f.combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true), false)
  elseif n == 7 then
    local f = storage.circuit_engine
    assert(not request.connected(f.container))
    f.target.clear(); f.target.set_filter(1, nil); f.target.set_bar()
    process(f.container, f.target, 'load')
    assert(f.target.get_item_count('iron-plate') == 500, 'Normal rate did not return')
    local retained = inputs.get(f.container)
    assert(inputs.flip(f.container))
    assert(inputs.get(f.container) == retained and retained.position.x == f.container.position.x + 6)
    assert(retained.get_wire_connector(defines.wire_connector_id.circuit_red, false).real_connection_count == 1,
      'Flip lost the existing circuit wire')
    assert(inputs.flip(retained))
    assert(retained.position.x == f.container.position.x - 6)
    log('REQUEST_INPUT_FLIP_PASS: endpoint toggles on owner/helper, retaining entity and wire')
    inputs.rebuild(); inputs.rebuild()
    assert(inputs.get(f.container) == retained, 'Rebuild replaced the connected port')
    assert(retained.get_wire_connector(defines.wire_connector_id.circuit_red, false).real_connection_count == 1)
    local blueprint_inventory = game.create_inventory(1)
    blueprint_inventory[1].set_stack('blueprint')
    blueprint_inventory[1].create_blueprint { surface = f.container.surface, force = f.container.force,
      area = {{-10, -2}, {10, 5}}, include_entities = true }
    for _, entity in ipairs(blueprint_inventory[1].get_blueprint_entities() or {}) do
      assert(entity.name ~= inputs.name, 'Input was stored in blueprint')
    end
    blueprint_inventory.destroy()
    retained.destroy()
    local repaired = inputs.get(f.container)
    assert(repaired ~= retained and repaired.valid)
    assert(not request.connected(f.container))
    f.input_before_owner_destroy = repaired
    f.container.destroy()
    log('CIRCUIT_ENGINE_PASS: 12000 bulk load, unload, isolated input, same-tick body changes, red inventory, zero, filters/bar, body-green ignored, rebuild, blueprint exclusion, repair')
    script.on_nth_tick(7, nil)
  end
end)
