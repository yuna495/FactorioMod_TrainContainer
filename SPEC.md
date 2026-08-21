# TrainContainer Specification

## Scope

TrainContainer provides one-tile-wide merged chest containers for Factorio 2.x. Normal gameplay prototypes are line-shaped `container` entities created from contiguous `steel-chest` rows or columns. Editor-only infinity variants are line-shaped `infinity-container` entities created from contiguous `infinity-chest` rows or columns and follow the same merge, split, inventory safety, quality, and circuit requirements.

The mod remains event-driven. It must not add `on_tick` polling or always-on monitoring for merge, split, inventory, circuit, blueprint, placement, or mining behavior.

## Merge Tool

The merge selection tool uses normal selection for both supported operations:

- selecting a contiguous straight line of two or more unmerged `steel-chest` or `infinity-chest` entities of the same quality merges them into the corresponding TrainContainer with that same quality;
- selecting exactly one existing TrainContainer splits it back into its original `steel-chest` or `infinity-chest` line;
- selections that mix unmerged chests with TrainContainers, contain multiple TrainContainers, or otherwise do not identify one unambiguous operation do nothing.

Only straight 1xN or Nx1 chest groups are valid merge targets. Groups with gaps, rectangles wider than one tile in both dimensions, unsupported lengths, or unsupported prototypes are ignored.

All selected source chests in a merge group must have the same `quality.name`. If any selected chest has a different quality, the merge does nothing and source chests, inventories, and wires remain unchanged.

## Inventory Safety

Inventory transfer must prefer preserving items over completing the transformation. Source entities must not be destroyed unless all readable item stacks were copied into the destination inventories.

Capacity checks use the actual destination prototype inventory size for the quality that will be created:

- when the destination is a TrainContainer, `prototype.get_inventory_size(defines.inventory.chest, quality)` is the full destination capacity and must not be multiplied by tile count again;
- when the destination is multiple source chest entities, capacity is one source chest's `get_inventory_size()` at the destination quality multiplied by the number of chests.

`move_inventories()` returns whether every readable source stack was copied. A failed transfer leaves source entities intact and the caller must not destroy them.

## Splitting TrainContainers

Splitting a real TrainContainer does not check, consume, or refund player inventory items. The original source chests were already consumed by the merge operation.

When a real TrainContainer is split:

- one real source chest entity is created for each occupied tile;
- every restored source chest uses `merged_chest.quality`;
- the TrainContainer inventory is safely distributed into the restored chests;
- the TrainContainer is destroyed only after the item transfer succeeds.

When an entity ghost TrainContainer is split, it remains a ghost-only transformation: one source chest ghost is created for each occupied tile and no real source chests are created.

## Circuit Connections

Circuit wire restoration is handled independently for red and green wires.

When splitting one TrainContainer into source chests, every external red or green circuit connection on the TrainContainer is recreated from every restored source chest to that same external connector. Script-created restoration may bypass normal reach checks so that existing long TrainContainer connections are not lost by distance limits after expansion.

When merging source chests into one TrainContainer, a wire color is restored only if every selected source chest had at least one wire connection of that color. The connection may be to another selected source chest or to an external entity. Only external connectors are deduplicated and reconnected to the TrainContainer; internal wires between selected source chests are not recreated.

## Blueprint And Rotation

When a player creates a blueprint or copy blueprint, normal steel TrainContainers are expanded inside the blueprint only. The source world entities are not changed.

Blueprint setup expansion follows the same footprint as runtime splitting:

- a 1xN normal TrainContainer is recorded as N `steel-chest` blueprint entities;
- an Nx1 normal TrainContainer is recorded as N `steel-chest` blueprint entities;
- each generated `steel-chest` preserves the TrainContainer blueprint entity's `quality`;
- other blueprint entities and tiles are otherwise preserved;
- editor infinity TrainContainers remain recorded as TrainContainers to preserve their editor blueprint workflow.

Blueprint circuit wires are rebuilt after expansion. Any wire that referenced a removed TrainContainer entity number is remapped to the generated `steel-chest` entity numbers. If both wire endpoints are expanded TrainContainers, each generated source chest is connected to each generated target chest for that wire color and connector pair. Wires to entities that are not present in the blueprint are not created.

Entity numbers for blueprint expansion are deterministic. Unchanged blueprint entities keep their existing entity numbers. The first generated `steel-chest` for a replaced TrainContainer reuses the TrainContainer's original entity number, and additional generated chests use new numbers above the previous maximum blueprint entity number.

Newly created blueprints no longer require TrainContainer-specific rotation for normal steel TrainContainers because they contain steel chest rows or columns. The custom blueprint rotation handler remains for compatibility with older blueprints that still contain TrainContainer prototype names.
