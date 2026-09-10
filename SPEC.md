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

The maximum TrainContainer length is fixed by the mod at 83 tiles. It is not user-configurable, so all supported line-length prototypes remain available for save compatibility.

## Inventory Safety

Inventory transfer must prefer preserving items over completing the transformation. Source entities must not be destroyed unless all readable item stacks were copied into the destination inventories.

There is no setting or code path that intentionally voids items during merge or split.

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

## Train-adjacent Graphics

Normal steel and editor infinity TrainContainers use dedicated train-loading graphics when their one-tile-wide footprint has length `N = 7k - 1`, for integer `k >= 1`. With the current maximum length of 83, these lengths are 6, 13, 20, 27, 34, 41, 48, 55, 62, 69, 76, and 83, in both orientations. All other lengths retain the existing wide-chest/high-chest graphics.

The dedicated design follows `列車隣接コンテナデザイン.png`: a narrow industrial container with a relatively flat metal lid, recessed side rollers/transfer openings, reinforcement, and restrained yellow/black warning marks. Mechanical details remain inside the one-tile ground footprint. Both long sides have transfer details because direct loading supports either side.

Graphics are assembled from reusable T6 (six tiles), J (one tile), and L/R end-cap modules: `L + T6 + (J + T6) * (k - 1) + R`. End caps overlay the ends inside the footprint and add no length. Horizontal and vertical modules are rendered separately with transparent body and shadow layers, at 96 source pixels per tile and sprite scale 1/3 (1.5 times the original source resolution, with unchanged in-game size). The data-stage sprite generator places these modules as layers; no length-specific full sprite is required. Editable Blender sources separate T6, J, end caps, and render setup.

Materials should read as worn metal alongside the vanilla steel chest: contrasted metallic highlights, directional abrasion, uneven roughness, dark oily recesses, and restrained warm oxidation. Avoid uniformly colored, smooth plastic-looking panels. These surface details are baked into the static module sprites.

This is only a prototype appearance choice, independent of nearby trains and loading mode. It does not add entities, recipes, or transfer restrictions. Prototype names, collision/selection boxes, capacities, and existing save/blueprint behavior are unchanged.

### Status lamps

The existing round beacon on each J module uses engine-managed rendering. All beacons on one container share the following status:

| Condition | Color | Display |
| --- | --- | --- |
| Loading mode `off` | Yellow | Steady |
| Loading mode `load`/`unload`, no adjacent cargo wagon and no recent item movement | Green | Steady (ready/waiting) |
| Loading enabled, adjacent cargo wagon, no recent item movement | Yellow | Blinking |
| Recent successful direct loading or unloading | Green | Blinking |
| Future error state (not currently generated) | Red | Reserved |

Loading mode is checked first. When it is `off`, lamp refresh sets steady yellow and returns without any wagon adjacency scan. Disabling loading clears the lamp's recent-transfer timestamp, so re-enabling it cannot revive stale activity. With loading enabled, adjacency uses the same long-side geometric checks as direct loading, independently of train state. A moving train, a train stopped away from a station, an empty source, a full destination, or a filter excluding all items is yellow blinking when adjacent and idle; these are not treated as errors.

A successful transfer calls `status_lamps.note_transfer(container)`, immediately sets green blinking, and records its tick. Recent activity takes priority while loading is enabled and the last transfer was less than 60 ticks ago. Once activity expires, the next refresh returns to yellow blinking if a wagon is adjacent, or steady green otherwise. Lamp status is refreshed every 60 ticks only for registered containers with J modules, so timeout is displayed less than 120 ticks after the last movement. `train_transfer.set_mode()` also calls `status_lamps.refresh(entity)` immediately after a mode change, without waiting for that periodic refresh.

State changes update the existing rendering object's `color` and `blink_interval` properties: 0 for steady display, 30 for 30 ticks lit followed by 30 ticks unlit. Unchanged states do not rewrite rendering properties, and blinking does not require Lua tick updates or object recreation. This visual status sampling is independent of inventory-transfer scheduling and does not transfer items. No global per-tick scan is added. Red is not used for normal loading/unloading.

