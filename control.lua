require('init')
require('control_init')

require('scripts.event_handlers.merge_chest')
require('scripts.event_handlers.rotate_blueprint')
require('scripts.event_handlers.setup_blueprint')
require('scripts.event_handlers.split_chest')
require('scripts.event_handlers.train_transfer_gui')

commands.add_command(
	'train-container-clean-cargoships-bridges',
	{ 'command-help.train-container-clean-cargoships-bridges' },
	function(command)
		local player = command.player_index and game.get_player(command.player_index)
		local train_container_names = {}

		for name, _ in pairs(prototypes.entity) do
			if MergingChests.get_merged_chest_info(name) then
				table.insert(train_container_names, name)
			end
		end

		local removed = 0
		for _, surface in pairs(game.surfaces) do
			for _, container in pairs(surface.find_entities_filtered({ name = train_container_names })) do
				if container.valid then
					for _, bridge in pairs(surface.find_entities_filtered({
						area = container.bounding_box,
						name = { 'bridge_gate', 'bridge_base' },
					})) do
						if bridge.valid then
							bridge.destroy()
							removed = removed + 1
						end
					end
				end
			end
		end

		local message = { 'message.train-container-cargoships-bridges-cleaned', removed }
		if player then
			player.print(message)
		else
			game.print(message)
		end
	end
)
