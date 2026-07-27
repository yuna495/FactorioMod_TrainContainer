local definitions = { 1, 2, 3, 4 }
local suffixes = { "", "-infinity" }
local item_rotations = {}
local train_container_names = {}

for _, wagons in ipairs(definitions) do
  local base_name = "train-container-" .. wagons

  for _, suffix in ipairs(suffixes) do
    local horizontal_name = base_name .. suffix
    local vertical_name = base_name .. suffix .. "-vertical"

    item_rotations[horizontal_name] = vertical_name
    item_rotations[vertical_name] = horizontal_name

    table.insert(train_container_names, horizontal_name)
    table.insert(train_container_names, vertical_name)
  end
end

local function rotate_cursor_item(player)
  local stack = player.cursor_stack

  if not stack or not stack.valid_for_read then
    return false
  end

  local target_name = item_rotations[stack.name]

  if not target_name then
    return false
  end

  local count = stack.count
  local quality = stack.quality and stack.quality.name or nil
  local ok = false

  if quality then
    ok = pcall(function()
      stack.set_stack({ name = target_name, count = count, quality = quality })
    end)
  end

  if not ok then
    ok = pcall(function()
      stack.set_stack({ name = target_name, count = count })
    end)
  end

  return ok
end

local function rotate_cursor_ghost(player)
  local ok, ghost = pcall(function()
    return player.cursor_ghost
  end)

  if not ok or not ghost then
    return false
  end

  local target_name = item_rotations[ghost.name]

  if not target_name then
    return false
  end

  local target_ghost = {
    name = target_name,
  }

  if ghost.quality then
    target_ghost.quality = ghost.quality
  end

  return pcall(function()
    player.cursor_ghost = target_ghost
  end)
end

local function on_rotate_input(event)
  local player = game.get_player(event.player_index)

  if not player then
    return
  end

  if rotate_cursor_item(player) then
    return
  end

  rotate_cursor_ghost(player)
end

script.on_event("train-container-rotate", on_rotate_input)
script.on_event("train-container-reverse-rotate", on_rotate_input)

commands.add_command(
  "train-container-clean-cargoships-bridges",
  { "command-help.train-container-clean-cargoships-bridges" },
  function(command)
    local player = command.player_index and game.get_player(command.player_index)
    local removed = 0

    for _, surface in pairs(game.surfaces) do
      for _, container in pairs(surface.find_entities_filtered({ name = train_container_names })) do
        if container.valid then
          for _, bridge in pairs(surface.find_entities_filtered({
            area = container.bounding_box,
            name = { "bridge_gate", "bridge_base" },
          })) do
            if bridge.valid then
              bridge.destroy()
              removed = removed + 1
            end
          end
        end
      end
    end

    local message = { "message.train-container-cargoships-bridges-cleaned", removed }

    if player then
      player.print(message)
    else
      game.print(message)
    end
  end
)
