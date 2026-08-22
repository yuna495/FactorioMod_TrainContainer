# Train Container

Train Container is a Factorio 2.0 mod that lets you merge straight rows or columns of chests into a single large container.

It is designed mainly for train stations and other builds where many adjacent chests would otherwise be required.

The mod is event-driven and does not use `on_tick` processing for normal operation.

## Factorio Version

Tested with:

* Factorio 2.0.77

`info.json` currently targets Factorio 2.0.

## Features

* Merge contiguous steel chests into one large Train Container
* Supports both horizontal and vertical layouts
* Split a Train Container back into the original chest row
* Preserves item contents during merge and split
* Prevents transformations when items cannot be moved safely
* Supports Factorio quality
* Preserves supported circuit-network connections
* Blueprint and copy/paste support
* Blueprint rotation works by recording normal chests instead of Train Container entities
* Editor-only infinity-container support
* Direct loading and unloading between Train Containers and adjacent cargo wagons
* Optional item + quality filter for direct train loading
* Cybersyn2 station-equipment compatibility helpers
* No continuous runtime polling

## Basic Usage

Use the Train Container merge tool to select chests.

### Merge Chests

Place two or more `steel-chest` entities in a straight contiguous row or column.

For example:

```text
[C][C][C][C][C][C]
```

Select the entire row with the merge tool.

The chests are replaced by one Train Container occupying the same area:

```text
[      Train Container      ]
```

Vertical rows work the same way.

Only straight layouts are supported:

```text
1 x N
N x 1
```

Rectangular groups such as `2 x 3` are not supported.

There must be no gaps in the selected row.

### Split a Train Container

Select a single existing Train Container with the same merge tool.

The container is converted back into its original row or column of steel chests.

No additional steel chests are required from the player's inventory.

For example:

```text
[      Train Container      ]
```

becomes:

```text
[C][C][C][C][C][C]
```

The restored chests keep the Train Container's quality.

## Inventory Safety

Item preservation has priority over completing a merge or split.

A source entity is not destroyed unless all readable inventory stacks can be transferred successfully.

If the destination does not have enough inventory capacity, the transformation is cancelled instead of deleting items.

This applies to both:

* steel chests → Train Container
* Train Container → steel chests

## Quality Support

All chests selected for a merge must have exactly the same quality.

Example:

```text
Rare steel chest
Rare steel chest
Rare steel chest
Rare steel chest
```

becomes one Rare Train Container.

Splitting that container restores Rare steel chests.

If the selected chests contain mixed qualities, the merge is cancelled.

Example:

```text
Rare
Rare
Uncommon
Rare
```

will not merge.

The original chests, inventories, and circuit connections remain unchanged.

## Circuit Network

Red and green circuit wires are handled independently.

### Chests → Train Container

A wire color is preserved only when every selected source chest has at least one connection of that color.

Connections between the selected chests themselves count when determining whether all chests are connected.

Only connections to entities outside the selected chest group are recreated on the resulting Train Container.

Example:

```text
[C]--red--[C]--red--[C]--red--[C]
 |
 +--red-- Combinator
```

All selected chests participate in the red network, so the resulting Train Container keeps the external red-wire connection.

If even one selected chest has no red-wire connection at all, preservation of the red network is not required.

The same rule is applied separately to green wires.

### Train Container → Chests

When a Train Container is split, its external red and green circuit connections are recreated on every restored chest.

For example:

```text
Train Container --red-- Combinator
```

becomes conceptually:

```text
Chest 1 --red-- Combinator
Chest 2 --red-- Combinator
Chest 3 --red-- Combinator
...
```

Script-created restoration may bypass normal wire reach checks so that existing connections are not lost simply because the Train Container was replaced by multiple chests.

## Blueprint and Copy/Paste

Normal steel Train Containers are not stored as Train Container entities inside newly created blueprints.

Instead, they are expanded into their original steel-chest rows when the blueprint or copy operation is created.

Example:

World:

```text
[      Train Container      ]
```

Blueprint:

```text
[C][C][C][C][C][C]
```

This allows Factorio's normal blueprint rotation and mirroring behavior to work without requiring special Train Container rotation logic.

### Quality

Each generated blueprint chest keeps the quality of the original Train Container.

A Rare Train Container is therefore recorded as Rare steel chests.

### Circuit Wires

Circuit connections are rebuilt when the Train Container is expanded inside the blueprint.

Connections are remapped to the generated steel chests so that the recorded circuit network matches the result of splitting the Train Container normally.

### Placement

Blueprint placement does not automatically recreate Train Containers.

Blueprints place normal steel-chest ghosts or steel chests.

If desired, the resulting chest row can then be merged again using the Train Container merge tool.

This behavior is intentional.

### Older Blueprints

The legacy Train Container blueprint rotation handler is retained for compatibility with older blueprints that may still contain Train Container prototype names directly.

## Infinity Containers

The mod also provides editor-oriented Train Container variants based on `infinity-chest`.

Infinity chests can be merged into line-shaped infinity Train Containers using the same general merge system.

They can also be split back into their source infinity chests.

Infinity Train Containers remain recorded as Train Container entities in blueprints rather than being rewritten to ordinary steel chests.

This preserves their editor-specific behavior.

