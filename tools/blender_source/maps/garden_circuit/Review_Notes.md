# Garden Circuit — expanded arena, October 3, 2026

The authoritative editable map is `GardenCircuit.blend`, scene **A1 • Garden Circuit • 3v3 KOTH**. The matching runtime export is `art/maps/garden_circuit/GardenCircuit.glb`; the default game loads it. Keep 1/0.31 game units per meter and the accepted robot, movement, jump and sensitivity settings.

## Layout

The courtyard is **32 × 44 meters**, up from 18 × 24: 3.26 times the area. Reference robots remain approximately 55 cm tall, bench seat mesh tops now 1.51 m (3× larger furniture) and human service doors 6.6 m. The neutral central capture ring remains 3.6 m in diameter. A shallow concentric apron now joins the paving to the existing raised inlays, allowing walking entry from every direction.

Three traversable levels:
- Ground approaches, staging pavilions, midfield cover and underpasses.
- Galleries at **1.65 m**, with four ground ramps (8 m runs, approximately 11.5° slopes).
- Orchard terraces at **3.30 m**, with four outward ramps (3.5 m runs, approximately 25.2° slopes), interrupted sight screens and open drop edges.

Each side has two ground ramps and two upper ramps. Terrace planters hug the outer wall to leave a clear walking lane. The 1.65 m tier difference also offers jump shortcuts with the existing full-height jump; these are optional, with ramps as normal access. Six spawn markers sit behind widened 11 m fire screens; dogleg exits are at x ±6.15 m. Plants and cover interrupt long views while keeping several approaches to the hill.

TF2 KOTH is a pacing/layout reference, not a copied map or a claimed exact Viaduct dimension. Valve describes Viaduct's central point, varied elevations and multiple routes in its [official KOTH introduction](https://www.teamfortress.com/classless/day02.php). This original layout applies that principle at Apple Legends' miniature scale and unchanged controller speeds. Actual team balance requires future 3v3 playtesting.

## Authoring and review

Seven cameras show overview, hill approach, bench scale, gallery, dock, tactical overhead and upper terrace. Hide **GC • Roof canopies • hide for tactical review** for an overhead cutaway. Current renders are in `previews/01-review.png` through `07-review.png`. Review robots are excluded from the runtime export.

For routine edits, edit the saved source then run Blender in background with `provenance/export_runtime_map.py`. This recompiles ten visual batches, hidden solid planting collision, named markers, obstacle samples and the asset summary. `expand_garden_circuit.py` records the one-time expansion from the accepted pre-expansion source at b59ec60; it refuses to expand an already expanded file. Older provenance scripts and JSON describe historical compact-layout checks, not this map.

Godot uses a continuous 32 × 44 m floor collider, two-sided triangle collision and hidden solid basins/soil/base reveals/trunks. Leaves, small branches and flat signage remain decorative. Foundation, slab and paving planes remain separated; disabled map LOD/compression and 4× MSAA are preserved.

## Verification and limits

Final native results: all traversal checks pass; the tested cyan dock-to-hill walking route takes 13.23 seconds of movement. All 482 solid face samples block shots from both sides, and the 90 sampled spawn views are shielded. Settings/jump/F1/Esc/CS persistence regressions pass.

Native tests: `tests/garden_expansion_smoke.gd` checks expanded floor coverage, all four ground-to-gallery-to-terrace capsule climbs, ground underpasses, safe tier drops, a dock-to-hill walk and 90 sampled spawn sightlines. `garden_obstacles_smoke.gd` audits every exported solid obstacle sample from both sides, actual seam traversal and planter blocking. `garden_settings_smoke.gd` checks jump, settings, F1 freeze, Esc and exact CS sensitivity persistence.

The build remains an offline duel with a simple bot that may get stuck on cover. Capture and pickup markers are visual placeholders; team/KOTH logic, advanced bot navigation and multiplayer remain deferred. No whole-map balance, physical mouse calibration or frame-rate benchmark is claimed.

## October 3 — miniature world scale

User requests a much smaller-feeling character in an abnormally large human garden campus, with Olympus as atmosphere inspiration. This explicitly supersedes the earlier fixed furniture scale. Robot height remains approximately 0.55 m, with unchanged camera, movement and sensitivity. Original benches are now 3× larger (4.46 m wide, seat mesh top 1.51 m, underside 1.19 m); two extra giant benches appear beside spawn. Added 2.25 m café tables and robot-sized cups, 6.6 m doors, taller planters/trees, 1.8× taller perimeter/pavilions, 2.1× skyline towers and original white garden arches reaching 19.5 m. All geometry is original; no commercial map or asset is copied.

