# Apple Legends — Blender asset index

All editable Blender sources are in `tools/blender_source/`. Open the file for the asset you want to change; the map does not need to be opened to edit a robot or rifle.

| Asset | Editable Blender file |
| --- | --- |
| Garden Circuit map | `maps/garden_circuit/GardenCircuit.blend` |
| Player robot — cyan | `characters/player/MiniBot_Player.blend` |
| Enemy robot — amber | `characters/enemy/MiniBot_Enemy.blend` |
| Rifle and first-person robot hands | `weapons/PulseRifle.blend` |
| Campus props — bench, planter, charger, cargo, wall | `props/Campus_Props.blend` |
| Original calibration workshop / shared source | `calibration_assets.blend` |
| Concept boards | `references/` |
| Seven map review renders | `maps/garden_circuit/previews/` |
| Map review notes | `maps/garden_circuit/Review_Notes.md` |

Paths above are relative to `tools/blender_source/`. The consolidated visual map export is `art/maps/garden_circuit/GardenCircuit.glb`. Existing calibration GLBs stay in `art/calibration/`, keeping all current game references valid. Authoring sources are excluded from Godot import by the existing `.gdignore`.

## In the map Outliner

- **01 MAP • Garden Circuit:** ground, architecture, traversal, objective, spawn docks, props, planting, signage, skyline, and roofs.
- **02 CHARACTERS • Scale References:** separate PLAYER and ENEMY collections; each reference has separate Body and Held Weapon subcollections.
- **03 GAMEPLAY • Spawns, Point, Pickups:** named layout markers.
- **04 REVIEW • Cameras and Lighting:** review cameras, lights, and hidden structural collision proxies.

The map scene is active when the map file opens. Separate compiled EXPORT and calibration workshop scenes are retained; workshop objects are grouped by asset. Cameras and scale references are review helpers.

## Separate asset files

The robot files divide head/face, torso, arms/hands, legs/feet, backpack, and attached weapon into named collections. The rifle divides body/grip, muzzle, sights, energy/magazine, and first-person hands/arms. Props are grouped by individual asset. Player and enemy are independently editable presentation copies of the same chassis, distinguished by cyan/amber accents; they are not different gameplay classes.

The files preserve original authoring coordinates. Robot/rifle/prop files display a metric scale of 0.31 m per authoring unit; the garden map uses physical meters (scale 1.0). No runtime mesh dimensions or controller values changed. Re-exporting individual assets into the running game is a separate step; these source files do not automatically update the existing GLBs.

Historical arena scripts and geometry audit JSON are under `maps/garden_circuit/provenance/`. They record earlier construction passes and contain historical paths; they are not a one-command reproduction of every subsequent refinement. The editable Blender file is authoritative.

The expanded 32 × 44 m arena is playable in Godot, with solid collision and three levels at ground, 1.65 m and 3.30 m. Navigation, KOTH rules and team play remain deferred. See the current map review notes. The expansion remains local; do not publish without explicit approval.

The current Garden Circuit source includes the October 3 miniature-world pass: 3× benches, giant café tables/cups, 6.6 m doors, taller trees/towers and original white garden arches. Robot scale and playable tiers are unchanged. `miniature_world.py` is guarded one-time provenance; use `export_runtime_map.py` for routine exports. Current seven previews show these proportions.

Current Garden Circuit ramp starts/landings are x ±11.3/14.8 m with matching terrace notches, preserving open middle galleries. `clear_gallery_junctions.py` records this edit. Current planting collision includes basins/soil/base reveals/trunks; branches and leaves are decorative.
