# Train Container

First-stage implementation of one-tile-wide train-length containers for Factorio 2.0.77.

## Factorio Version

This implementation targets `base >= 2.0.77`.

A local check with Factorio 2.0.77 showed that `ContainerPrototype.direction_count` is not consumed there and `container.picture` still expects a single `Sprite`. Because of that, true vertical/horizontal collision cannot be implemented as one rotatable `container` prototype in 2.0.77.

## Scope

This stage adds four sizes of ordinary `container`, with separate east-west and north-south prototypes for each size:

- `train-container-1`: 6 x 1 tiles, 96 slots
- `train-container-1-vertical`: 1 x 6 tiles, 96 slots
- `train-container-2`: 13 x 1 tiles, 192 slots
- `train-container-2-vertical`: 1 x 13 tiles, 192 slots
- `train-container-3`: 20 x 1 tiles, 288 slots
- `train-container-3-vertical`: 1 x 20 tiles, 288 slots
- `train-container-4`: 27 x 1 tiles, 384 slots
- `train-container-4-vertical`: 1 x 27 tiles, 384 slots

Recipes are enabled from the start and use one `steel-chest` per occupied tile. The east-west and north-south variants are separate craftable items.

This stage intentionally does not implement train detection, loading, unloading, custom circuit behavior, GUI, LTN, Cybersyn, inventory sharing, or snapping. The containers do support the same basic circuit connection as vanilla chests, so their inventory contents can be read by the circuit network.

## Infinity Containers

The mod always registers hidden `infinity-container` variants for editor-mode blueprint design:

- `train-container-1-infinity`
- `train-container-1-infinity-vertical`
- `train-container-2-infinity`
- `train-container-2-infinity-vertical`
- `train-container-3-infinity`
- `train-container-3-infinity-vertical`
- `train-container-4-infinity`
- `train-container-4-infinity-vertical`

These variants use the same footprints, inventory sizes, and circuit connector support as the normal containers, but open the infinity-container GUI with `gui_mode = "all"`. They are separate prototypes instead of changing the normal containers' prototype type, which keeps normal saves and blueprints stable.

Infinity train container items have no recipes and are hidden from normal crafting. Like the base game's `infinity-chest`, they are sorted into the `other` item subgroup for editor/cheat use. Blueprints containing them keep the infinity entities instead of being rewritten to normal containers.

## Rotation Approach

For Factorio 2.0.77 compatibility, each size and infinity state has two real prototypes:

- horizontal: `train-container-N` or `train-container-N-infinity`
- vertical: `train-container-N-vertical` or `train-container-N-infinity-vertical`

Both orientations expose `placeable_by` and have their own item. This keeps Factorio's normal blueprint, copy/cut selection, ghosts, construction, mining, and pipette behavior available on the real container entities.

`control.lua` only handles the parts Factorio can safely expose for two separate prototypes:

- pressing rotate while holding a train container item swaps the cursor item between the horizontal and vertical variant
- pressing rotate while holding a train container ghost cursor swaps the ghost between the horizontal and vertical variant

Pressing rotate while hovering a placed train container intentionally does nothing. A placed container is treated as already occupying its chosen footprint; changing it into the other orientation would require deleting and recreating the entity, which can collide with surrounding buildings and disturb circuit wiring or undo/redo state. In practice this makes placed-container rotation equivalent to a left-right flip for a symmetric chest: no visible or physical change.

Blueprint and clipboard rotation is intentionally not script-rewritten. Factorio's native blueprint rotation can rotate positions and entity directions, but it cannot treat two different `container` prototype names as two rotations of the same entity. The only script API available for changing those names is rewriting the blueprint entity list with `set_blueprint_entities()`, which is not safe enough in Factorio 2.0.77 for mixed blueprints, especially those containing rail or elevated-rail entities. Mixed blueprints therefore keep Factorio's native behavior: the blueprint rotates, but train container orientation names are not swapped by script.

## Cargo Ships Cleanup

Cargo Ships uses a hidden/selectable `bridge_gate` helper whose localized name is the railway movable bridge. Earlier experimental blueprint rewriting could leave that helper overlapping a train container in editor saves or clipboard-derived placements. Current Train Container code no longer creates or rewrites Cargo Ships entities.

If a stale Cargo Ships bridge helper is already overlapping a train container, run:

```text
/train-container-clean-cargoships-bridges
```

The command only removes `bridge_gate` and `bridge_base` entities whose bounding boxes overlap an existing train container. It is intentionally manual so legitimate Cargo Ships bridges elsewhere are not touched.

The unpacked working folder is named `TrainContainer`, so `info.json.name` is kept as `TrainContainer` for local loading. The gameplay prototype IDs are the requested `train-container-1` through `train-container-4`.

## Size Math

Lengths are generated from:

```lua
length = 6 * wagons + (wagons - 1)
```

The selection box spans the exact tile footprint:

```lua
-- vertical
{{-0.5, -length / 2}, {0.5, length / 2}}

-- horizontal
{{-length / 2, -0.5}, {length / 2, 0.5}}
```

The collision box leaves a 0.1 tile border on the long axis and a 0.1 tile border on the short axis:

```lua
-- vertical
{{-0.4, -length / 2 + 0.1}, {0.4, length / 2 - 0.1}}

-- horizontal
{{-length / 2 + 0.1, -0.4}, {length / 2 - 0.1, 0.4}}
```

Odd lengths are centered on a tile. Even lengths are centered on a tile boundary on the long axis and on a tile center on the short axis, matching Factorio's normal placement grid for rectangular buildings.

## Graphics

The entity graphics reuse MIT-licensed steel chest segment art from WideChests. Runtime sprites are assembled from end and middle segments as separate layers, so the art is tiled instead of stretched.

See `THIRD_PARTY_LICENSES.md` for source attribution and license text.
