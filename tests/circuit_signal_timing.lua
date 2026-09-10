-- Loaded only in the isolated engine-test copy. No transfer runs in this probe.
local green = defines.wire_connector_id.circuit_green
local signal = { type = 'item', name = 'iron-plate', quality = 'normal' }
local function iron(signals)
  for _, entry in ipairs(signals or {}) do
    if entry.signal.name == signal.name and (entry.signal.type == nil or entry.signal.type == 'item') then
      return entry.count
    end
  end
  return 0
end
local function sample(label)
  local c = storage.circuit_timing.container
  -- Obtain a fresh network reference each time, not a saved signal array.
  local network = assert(c.get_circuit_network(green))
  local row = {
    tick = game.tick, label = label,
    inventory = c.get_inventory(defines.inventory.chest).get_item_count('iron-plate'),
    network_signals = iron(network.signals),
    entity_get_signals = iron(c.get_signals(green)),
    network_get_signal = network.get_signal(signal),
    entity_get_signal = c.get_signal(signal, green),
  }
  log('CIRCUIT_SIGNAL_TIMING '..helpers.table_to_json(row))
  assert(row.network_signals == row.entity_get_signals and row.network_signals == row.network_get_signal
    and row.network_signals == row.entity_get_signal, 'Signal APIs returned different values')
end
script.on_event(defines.events.on_tick, function()
  if game.tick == 50 then
    assert(not storage.circuit_engine.input_before_owner_destroy.valid, 'Destroyed owner left a request input')
    log('REQUEST_INPUT_DESTROY_PASS: owner removal cleaned helper')
    local s = game.surfaces[1]
    local c = assert(s.create_entity { name = 'train-container-wide-steel-chest-13', position = {0, 20}, force = 'player' })
    local combinator = assert(s.create_entity { name = 'constant-combinator', position = {0, 23}, force = 'player' })
    c.get_or_create_control_behavior().read_contents = true
    assert(c.insert { name = 'iron-plate', count = 3000 } == 3000)
    assert(c.get_wire_connector(green, true).connect_to(combinator.get_wire_connector(green, true), false))
    local section = combinator.get_or_create_control_behavior().add_section()
    section.set_slot(1, { value = { name = 'iron-plate', quality = 'normal', comparator = '=' }, min = 700 })
    storage.circuit_timing = { container = c, section = section }
  elseif game.tick == 54 then
    sample('before_insert')
    assert(storage.circuit_timing.container.insert { name = 'iron-plate', count = 100 } == 100)
    sample('after_insert_100_same_tick')
  elseif game.tick == 55 then
    sample('insert_next_tick')
  elseif game.tick == 56 then
    sample('before_remove')
    assert(storage.circuit_timing.container.remove_item { name = 'iron-plate', count = 200 } == 200)
    sample('after_remove_200_same_tick')
  elseif game.tick == 57 then
    sample('remove_next_tick')
  elseif game.tick == 58 then
    sample('remove_two_ticks_later')
  elseif game.tick == 60 then
    sample('before_constant_change')
    storage.circuit_timing.section.set_slot(1, { value = { name = 'iron-plate', quality = 'normal', comparator = '=' }, min = 900 })
    sample('constant_900_same_tick')
  elseif game.tick == 61 then
    sample('constant_next_tick')
  elseif game.tick == 62 then
    sample('constant_two_ticks_later')
    log('CIRCUIT_SIGNAL_TIMING_PASS: fresh network.signals, entity.get_signals, network.get_signal, entity.get_signal compared')
    script.on_event(defines.events.on_tick, nil)
  end
end)
