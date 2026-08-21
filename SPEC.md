# TrainContainer Specification

## Scope

TrainContainer provides one-tile-wide merged steel chest containers for Factorio 2.x. Normal gameplay prototypes are line-shaped `container` entities created from contiguous `steel-chest` rows or columns. Editor-only infinity variants exist for blueprint design and are not split into real chests by the merge tool.

The mod remains event-driven. It must not add `on_tick` polling or always-on monitoring for merge, split, inventory, circuit, blueprint, placement, or mining behavior.

## Merge Tool

The merge selection tool uses normal selection for both supported operations:

- selecting a contiguous straight line of two or more unmerged `steel-chest` entities of the same quality merges them into the corresponding TrainContainer with that same quality;
- selecting exactly one existing TrainContainer splits it back into its original `steel-chest` line;
- selections that mix unmerged chests with TrainContainers, contain multiple TrainContainers, or otherwise do not identify one unambiguous operation do nothing.

Only straight 1xN or Nx1 chest groups are valid merge targets. Groups with gaps, rectangles wider than one tile in both dimensions, unsupported lengths, or unsupported prototypes are ignored.

All selected steel chests in a merge group must have the same `quality.name`. If any selected chest has a different quality, the merge does nothing and source chests, inventories, and wires remain unchanged.

## Inventory Safety

Inventory transfer must prefer preserving items over completing the transformation. Source entities must not be destroyed unless all readable item stacks were copied into the destination inventories.

Capacity checks use the actual destination prototype inventory size for the quality that will be created:

- when the destination is a TrainContainer, `prototype.get_inventory_size(defines.inventory.chest, quality)` is the full destination capacity and must not be multiplied by tile count again;
- when the destination is multiple normal `steel-chest` entities, capacity is one chest's `get_inventory_size()` at the destination quality multiplied by the number of chests.

`move_inventories()` returns whether every readable source stack was copied. A failed transfer leaves source entities intact and the caller must not destroy them.

## Splitting TrainContainers

Splitting a real TrainContainer does not check, consume, or refund player inventory items. The original steel chests were already consumed by the merge operation.

When a real TrainContainer is split:

- one real `steel-chest` entity is created for each occupied tile;
- every restored steel chest uses `merged_chest.quality`;
- the TrainContainer inventory is safely distributed into the restored chests;
- the TrainContainer is destroyed only after the item transfer succeeds.

When an entity ghost TrainContainer is split, it remains a ghost-only transformation: one `steel-chest` ghost is created for each occupied tile and no real steel chests are created.

## Circuit Connections

Circuit wire restoration is handled independently for red and green wires.

When splitting one TrainContainer into steel chests, every external red or green circuit connection on the TrainContainer is recreated from every restored steel chest to that same external connector. Script-created restoration may bypass normal reach checks so that existing long TrainContainer connections are not lost by distance limits after expansion.

When merging steel chests into one TrainContainer, a wire color is restored only if every selected source chest had at least one wire connection of that color. The connection may be to another selected source chest or to an external entity. Only external connectors are deduplicated and reconnected to the TrainContainer; internal wires between selected source chests are not recreated.

## Blueprint And Rotation

Existing blueprint and ghost behavior must remain compatible with the current prototype names, `placeable_by` definitions, and custom blueprint rotation handler. The rotation handler may swap TrainContainer prototype names in blueprint entities, but this feature is not redesigned as part of merge or split changes.
