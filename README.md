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

## Container Sizes

Train Containers are generated as straight line-shaped containers.

Supported layouts are:

```text
1 x N
N x 1
```

The maximum supported length is controlled by the mod startup setting.

The default maximum length is 27 tiles.

The supported range is currently:

```text
2 to 83 tiles
```

A Train Container prototype is generated for each supported length up to the configured maximum.

## Inventory Size

Container inventory capacity scales with the number of merged chests.

A configurable inventory-size limit prevents excessively large inventories.

Factorio quality modifiers are also respected when calculating the effective inventory capacity.

## Performance

Train Container is designed primarily to reduce the number of active chest entities in large builds.

Once created, a Train Container is a normal Factorio container entity.

The mod does not continuously scan containers and does not use `on_tick` processing for merge, split, inventory, circuit, or blueprint behavior.

Runtime scripting is only used when relevant player actions occur.

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
* Automatic train detection, LTN integration, Cybersyn integration, and custom train-station logic are not provided

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