The 32 × 44 m courtyard, ground floor, 1.65/3.30 m tiers, ramp geometry, hill apron and six spawn markers remain. Human scenery provides the scale cues without changing the accepted controller. Updated editable Blender source, solid runtime export, source previews and player-eye native screenshot. The expanded source is also copied to this task's outputs.

Verification: native expanded-map ramps, underpasses, tier drops, four walking hill entries and 90 sampled spawn sightlines pass; representative walking time remains 13.23 seconds. All 482 sampled authored obstacle faces block rays from both sides, with level paving and actual planter blocking. All six spawn pads pass without jumping. The new miniature-world fixture confirms oversized seat dimensions and actual grounded capsule passage beneath the solid bench. Native eye-level imagery was reviewed. User feel acceptance, team balance and frame-rate benchmarking remain unverified. Keep local publication restrictions and deferred multiplayer/KOTH systems.

## October 3 — wall-visible weapon and clear ramp junctions

The user likes the miniature-world scale (local commit 12f2d45), then reports the gun disappearing at wall contact and blocked movement/jumping near an upper ramp. They explicitly request checking all blockers. Keep the accepted miniature art and current locomotion.

The first-person rifle now uses copied local materials with Godot's `use_z_clip_scale` and scale 0.1, keeping its screen size, lighting and internal depth while bringing rendered geometry inside the capsule clearance. Near plane is 0.01. Both original and imported rifle/hand meshes and muzzle flashes are configured; enemy/shared world materials retain ordinary depth. Camera-origin hitscan, wall occlusion, ADS/FOV, recoil, reload and gameplay collision remain. Native hip/ADS pixel comparisons at actual wall contact confirm the rifle stays visible; rifle combat/regression checks pass.

The four upper ramps previously started at x ±9.5 m and cut across the middle galleries. Their starts now sit at x ±11.3 m with landings at ±14.8 m: same 3.5 m run, slope and tier heights. Matching upper-deck notches and outer links avoid solid deck overlap; all middle-gallery walking lanes stay open. Small tree branches now share foliage's decorative collision policy to prevent hidden snags; basins, soil, base reveals and trunks remain solid. Source, runtime export and previews match.

Headless physics checks pass for six full-length gallery lanes, 40 full-height middle-gallery jumps, four upper-ramp jumps, connected high-tier walking routes and 20 full-height upper-terrace jumps, plus jumping over all six center-facing gallery guards. Fast mode uses 600 ticks/s and time scale 10 solely in this static-map fixture, retaining a 1/60 simulated delta; production remains unchanged. Native checks pass for all eight ramp connections, underpasses, safe tier drops, four hill entries and 90 sampled protected spawn sightlines; representative dock-to-hill movement stays 13.23 seconds. All six spawn pads still support walking without a jump. These checks cover authored routes and sampled surfaces, not every possible player trajectory or a performance benchmark. Keep local publication restrictions.

October 3 lower gallery edge refinement: center-facing gallery decks now have visible porcelain structural skirts beneath their solid lips, with symmetric 2.4 m ground portals centered at longitudinal +/-1.5 m. A ground capsule previously walked beneath the thin lip and hit the underside after only 0.776 m of jump rise. The skirts keep ordinary wall approaches outside the deck until a held jump can mount its 1.65 m surface. Existing gallery guards remain taller than a jump from ground; use the open spans beside them. Ground underpasses and upper tiers remain solid and traversable. No locomotion or collision-layer change.

Targeted capsule fixture: `tests/garden_lower_edges_smoke.gd` checks ten wall approaches, eight actual gallery mounts, two guarded-edge retreats, and four mirrored underpass crossings. Native Metal and headless physics pass this fixture. Existing seven previews remain from the preceding geometry pass; the dedicated lower-edge preview documents this refinement.

Integrated KOTH regression isolation freezes objective clocks and respawn timers while exercising authored geometry. Final native accelerated map fixture passes all eight ramps, both underpasses, independent high-tier-to-ground and gallery-to-ground drops, four hill entries and 90 spawn sightlines; simulated dock-to-hill walking remains 13.23 seconds. A high-tier walking drop can either touch the gallery or cross the open gap directly to ground depending on lateral contact, so the fixture checks both tier drops independently. The 392 authored solid obstacle samples also pass two-sided collision checks. Some legacy fixtures report exit-only resource cleanup warnings; gameplay assertions pass.
