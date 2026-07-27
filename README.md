# Train Container

First-stage implementation of one-tile-wide train-length containers for Factorio 2.0.77.

## Factorio Version

This implementation targets `base >= 2.0.77`.

A local check with Factorio 2.0.77 showed that `ContainerPrototype.direction_count` is not consumed there and `container.picture` still expects a single `Sprite`. Because of that, true vertical/horizontal collision cannot be implemented as one rotatable `container` prototype in 2.0.77.

## Scope

This stage adds four ordinary `container` prototypes:

- `train-container-1`: 1 x 6 tiles, 96 slots
- `train-container-2`: 1 x 13 tiles, 192 slots
- `train-container-3`: 1 x 20 tiles, 288 slots
- `train-container-4`: 1 x 27 tiles, 384 slots

Recipes are enabled from the start and use one `steel-chest` per occupied tile.

This stage intentionally does not implement train detection, loading, unloading, custom circuit behavior, GUI, LTN, Cybersyn, inventory sharing, or snapping. The containers do support the same basic circuit connection as vanilla chests, so their inventory contents can be read by the circuit network.

## Infinity Containers

The mod always registers hidden `infinity-container` variants for editor-mode blueprint design:

- `train-container-1-infinity`
- `train-container-2-infinity`
- `train-container-3-infinity`
- `train-container-4-infinity`

These variants use the same footprints, rotation placement flow, inventory sizes, and circuit connector support as the normal containers, but open the infinity-container GUI with `gui_mode = "all"`. They are separate prototypes instead of changing the normal containers' prototype type, which keeps normal saves and blueprints stable.

Infinity train container items have no recipes and are hidden from normal crafting. Like the base game's `infinity-chest`, they are sorted into the `other` item subgroup for editor/cheat use. Blueprints containing them keep the infinity entities instead of being rewritten to normal containers.

## Rotation Approach

For Factorio 2.0.77 compatibility, each size has two real container prototypes:

- `train-container-N`: horizontal `length x 1`
- `train-container-N-vertical`: vertical `1 x length`

The player-facing item remains `train-container-N`. It places a short-lived `simple-entity-with-owner` placeholder named `train-container-N-placeable`; `control.lua` immediately replaces that placeholder with the correct real `container` based on placement direction. The placeholder is not a persistent storage/helper entity and has no inventory.

The real horizontal/vertical containers are marked `hidden` and do not advertise `placeable_by`; this keeps the editor entity list from showing separate fixed horizontal, rotatable placeholder, and fixed vertical entries for each size. The player/editor-facing item places the short-lived placeholder, which keeps each size to one rotatable entry.

Rotate the container while it is still in the player's hand to choose the horizontal or vertical footprint before placement. Already placed containers are not script-rotated in this stage, because swapping a live long chest into the other orientation can collide with neighboring buildings and would require extra user-facing handling outside the first-stage scope. Blueprints made from placed train containers are normalized back to the rotatable placeholder so construction robots can build them from the visible item; existing blueprints that still contain fixed internal names are converted when their ghosts are pasted.

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

Odd lengths are centered on a tile. Even lengths are centered on a tile boundary, matching Factorio's normal placement behavior for even-sized buildings.

## Graphics

The entity graphics reuse MIT-licensed steel chest segment art from WideChests. Runtime sprites are assembled from end and middle segments as separate layers, so the art is tiled instead of stretched.

See `THIRD_PARTY_LICENSES.md` for source attribution and license text.
