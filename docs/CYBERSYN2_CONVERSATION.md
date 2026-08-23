# Cybersyn 2 Compatibility Discussion

Status: Ongoing discussion. Nothing in this document is a finalized specification.

This file preserves the original discussion with the Cybersyn 2 developer.
Do not treat proposals in this document as implementation requirements.
For implemented TrainContainer behavior, refer to SPEC.md.

## Conversation

1. TrainContainer author:

```txt
Hi, I have a compatibility question/request for Cybersyn 2.

I’m working with a Factorio 2.0 mod called TrainContainer. It acts like a bulk train loader: long merged chest entities sit directly beside cargo wagons and transfer items directly between the container and wagons, without visible inserters/loaders.

Cybersyn 2 currently seems to infer station cargo capability from inserters/loaders/pumps near the station rails. Because TrainContainer is a container-like bulk loader, CS2 does not detect it unless I create hidden dummy inserters as shims.

Would you consider adding an API or mod-data extension so other mods can register custom cargo-loading entities, or directly register cargo-capable tile indices for a stop layout?

That would make bulk-loader-style mods compatible without fake inserter entities.
```

2. Cybersyn2 author:

```txt
I am willing to add an extension point for this, The question is in the details of how it should work
merely registering the equipment for scan is one thing; how do I know what cars your equipment can load?
```

3. TrainContainer author:

```txt
Yes, that is exactly the difficult part.

My original request was mainly that Cybersyn2 could recognize chest/container-like station equipment, not only inserters and loaders.

But I understand that recognition alone is not enough. Cybersyn2 also needs to know which cargo wagons that equipment can service.

For Train Container, I can compute that mapping on my side. The mod already determines which cargo wagons are adjacent and serviceable. So Cybersyn2 would not need to implement Train Container's geometry rules itself.

The extension point I would need could be something like:

- register this entity as station cargo-handling equipment
- tell Cybersyn2 whether it supports loading, unloading, or both
- provide the cargo wagon unit_numbers that this equipment can currently service

Train Container would update that mapping when trains arrive/leave or when its mode changes.

I do not need Cybersyn2 to perform item transfer. Train Container handles the actual transfer itself. I only need Cybersyn2 to count this entity as station equipment and associate it with the wagons it can service.

I am open to whatever API shape fits Cybersyn2 best. The main point is that Train Container can provide the equipment-to-wagon mapping, so Cybersyn2 does not have to infer it from inserter positions.
```

```txt
I think I now understand the other half of the problem.
TrainContainer should probably not simply fill every serviceable wagon to capacity, because Cybersyn has a specific delivery amount for the train/wagon.

Ideally, if TrainContainer registers that it can service a wagon, I would also need some way to obtain that wagon's current loading/unloading order from Cybersyn 2 — item/fluid, quality if applicable, and requested amount.

Then TrainContainer could wait for the train to stop, and perform its own bulk transfer up to exactly the amount Cybersyn requested, rather than blindly filling or emptying the wagon.

So perhaps the extension point needs two parts:

TrainContainer tells CS2 which wagons each container can service.
TrainContainer can query the current cargo order for those wagons, or CS2 provides that order when the equipment is registered/updated.

Would something along those lines fit how CS2 internally represents station equipment and wagon orders?
```

4. Cybersyn2 author:

```txt
Each plugin api needs to focus on one thing at a time; this scope is too wide. We will not be dealing with cargo or trains at this time; the first plugin API for this use case will be focused station geometry and allowlist generation. The question at hand is equipment detection and allowlist generation, these are the rough stages of that process:

1) When should Cybersyn rescan a stop for its equipment? (this would either be you registering a prototype for cybersyn's on_build or you doing your own on build and calling a cybersyn API to determine and rescan the stop)

2) During scanning, how should it identify your plugin equipment? (Currently cybersyn is using a find_entities_filtered for this,. so probably registering a prototype name will be necessary here)

3) When your plugin equipment is found, how should it impact stop layout? This is the difficult question. There is no cargo wagon unit number to be provided. The station will not even have a train parked at it. It is a question of geometry; how many tiles back is your loader from the station, which car number does that correspond to, et cetera.
```

5. TrainContainer author:

```txt
That makes sense. Keeping the first API focused only on station geometry and allowlist generation sounds good.

For TrainContainer, I think the three stages could work like this:

1) When should Cybersyn rescan the stop?

Registering the TrainContainer prototype names for Cybersyn's build/remove handling should work for normal placement and removal.

TrainContainer currently has many generated prototypes because its length can vary, but I can provide/register all relevant prototype names.

TrainContainer also has a runtime loading mode (off, load, unload). If changing that mode needs to affect the station allowlist, I would need some way to explicitly tell Cybersyn to rescan the relevant nearby stop(s), since the entity itself is not rebuilt when the mode changes.

2) How should Cybersyn identify TrainContainer equipment?

Registering prototype names should be fine. Cybersyn can continue using its existing find_entities_filtered approach and include the registered TrainContainer prototypes in the scan.

3) How should TrainContainer affect the stop layout?
I think this is the important part, and I realized that TrainContainer probably should not try to provide car numbers itself.

A station may receive different train compositions, for example:

LCCC...

LLCC...

LLLLCC...

So the same physical TrainContainer cannot reliably say "I service cargo cars 2–4" without also knowing the train composition.

What TrainContainer can provide reliably is its physical serviceable span.

A TrainContainer is always either 1×N or N×1, and it is always placed directly beside the rail, in the strip where inserters would normally be placed. Therefore, from its entity position, orientation, and length, its exact longitudinal service span can be determined.

TrainContainer itself currently does not determine which train stop it belongs to, or how far it is from that stop. I think it would be better not to duplicate that logic: Cybersyn already owns the station scan and station-relative geometry.

So perhaps the responsibility could be:

Cybersyn determines which registered equipment belongs to the stop being scanned.
TrainContainer provides the physical span/area that the equipment can service.
Cybersyn converts that physical span into its own station-relative car positions and generates the allowlist.

For the plugin API, TrainContainer could provide either:

entity center position + orientation + length, or
directly the start/end coordinates (or bounding area) of its serviceable span.

I think the second option may be more generic for other loader mods as well, since their serviceable area may not necessarily match their entity bounding box.

Would that fit reasonably well with how Cybersyn currently builds the station layout and allowlist?
```

## Tracking

This discussion was moved to the Cybersyn 2 GitHub issue tracker:

[Third-party loading equipment registration](https://github.com/project-cybersyn/cybersyn2/issues/204)

Future discussion should be tracked there.
