local h = dofile('tests/train_filters.lua')
local request = require('scripts.train_circuit_request')
local configuration = require('scripts.train_filter_configuration')
local transfer, cycle, total = h.transfer, h.cycle, h.total
local function entry(name, count, quality, kind)
  return { signal = { name = name, quality = quality, type = kind }, count = count }
end
local function bulk(count)
  local result = {}
  while count > 0 do result[#result + 1] = { name = 'iron', count = math.min(count, 100) }; count = count - 100 end
  return result
end
-- A dedicated input never reads or emits the owner's inventory.
local function connect(c, external, read_contents)
  local state = { connected = true, external = external, reads = 0 }
  c.get_wire_connector = function() error('Body connector must not be read') end
  c.get_circuit_network = function() error('Body network must not be read') end
  c.get_control_behavior = function() error('Body read_contents must not be read') end
  c.request_input = {
    get_wire_connector = function(id, create)
      assert(id == defines.wire_connector_id.circuit_green and create == false)
      return { real_connection_count = state.connected and 1 or 0, connection_count = 1 }
    end,
    get_circuit_network = function(id)
      assert(id == defines.wire_connector_id.circuit_green)
      state.reads = state.reads + 1
      return { signals = state.external }
    end
  }
  return state
end

for _, direction in ipairs({ 'load', 'unload' }) do
  for _, dynamic in ipairs({ false, true }) do
    local c, t, src, dst = h.setup(direction, bulk(1200))
    connect(c, {})
    transfer.set_circuit_set_filters(c, dynamic); transfer.set_mode(c, direction); cycle(10)
    assert(total(dst) == 0 and total(src) == 1200, 'Connected zero request fell back')
  end
  local c, t, src, dst = h.setup(direction, bulk(1200))
  local wire = connect(c, { entry('iron', 750) })
  transfer.set_mode(c, direction); cycle(10)
  assert(total(dst) == 750 and total(src) == 450 and wire.reads == 1)
  wire.external = { entry('iron', 1000) }; cycle(20)
  assert(total(dst) == 1000 and total(src) == 200, 'Capacity limit or refill retry failed')

  c, t, src, dst = h.setup(direction, bulk(300))
  connect(c, { entry('iron', 1000) }); transfer.set_mode(c, direction); cycle(10)
  assert(total(dst) == 300 and total(src) == 0)
  for i = 1, 2 do src[i].count = 100; src[i].valid_for_read = true end
  cycle(20); assert(total(dst) == 500, 'Later supply was not processed next circuit cycle')

  c, t, src, dst = h.setup(direction, { { name = 'iron', count = 100 },
    { name = 'iron', quality = 'rare', count = 100, metadata = 'unique' }, { name = 'copper', count = 100 } })
  connect(c, { entry('iron', 40), entry('iron', 30, 'rare'), entry('copper', 20),
    entry('signal-A', 100, nil, 'virtual'), entry('water', 100, nil, 'fluid') })
  transfer.set_mode(c, direction); cycle(10)
  assert(total(dst) == 90 and total(src) == 210)
  local counts = {}; for _, s in ipairs(dst) do if s.valid_for_read then
    counts[request.key(s.name, s.quality)] = s.count
    if s.quality.name == 'rare' then assert(s.metadata == 'unique') end
  end end
  assert(counts[request.key('iron')] == 40 and counts[request.key('iron', 'rare')] == 30)

  for _, manual in ipairs({ 'whitelist', 'blacklist' }) do
    c, t, src, dst = h.setup(direction, { { name = 'iron', count = 100 }, { name = 'copper', count = 100 } })
    connect(c, { entry('iron', 70), entry('copper', 60) })
    transfer.set_filter(c, 3, h.filter(manual == 'whitelist' and 'iron' or 'copper'))
    transfer.set_filter_mode(c, manual); transfer.set_mode(c, direction); cycle(10)
    assert(total(dst) == 70)
    transfer.set_circuit_set_filters(c, true); cycle(20); assert(total(dst) == 160)
    transfer.set_circuit_set_filters(c, false); cycle(30); assert(total(dst) == 160)
    assert(transfer.get_filter_configuration(c).slots[3].name ~= nil)
  end
end

local c, t, src, dst = h.setup('load', bulk(1400), nil, 2)
connect(c, { entry('iron', 1000) }); transfer.set_mode(c, 'load'); cycle(10)
assert(total(dst) == 500 and total(t.cargo_wagons[2].get_inventory()) == 500 and total(src) == 400)

-- Even two active trains must not each reuse the same container request.
c, t, src, dst = h.setup('load', bulk(1400), nil, 2)
local wire = connect(c, { entry('iron', 700) }); transfer.set_mode(c, 'load')
local group = storage.train_transfer.active_trains[50].groups[1]
group.wagons = { t.cargo_wagons[1] }
storage.train_transfer.active_trains[51] = { train = t, groups = { {
  container = c, wagons = { t.cargo_wagons[2] }, next_wagon = 1, mode = 'load',
  filter_configuration = transfer.get_filter_configuration(c) } } }
cycle(10)
assert(total(dst) + total(t.cargo_wagons[2].get_inventory()) == 700 and wire.reads == 1)

c, t, src, dst = h.setup('load', bulk(800))
wire = connect(c, { entry('iron', -50), entry('copper', 0), entry('iron', 100, nil, 'fluid') })
transfer.set_mode(c, 'load'); cycle(10); assert(total(dst) == 0)
wire.connected = false; cycle(20); assert(total(dst) == 500 and wire.reads == 1)

-- Connect while a normal blocked-transfer retry is pending.
c, t, src, dst = h.setup('load', bulk(800))
transfer.set_filter(c, 1, h.filter('copper')); transfer.set_mode(c, 'load'); cycle(10)
wire = connect(c, { entry('iron', 650) }); transfer.set_circuit_set_filters(c, true)
storage.train_transfer.active_trains[50].groups[1].retry_after_tick = 1000
cycle(20); assert(total(dst) == 650)
transfer.set_mode(c, 'off')
assert(transfer.get_filter_configuration(c).circuit_set_filters)
transfer.set_mode(c, 'load'); cycle(30); assert(total(dst) == 800)
transfer.set_mode(c, 'off')
h.events[defines.events.on_object_destroyed]({ registration_number = c.registration })
assert(storage.train_transfer.filters[c.unit_number] == nil)

for _, read_contents in ipairs({ true, false }) do
  c, t, src, dst = h.setup('load', bulk(800))
  connect(c, { entry('iron', 150) }, read_contents)
  transfer.set_mode(c, 'load'); cycle(10); assert(total(dst) == 150)
end
c, t, src, dst = h.setup('load', bulk(800), { bar = 2, filters = { [1] = h.filter('copper') } })
connect(c, { entry('iron', 800) }); transfer.set_mode(c, 'load'); cycle(10)
assert(total(dst) == 0 and total(src) == 800)

c, t = h.setup('load', {})
storage.train_transfer.filters[1] = { mode = 'blacklist', slots = { [5] = h.filter('iron', 'rare') } }
storage.train_transfer.filter_schema_version = 3
h.lifecycle.configuration()
local config = transfer.get_filter_configuration(c)
assert(config.circuit_set_filters == false and config.mode == 'blacklist' and config.slots[5].quality == 'rare')
assert(configuration.normalize('iron').circuit_set_filters == false)
assert(configuration.normalize(h.filter('iron')).circuit_set_filters == false)

-- Circuit configuration edits must not touch the existing geometry shim lifecycle.
c, t = h.setup('load', bulk(100))
MergingChests.cybersyn2_inserter_shim_name = 'test-shim'
prototypes.entity['test-shim'] = {}
defines.direction = { north = 0, south = 8, west = 12, east = 4 }
local built, destroyed = 0, 0
script.raise_event = function() end
local previous_find = c.surface.find_entities_filtered
c.surface.find_entities_filtered = function(query)
  if type(query.type) == 'table' then return { { valid = true, position = { x = 0, y = 1 } } } end
  return previous_find(query)
end
c.surface.create_entity = function(options)
  assert(options.name == 'test-shim')
  built = built + 1
  return { valid = true, destroy = function() destroyed = destroyed + 1 end }
end
transfer.set_mode(c, 'load')
assert(built == 6 and destroyed == 0)
connect(c, { entry('iron', 10) })
transfer.set_circuit_set_filters(c, true); cycle(10)
transfer.set_circuit_set_filters(c, false)
assert(built == 6 and destroyed == 0, 'Circuit filter edit changed shims')
transfer.set_mode(c, 'off')
assert(destroyed == 6 and storage.train_transfer.cybersyn2_shims[c.unit_number] == nil)
print('PASS: circuit quotas, both directions, quality/metadata, isolated request input, zero/negative/non-item, multi-wagon/train, later supply, filters/toggle, migration, cleanup and safety.')