Infinity Train Containers also support direct train loading and unloading. This is intended for editor testing, blueprint checks, and station-layout experiments.

## Direct Train Loading

Train Containers can transfer items directly to or from adjacent `cargo-wagon` entities without visible inserters or loaders.

This feature is available for both:

* normal steel Train Containers
* editor infinity Train Containers

Open a Train Container to show the direct transfer GUI. The normal container inventory GUI remains available.

The mode setting is stored per placed Train Container:

* `Off`: no direct transfer
* `Load to wagon`: move items from the Train Container into adjacent cargo wagons
* `Unload from wagon`: move items from adjacent cargo wagons into the Train Container

Direct transfer only runs while the train is stopped at a station. A cargo wagon must be beside the long side of the Train Container; wagons at the short ends are ignored.

When multiple adjacent cargo wagons are eligible, they are processed in round-robin order.

The current transfer limit is:

```text
100 items / 10 ticks / Train Container
```

At 60 UPS this is up to:

```text
600 items/s / active Train Container
```

The transfer speed is fixed for now. It does not scale with Train Container length, number of adjacent wagons, or quality.

### Direct Transfer Filter

The direct transfer GUI includes an optional item filter.

The filter stores both:

* item prototype
* quality

For example, filtering `iron-plate / normal` transfers only normal iron plates. Uncommon, rare, or higher-quality iron plates are not transferred by that filter.

If no filter is set, all items and all qualities are eligible.

The same filter applies to both loading and unloading.

### Transfer Safety

Direct transfer uses Factorio item-stack transfer APIs so item stack metadata is preserved where the game supports it, including quality and other stack data.

Destination constraints are respected, including:

* cargo wagon inventory filters
* inventory bars
* stack size limits
* full destination inventories

Items are removed from the source only when the destination accepts them.

### Search-Area Display

When a Train Container is selected or opened, the mod may draw translucent yellow rectangles showing the wagon-detection area.

This is a diagnostic overlay only. It does not affect transfer behavior.

## Cybersyn2 Compatibility

Cybersyn2 detects station equipment by looking for inserters and loaders near rails.

Because Train Container direct transfer does not use real inserters, the mod creates hidden inactive helper inserters when direct transfer is enabled. These helpers exist only so Cybersyn2 and similar station logic can recognize that the Train Container side can load or unload cargo wagons.

The helper inserters:

* are invisible
* are inactive
* do not transfer items
* consume no energy
* have no collision
* cannot be selected, mined, deconstructed, or blueprinted
* are removed when direct transfer is turned off or when the owning Train Container is removed

Helpers are placed at the first Train Container tile and then every five tiles along the long axis, on rail-facing sides where nearby rails are found.

Changing between load and unload mode keeps existing helpers when their position does not need to change. Simply opening or closing the GUI does not recreate helpers.

The actual item movement is always performed by Train Container runtime logic, not by the helper inserters.

## Container Sizes

Train Containers are generated as straight line-shaped containers.

Supported layouts are:

```text
1 x N
N x 1
```

Supported lengths are:

```text
2 to 83 tiles
```

The maximum length is fixed at 83 tiles.

All supported Train Container prototypes are always generated so that existing
containers remain available when loading saved games.

## Inventory Size

Container inventory capacity scales with the number of merged chests.

A configurable inventory-size limit prevents excessively large inventories.

Factorio quality modifiers are also respected when calculating the effective inventory capacity.

## Performance

Train Container is designed primarily to reduce the number of active chest entities in large builds.

Once created, a Train Container is a normal Factorio container entity.

The mod does not continuously scan containers and does not use `on_tick` processing for merge, split, inventory, circuit, or blueprint behavior.

Runtime scripting is only used when relevant player actions occur.

Direct train loading uses a 10-tick handler only while at least one stopped train has active adjacent Train Container transfer groups. When no active transfer exists, the periodic handler is disabled.

Cybersyn2 helper inserters are rebuilt only when needed, such as when direct transfer is enabled, disabled, or compatibility state is rebuilt after configuration changes. Opening the GUI does not rebuild them.

## Cargo Ships Cleanup

Older experimental versions could leave hidden Cargo Ships bridge helper entities overlapping Train Containers in some saves.

If this occurs, run:

```text
/train-container-clean-cargoships-bridges
```

The command removes overlapping:

```text
bridge_gate
bridge_base
```

entities only where they overlap an existing Train Container.

The command is manual so legitimate Cargo Ships bridges elsewhere are not affected.

## Limitations

* Only straight `1 x N` and `N x 1` chest groups are supported
* Mixed-quality chests cannot be merged
* Blueprint placement creates normal chests rather than automatically recreating Train Containers
* Train Container transformations require enough inventory capacity to preserve all items
* Direct transfer works only with cargo wagons stopped at train stations
* Direct transfer does not read train schedules, station names, requests, or circuit conditions by itself
* Cybersyn2 compatibility is detection-oriented; Cybersyn2 may see the hidden helper inserters, but actual item movement is still handled by Train Container

## Credits

Train Container contains code and graphics derived from:

**WideChests**
by Atria1234

WideChests is licensed under the MIT License.

See:

```text
THIRD_PARTY_LICENSES.md
```

for full attribution and third-party license information.

## License

Train Container is released under the MIT License.

See:

```text
LICENSE
```
