# Train Container

Merge rows of steel chests into a single large container for compact train stations and shared storage. Load and unload adjacent cargo wagons directly, without inserters or loaders.

## Requirements

- **Factorio 2.0**. Cybersyn2 is optional; no other mod is required.
- Enable **Train Container** in Factorio's Mods menu after installation.

## Features

- Horizontal or vertical containers, **2–83 tiles** long.
- Storage capacity scales with the merged chests, subject to the inventory limit in mod settings.
- Quality support and item-preserving merge/split operations.
- Direct wagon transfer with **five item-and-quality filters**, using whitelist or blacklist mode.
- Optional circuit-controlled transfer quantities and filters.
- Cybersyn2 station-equipment detection support; editor/cheat-mode infinity containers are also available.

## Quick start

1. Place **2–83 steel chests of the same quality** in one straight, gap-free row or column.
2. Choose **Merge Train Containers** from the shortcut bar and select the row. You can also assign a key to the merge tool in Controls.
3. To split it again, select **one Train Container** with the same tool. No extra chests are needed.

```text
[C][C][C][C][C][C]  ↔  [    Train Container    ]
```

Rectangles, mixed qualities, and mixed selections of chests and Train Containers cannot be merged. If items cannot fit safely, the merge or split is cancelled.

## Direct train loading

Place the container alongside cargo wagons and open it to choose **Load to wagon**, **Unload from wagon**, or **Off** (the default). The train must be **stopped at a station**, with wagons beside the container's long side; wagons at its ends do not qualify.

Without circuit quantity control, each container transfers up to **3,000 items/second at 60 UPS**, regardless of length or quality. Transfers respect destination capacity, inventory bars, and wagon filters. Compatible modded cargo wagons are supported; fluid wagons are not.

Set up to five filters to allow or exclude specific items **and qualities**. With no filters, all items and qualities are allowed.

On containers with status lamps, blinking green means items recently moved; blinking yellow means a wagon is adjacent but no items are moving. Steady yellow means transfer is off; steady green means enabled and waiting for a wagon.

### Circuit quantity control

Connect a green request wire to the container's **separate end input**, not the container body. Positive item-and-quality signals specify transfer limits **per 10-tick cycle**, bypassing the normal speed limit. A connected input with no positive requests stops transfer. Enable **Set filters** to use these signals instead of the manual filters.

Use a separate request network for each container and keep inventory signals off it. Supply the **remaining quantity**: a constant signal of 2,000 permits another 2,000 items every cycle, not a one-time delivery. External circuits must account for signal delay.

See the [circuit guide (Japanese)](docs/circuit-transfer.md) for wiring, input positioning, and upgrade details.

## Blueprints and wiring

- Normal Train Containers are saved in blueprints and copies as **steel-chest rows**, supporting rotation and mirroring. Merge them again after construction.
- Transfer modes, filters, and request-input wiring are **not copied**. Configure them again on new containers.
- During merging, an external red or green connection is retained only when **every source chest has a connection of that color**. Splitting reconnects the container's external wires to all restored chests.

## License and credits

Released under the [MIT License](LICENSE). Includes code and graphics derived from **WideChests by Atria1234** (MIT); see [third-party attribution](THIRD_PARTY_LICENSES.md).