The registry in `storage.train_status_lamps` holds container references, rendering objects, destruction registrations, and the most recent transfer tick. Build/revive/clone events register lamps, destruction removes them, save/load preserves them, and initialization/configuration changes rebuild the registry once for existing entities. The periodic lamp handler is disabled when the registry is empty. Rendering targets follow their container; all players see the same status. Ghosts are not animated. The 6-tile T6 has no J beacon, and the yellow end-cap tabs remain non-emissive safety markings. No lamp is added to the ordinary chest graphics.

## Direct Train Loading

Normal steel TrainContainers and editor-only infinity TrainContainers support direct item transfer with adjacent `cargo-wagon` type entities without inserters, including cargo wagons added by other mods. Infinity TrainContainers use the same runtime mode, GUI, wagon search, and transfer behavior as steel TrainContainers.

Each placed TrainContainer has one runtime loading mode:

- `off`: no direct wagon transfer; this is the default for new TrainContainers and for existing save entities with no stored mode;
- `load`: transfer items from the TrainContainer inventory to adjacent cargo wagon inventories;
- `unload`: transfer items from adjacent cargo wagon inventories to the TrainContainer inventory.

Loading mode is per placed entity and is stored in Factorio 2.x `storage` keyed by the TrainContainer's stable runtime identifier. Only non-`off` modes need persistent storage.

The mode is changed through a per-player GUI that appears when a player opens a steel or infinity TrainContainer. The GUI is anchored to the left of the vanilla container/inventory window using the relative GUI container anchor, so Factorio manages its position alongside the inventory UI. It must not replace or block the normal container inventory GUI. Old screen-left panels are removed when rebuilding or reopening the GUI. Player GUI state is per player.

Each placed TrainContainer may store up to five item-and-quality filters and a filter mode (`whitelist` by default, or `blacklist`). Empty slots and duplicate filters are allowed; the same item at different qualities is distinct. With zero valid filters, both modes allow all item stacks, preserving the existing unrestricted-transfer behavior. With one to five filters, whitelist allows only stacks matching any configured item name and quality name; blacklist excludes those matches and allows all others. Loading and unloading use the same predicate.

Schema version 4 stores `storage.train_transfer.filters[unit_number] = { mode = "whitelist" | "blacklist", slots = { [1..5] = { name = ITEM, quality = QUALITY } }, circuit_set_filters = false | true }`, with absent indices for empty slots. An absent configuration means an empty whitelist with circuit filters disabled. The configuration is independent of loading mode, remains editable while loading is off, is discarded on entity removal/split, and is not saved to blueprints or copied by settings copy/paste. Old single item-and-quality filters migrate to whitelist slot 1; older string-only filters migrate to whitelist slot 1 with normal quality. Schema 3 configurations retain their mode and all slots; older configurations default `circuit_set_filters` to false. Unknown item prototypes are discarded and unavailable qualities fall back to normal, as before. Migrating also updates saved active-group filter snapshots and clears their retry deadline so legacy settings are not retained there.

The GUI uses standard Factorio frame/label/slot styles, the standard two-state switch labeled with the inserter whitelist/blacklist locale keys, and five `item-with-quality` choose-element buttons in one row. Every slot or filter-mode edit saves immediately and rebuilds the affected active transfer groups to use the new configuration without an old retry delay. Filter edits do not change loading mode or lamp semantics. Open GUI views of the same container synchronize, and closing a GUI does not write back stale settings. Existing open panels are rebuilt on configuration changes.

The GUI may show a compact status line describing whether direct transfer is off, no nearby cargo wagon was found, a nearby wagon is not stopped at a station, long-side adjacency failed, or eligible adjacent wagons were found.

When a player hovers over or opens a steel or infinity TrainContainer, the mod may draw player-local translucent yellow filled rectangles showing the long-side cargo wagon center-point search bands used by direct train loading diagnostics. This rendering is informational and must not affect transfer behavior.

