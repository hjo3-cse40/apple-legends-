# Garden Circuit — expanded arena, October 3, 2026

The authoritative editable map is `GardenCircuit.blend`, scene **A1 • Garden Circuit • 3v3 KOTH**. The matching runtime export is `art/maps/garden_circuit/GardenCircuit.glb`; the default game loads it. Keep 1/0.31 game units per meter and the accepted robot, furniture, movement, jump and sensitivity settings.

## Layout

The courtyard is **32 × 44 meters**, up from 18 × 24: 3.26 times the area. Reference robots remain approximately 55 cm tall, bench seats 45 cm and human service doors 2.2 m. The neutral central capture ring remains 3.6 m in diameter. A shallow concentric apron now joins the paving to the existing raised inlays, allowing walking entry from every direction.

Three traversable levels:
- Ground approaches, staging pavilions, midfield cover and underpasses.
- Galleries at **1.65 m**, with four ground ramps (8 m runs, approximately 11.5° slopes).
- Orchard terraces at **3.30 m**, with four outward ramps (3.5 m runs, approximately 25.2° slopes), interrupted sight screens and open drop edges.

Each side has two ground ramps and two upper ramps. Terrace planters hug the outer wall to leave a clear walking lane. The 1.65 m tier difference also offers jump shortcuts with the existing full-height jump; these are optional, with ramps as normal access. Six spawn markers sit behind widened 11 m fire screens; dogleg exits are at x ±6.15 m. Plants and cover interrupt long views while keeping several approaches to the hill.

TF2 KOTH is a pacing/layout reference, not a copied map or a claimed exact Viaduct dimension. Valve describes Viaduct's central point, varied elevations and multiple routes in its [official KOTH introduction](https://www.teamfortress.com/classless/day02.php). This original layout applies that principle at Apple Legends' miniature scale and unchanged controller speeds. Actual team balance requires future 3v3 playtesting.

## Authoring and review

Seven cameras show overview, hill approach, bench scale, gallery, dock, tactical overhead and upper terrace. Hide **GC • Roof canopies • hide for tactical review** for an overhead cutaway. Current renders are in `previews/01-review.png` through `07-review.png`. Review robots are excluded from the runtime export.

For routine edits, edit the saved source then run Blender in background with `provenance/export_runtime_map.py`. This recompiles ten visual batches, hidden solid planting collision, named markers, obstacle samples and the asset summary. `expand_garden_circuit.py` records the one-time expansion from the accepted pre-expansion source at b59ec60; it refuses to expand an already expanded file. Older provenance scripts and JSON describe historical compact-layout checks, not this map.

Godot uses a continuous 32 × 44 m floor collider, two-sided triangle collision and hidden solid basins/soil/trunks/branches. Leaves and flat signage remain decorative. Foundation, slab and paving planes remain separated; disabled map LOD/compression and 4× MSAA are preserved.

## Verification and limits

Final native results: all traversal checks pass; the tested cyan dock-to-hill walking route takes 13.23 seconds of movement. All 454 solid face samples block shots from both sides, and the 90 sampled spawn views are shielded. Settings/jump/F1/Esc/CS persistence regressions pass.

Native tests: `tests/garden_expansion_smoke.gd` checks expanded floor coverage, all four ground-to-gallery-to-terrace capsule climbs, ground underpasses, safe tier drops, a dock-to-hill walk and 90 sampled spawn sightlines. `garden_obstacles_smoke.gd` audits every exported solid obstacle sample from both sides, actual seam traversal and planter blocking. `garden_settings_smoke.gd` checks jump, settings, F1 freeze, Esc and exact CS sensitivity persistence.

The build remains an offline duel with a simple bot that may get stuck on cover. Capture and pickup markers are visual placeholders; team/KOTH logic, advanced bot navigation and multiplayer remain deferred. No whole-map balance, physical mouse calibration or frame-rate benchmark is claimed.
