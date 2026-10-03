# Apple Legends — A1 Garden Circuit

Blender review build, October 2, 2026. The working Blender file is `GardenCircuit.blend`; the active scene is **A1 • Garden Circuit • 3v3 KOTH**. It opens at robot eye level. The original calibration workshop remains in a separate scene, and both reference boards are packed into the file.

## Scale and layout

The playable courtyard is 18 × 24 meters. Reference robots are approximately 55 cm tall (measured mesh extent approximately 53.8 cm). Human bench seats are 45 cm high, doors are 2.2 m high, and surrounding campus towers reach 10 m. Large paving modules, human door handles, overhead architecture, planters, trees, and small service ports establish the miniature feeling.

The center is a 3.6 m diameter capture zone with low split cover and two power pylons. Six spawn docks sit behind fire screens, with two exits per team. Ground approach lanes connect to two 85 cm raised galleries, each with two 10.7° ramps. Interrupted gallery screens limit views of the hill. Two side utility capsule sockets are visual placeholders.

## Reviewing in Blender

The **Review cameras** collection contains six views. The active view is 02. Select another camera and use **View → Cameras → Set Active Object as Camera**; **View → Cameras → Active Camera** toggles the camera view. Numpad 0 is the usual shortcut for the latter.

| Camera | Purpose | Render |
| --- | --- | --- |
| 01 • Arena overview | Whole campus and playable courtyard | `previews/01-review.png` |
| 02 • Robot eye / hill approach | Low camera, objective readability, surrounding scale | `previews/02-review.png` |
| 03 • Tiny bot beside human bench | Explicit character/furniture scale comparison | `previews/03-review.png` |
| 04 • Gallery flank | Elevated route and interrupted objective sightlines | `previews/04-review.png` |
| 05 • Team dock eye level | Spawn screen and exit approach | `previews/05-review.png` |
| 06 • Tactical overhead | Layout, route connections, cover placement | `previews/06-review.png` |

Hide **GC • Roof canopies • hide for tactical review** to reveal the galleries from above. The overhead PNG uses this cutaway; the saved Blender scene keeps the roofs visible. **Robot scale reference** can be hidden independently. **Gameplay markers** contains the named spawns, exits, pickup locations, and capture volume. An internal text block, **START HERE • Garden Circuit review**, preserves notes inside Blender.

## Review and corrections performed

Checked overhead layout, robot-eye approach, human bench scale, gallery flank, and dock views. Corrected reference robots intersecting hill cover, widened service passages, moved pickup pedestals clear of the walking lane, revised sky/light color, widened spawn shielding, added partial gallery screens, corrected outward normals on ramps in both directions, and moved the dock camera clear of a robot helmet.

Architecture-only ray checks exclude reference bots: all six spawn positions are shielded in 66 sampled sightlines to five objective locations and six gallery positions. Four service-lane centerline rays are clear at robot eye height. These checks establish the sampled geometry only; they do not prove complete collision clearance, bot navigation, fairness, or actual 3v3 pacing.

## Prototype handoff

`art/maps/garden_circuit/GardenCircuit.glb` is a consolidated visual export: ten meshes with 61 material primitives, plus named gameplay marker nodes and extras. Reference bots, review cameras, lights, and collision proxies are excluded. Its structure was checked for six spawns, one capture volume, two pickups, and valid binary glTF. The source Blender scene remains individually editable; the **EXPORT • Garden Circuit visual map** scene holds the consolidated version.

The file uses meters. A proposed conversion is approximately 3.226 accepted Godot simulation units per Blender meter, preserving the existing character dimensions and controller. This conversion has not been applied to the game. At that convention, the current full jump corresponds to about 1.84 m: roof/shortcut access must be checked during integration.

This is an arena model for review, not a working KOTH match. Godot integration still needs complete simple collision, navigation, capture/team/respawn rules, and playtesting. The hidden collision collection contains only an initial structural kit. Existing game files and settings were left unchanged; no commit or push was made. No frame-rate claim is made.

Source organization and separate robot/enemy/rifle/prop files are documented in `tools/blender_source/README.md`. The map Outliner groups Map, Characters, Gameplay, and Review.

## Runtime stability follow-up — October 2, 2026

Garden Circuit is now integrated in the running Godot game. The authored foundation/slab top planes are separated to remove coplanar surfaces. `provenance/export_runtime_map.py` rebuilds ten visual batches and a hidden collision-only batch for 100 solid planting components; it also emits source obstacle samples for runtime verification. Plant foliage remains decorative. Source markers still supply player/bot spawns. Godot uses a flat floor collider at the paving-top level, disables automatic LOD and vertex compression on this export, and enables two-sided solid collision. Team/KOTH and navigation rules remain deferred.