Only directly adjacent `cargo-wagon` type entities are eligible transfer targets. A wagon is adjacent only when its center position falls within one of the TrainContainer's long-side search bands and its selection bounding box overlaps the TrainContainer along that long axis. Center-point side bands are used for the perpendicular side test because cargo wagon selection boxes can overlap nearby containers unevenly between rail lanes. Wagons near a TrainContainer short end are not eligible.

Direct transfer only runs while the train is stopped at a station, represented by `defines.train_state.wait_station`. The implementation remains event-driven: train state changes register or unregister active loading groups, and periodic processing is limited to currently active groups. The mod must not scan all TrainContainers, all trains, or all surfaces every tick.

When one TrainContainer is adjacent to multiple cargo wagons in an active stopped train, the eligible wagons are processed in round-robin order. Complete equalization is not required.

Without a green wire on the request input, transfer speed is controlled by named runtime constants: at most 500 items per TrainContainer every 10 ticks (3000 items per second at 60 UPS). Normal transfer retains manual filtering, round-robin and the existing 60-tick retry delay.

### Green circuit quantity control

Each real steel/infinity TrainContainer owns exactly one `train-container-request-input` auxiliary entity. It is a passive lamp-type circuit receiver with no inventory and no signal output. It has no item, recipe, mining result, collision, light emission or independent operation. Both its on and off lamp sprites are transparent, including after either flip operation. Its higher-priority selection area initially sits inside the leftmost tile (horizontal) or topmost tile (vertical). The input accepts a player's green circuit wire without changing the container footprint or graphics selection. Its red connector is ignored by transfer logic.

The body remains a normal chest: its red inventory output and `read_contents` setting are untouched. Its green network is never read by direct transfer. Self-inventory subtraction is removed entirely. Connect external quantity requests to the auxiliary input's green connector; never join this request network to the body's inventory network.

Only a real green wire connection on the auxiliary input enables generic circuit-controlled bulk loading/unloading. Detection uses the input's `get_wire_connector(defines.wire_connector_id.circuit_green, false).real_connection_count`, excluding ghost wires. Connected with no positive item signals means no transfer, never a fallback to normal mode. Without an input green wire, even if the body's green wire is connected, normal manual transfer applies.

Each positive item-and-quality signal read through the input's `get_circuit_network(...).signals` is the maximum quantity allowed during the current 10-tick processing cycle. Zero/negative and non-item signals are ignored; missing quality means normal. No body inventory is added to or subtracted from these quantities. The network still exposes Factorio's last-tick values, but their interpretation is independent of current body inventory, eliminating the self-output timing mismatch. The guarantee is against the sampled positive request, not future changes still propagating through external combinators.

Both vanilla flip controls (horizontal and vertical) toggle the input endpoint: left/right on horizontal containers and top/bottom on vertical containers. With an empty cursor, hovering either the body or its input selects the owner. Linked custom-input controls are used because non-flippable chest entities do not reliably fire `on_player_flipped_entity`; there is no second flip-event listener, so each press toggles once. Blueprint/item/ghost cursors retain normal vanilla behavior without moving placed inputs. The choice is stored as `reversed` on the owner record, defaults to false for existing saves, survives rebuild/save/load/helper repair, and is discarded on owner removal. Clones and blueprints do not inherit it. The body footprint, loading mode, filters, lamps and body wiring are not changed.

Ownership is stored in `storage.train_request_inputs.owners[unit_number]` with owner/input references and object-destruction registrations. Init/configuration changes add missing inputs and remove orphans while retaining valid existing inputs and wires. Build/revive/clone events create one input per owner; duplicate registration is idempotent. Mining, destruction, split and surface removal remove the helper through object-destruction callbacks. Script-raised owner teleports synchronize the helper immediately; force changes or unannounced script moves synchronize on the next active-transfer/open-GUI access or configuration rebuild. A cross-surface move or failed helper teleport recreates it unwired on the chosen side rather than continuing to read an old remote network. Unexpected helper destruction recreates an unwired replacement; independently cloned helper entities are removed. Inputs persist while Loading mode is OFF and across save/load. No periodic world scan is added.

