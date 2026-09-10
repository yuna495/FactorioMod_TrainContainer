-- Circuit quantities are snapshots for one transfer cycle, never delivery totals.
local request = {}
local inputs = require('scripts.train_request_inputs')

function request.connected(entity)
  local input = inputs.get(entity)
  if not input then return false end
  local connector = input.get_wire_connector(defines.wire_connector_id.circuit_green, false)
  return connector ~= nil and connector.real_connection_count > 0
end

local function quality_name(quality)
  if quality == nil then return 'normal' end
  return type(quality) == 'string' and quality or quality.name
end

function request.key(name, quality)
  return name .. '\0' .. quality_name(quality)
end

function request.read(entity)
  local quotas = {}
  local input = inputs.get(entity)
  if not input then return quotas end
  local network = input.get_circuit_network(defines.wire_connector_id.circuit_green)
  if network == nil then return quotas end
  for _, entry in ipairs(network.signals or {}) do
    local signal = entry.signal
    -- Factorio omits type for item signals and defaults quality to normal.
    if (signal.type == nil or signal.type == 'item') and signal.name then
      local key = request.key(signal.name, signal.quality)
      local count = entry.count
      if count > 0 then quotas[key] = count end
    end
  end
  return quotas
end

return request