Migration from the provisional body-green implementation preserves manual/circuit filter settings (schema 4), creates the new inputs, and does not rewire the body: old green request wires must be manually moved to the input. Inputs and their wiring are not blueprintable and are not copied by settings copy/paste. A cloned/new owner receives a new unwired input. Existing body blueprint expansion and circuit restoration remain unchanged.

Circuit-controlled processing bypasses the normal 500-item limit. It transfers stack portions through the existing safe inventory transfer path, bounded by each request, source availability and destination capacity/restrictions. Local item-and-quality quotas are decremented by actual accepted quantities and shared across all stacks, wagons and stopped-train groups for that container in the same cycle. Round-robin wagon selection is retained. No delivery total or remaining quota persists between cycles. An empty source or blocked destination is reconsidered on the next 10-tick circuit cycle, allowing later supplies to move. Green connection changes are checked before normal retry handling; disconnection returns to normal processing on the next cycle.

`circuit_set_filters=false` (default) applies positive green quantities AND the saved manual whitelist/blacklist predicate. With `circuit_set_filters=true`, positive green signals form a dynamic whitelist and manual filtering is bypassed, but its settings remain saved. Without a green wire on the request input, manual filters always apply regardless of this setting. Connected with zero positive requests transfers nothing in either toggle state. Loading mode off retains all settings and performs no transfer. Lamp semantics are unchanged, including adjacent/idle yellow blinking and successful transfer green blinking.

The relative GUI adds a standard Circuit network section and Set filters checkbox. Without a real green wire on the request input the checkbox is disabled, the connection label says manual transfer is active, and manual controls remain enabled. With input green connected, the checkbox is enabled; checking it disables manual slot/mode controls without deleting their settings. Edits save immediately and refresh active groups and other viewers. Only open panels are checked every 15 ticks for wire changes; the GUI handler is disabled when none are open and restored on save load. No global entity or per-tick scan is added.

Use a dedicated request green network, preferably **one TrainContainer per request network**. Inventory signals from any chest (including the body) or unrelated item signals must not be wired into the input request network: all positive item signals there are treated as requests without subtraction. Multiple TrainContainers do not coordinate quotas and can over-transfer on a shared network. The external circuit must continuously supply remaining quantities, accounting for circuit propagation delay before the next transfer cycle. A constant `iron-plate=2000` authorizes up to 2000 on **each** cycle until changed or disabled, not a one-time total.

This feature has no Cybersyn2 API dependency or entity searches. Cybersyn2 and LTN are external circuit examples only: a provider may combine a negative pickup manifest with train contents and multiply by -1 to supply positive remaining requests. Existing hidden inserter shim geometry, creation/removal and station integration are unchanged.

Direct transfer must never intentionally void items. Items are removed from the source only after the destination accepts them. Quality and other item stack metadata must be preserved during transfer, and destination inventory filters, bars, stack limits, and cargo wagon filters must be respected. The implementation should avoid per-cycle temporary inventory allocation when Factorio runtime APIs can safely move item stacks directly while preserving metadata and respecting destination constraints.

When direct transfer is enabled, the mod may create hidden inactive inserter helper entities for compatibility with train logistics mods that infer station cargo capability from inserters beside rails. These helpers do not perform item transfer, are not visible, selectable, minable, deconstructable, or blueprintable, and must be removed when direct transfer is disabled or when the owning TrainContainer is removed. Helper inserters are considered at the first TrainContainer tile and then every five tiles along the long axis. For each point, nearby rails on either long side may receive a helper with its pickup position aligned to that rail so other mods can associate the helper with the station equipment layout. Their construction and removal may raise script-built/script-destroyed events so other mods can update their station equipment caches.

Blueprint behavior is unchanged. Loading mode is not written to blueprint tags, restored from blueprints, or transferred by copy/paste settings. Normal steel TrainContainers are still expanded to `steel-chest` blueprint entities during blueprint setup.

When a TrainContainer is split, mined, destroyed, or otherwise removed, its stored loading mode and any active transfer state are discarded. Split `steel-chest` entities do not inherit loading mode. Merging `steel-chest` entities creates a TrainContainer in `off` mode.
