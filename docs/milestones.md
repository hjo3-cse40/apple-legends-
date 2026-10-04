# Milestones

M0 foundation → M1 movement → M2 gunplay → M3 offline duel/polish → M4 multiplayer → M5 small arena → M6 BR systems → M7 mini BR → M8 original content/polish.

## M0 acceptance

- [x] Minimal Godot project with a designated launch scene, fixed camera, visible fixture, and status overlay.
- [x] README, persistent agent rules, architectural rationale, and milestone criteria exist.
- [x] No third-party dependencies, gameplay framework, or later gameplay systems added.
- [x] Local Git repository initialized and M1 checkpoint committed/pushed as `fffb961`.
- [x] Godot 4.7.2 installed and exact version confirmed on development machine.
- [x] Editor import and headless startup complete without errors.
- [x] F5 visually shows the canyon range and HUD; no startup errors were observed.
- [x] Native Apple Silicon execution and Metal renderer confirmed on the M3 Pro.

M0 startup scaffold has been superseded by the running M1 range.

## M1 acceptance

- [x] A reusable player spawns above a collidable floor with boundary walls and a low ceiling/obstacle test area; automated smoke coverage confirms floor collision.
- [x] WASD movement is camera-yaw-relative and normalized. Ground acceleration/braking, speed, sprint speed, gravity, jump speed, air control, sensitivity, and FOV are configurable.
- [x] Mouse is captured during play and pitch is clamped. Escape releases the cursor; click recaptures it. Focus loss releases capture and explicit action releases clear stale movement state.
- [x] Jump requires grounded state, sprint respects configured speed, and air steering is bounded by acceleration toward the configured target speed.
- Corners, wall glancing, low ceilings, and landing do not create persistent sticking, penetration, or camera jitter. Stairs, slopes, crouch, and advanced traversal are explicitly outside the first slice unless scoped later.
- [x] Crosshair and debug HUD show FPS, velocity/horizontal speed, and grounded state; UI observes gameplay state without owning it.
- At render caps of 30, 60, and 120 FPS (where hardware permits), same-input straight-line travel over 5 seconds and jump apex agree within 5%, with physics cadence unchanged. Equivalent mouse displacement produces equivalent rotation. Record measurements and methodology; FPS is not a performance gate.
- Manual movement/aiming session on M3 feels responsive and predictable; record remaining feel issues. A 10-minute room session and focus/recapture/restart checks produce no runtime errors.
- Scope remains movement only: no weapons, networking, or BR logic.

## Implementation sequence

1. **Finish M0 verification:** install standard Godot, import, run the checks above, record version/results. Do not change engines without concrete evidence.
2. **M1a — highest-risk slice:** replace the preview fixture with collision floor/walls and a capsule CharacterBody3D player. Add explicit Input Map actions for WASD and mouse capture/look. Test camera response, focus handling, wall collisions, and frame cadence before expanding the controller.
3. **M1b — movement:** tune acceleration/braking, then jump, sprint, and bounded air control. Add one behavior at a time and verify it; expose tuning properties.
4. **M1c — feedback and acceptance:** add crosshair/debug HUD, run frame-rate and collision checks, tune on M3, document results, and checkpoint the playable room in Git. Defer crouch.

Each step should be a small logical commit after its relevant checks. The user accepted the movement baseline and explicitly authorized M2.

## Validation record

2026-09-16 M0: host reports arm64; Git 2.39.5 and Xcode developer directory available. Initial scaffold committed as `6d90d57`.

2026-09-16 M1 implementation: `/Applications/Godot.app/Contents/MacOS/Godot --version` reports `4.7.2.stable.official.ed1daf0bf`. Editor import and a 30-frame headless launch completed without parser/runtime errors. `tests/player_movement_smoke.gd` passed forward movement, diagonal normalization within 2%, jump/landing, floor/wall collision, mouse yaw/pitch, and pitch clamping. GUI startup showed the correctly lit range and grounded HUD through Metal on the M3 Pro. Focus handling, subjective mouse feel, wall/ceiling behavior, frame-cap measurements, and the 10-minute session remain manual checks.


## M2 — one semi-auto practice rifle

Authorized after the user tested M1 and reported movement feels good. Keep the accepted movement tuning unchanged.

Acceptance:
- Visible original rifle; left click fires once per press, holding does not repeat.
- Configurable shot cooldown, damage, range, magazine size, reload duration, ADS FOV, and visual recoil.
- Hitscan resolves the first obstruction, excludes the player, and damages only valid active targets.
- Empty magazine blocks shots; R reloads after a delay, with infinite reserve for range practice.
- Right mouse holds ADS; recoil/flash and hit marker make successful shots visible.
- Three stationary targets show health and reset after elimination.
- Escape/focus loss clears fire and ADS intent; the recapture click never fires.
- Existing movement smoke still passes; rifle and target smoke tests cover their behavior.
- User checks firing feel, ADS, sound, reload, and window focus changes in the actual game.

Implemented and automated checks passed. GUI preview confirmed rifle, targets, and HUD render with Metal. Hands-on firing feel, ADS alignment, sound, and focus switching remain user acceptance checks. No networking, inventory, extra weapons, or battle royale systems.

## Deferred user tuning feedback

- Shift should eventually toggle sprint rather than require holding.
- Consider slightly faster sprint movement.
- Current mouse sensitivity is a little fast; tune later with the user.

These are planning notes only. M2 must not silently change the accepted base movement or mouse sensitivity.


### M2 validation record

2026-09-16: Godot 4.7.2 movement regression passed with rifle attached. Rifle smoke passed actual target hit, miss, wall occlusion, shot cooldown, no repeated fire from a single request, empty-magazine rejection, reload lockout/completion, cursor-recapture suppression, input cancellation, signal delivery, and preservation of the 80-degree hip FOV after several frames. Target smoke passed damage rejection, health reduction, elimination lockout, and an actual shortened reset timer. Native Metal GUI preview displayed the rifle, three apple targets, health labels, crosshair, and ammunition. A second Sol agent reviewed firing/input routing without finding additional issues.

The user accepted M1 movement before this work. Base walk/sprint speeds and sensitivity remain unchanged. Recoil is viewmodel-only in M2; competitive camera recoil, accuracy spread, and detailed handling are future tuning work.

## M3 — offline duel vertical slice

Authorized by the user after the movement, shooting, and reload prototype was playable.

Acceptance:
- [x] Reusable health validates damage, clamps lethal hits, emits state signals, and resets cleanly.
- [x] Player death disables movement/collision and a timed respawn restores health, position, and ammunition.
- [x] One primitive-geometry bot acquires the player, respects line of sight/range, shoots, takes damage, dies, and respawns.
- [x] Bot movement can approach, retreat, and strafe around a preferred engagement distance.
- [x] Player and bot eliminations update a first-to-five score; victory/defeat stops respawns and the match can restart.
- [x] HUD reports health, score, match outcome, hit confirmation, incoming damage, ammo, and reload state.
- [x] Bot hits include their world source and display a compact camera-relative direction mark without changing movement or intercepting input.
- [x] Rifle feedback includes a procedural reload motion, transient FOV kick, stronger muzzle flash, and short-lived impact sparks.
- [x] Health, bot, duel, rifle, target, and movement headless smoke suites pass.
- [ ] Manual Metal playtest confirms bot difficulty, spawn safety, visual readability, reload feel, and match pacing.

### M3 validation record

2026-09-20: Godot 4.7.2 headless import/startup completed without project parser or runtime errors. Six smoke suites passed: reusable health, targets, rifle and feedback, bot health/LOS fire/movement, integrated player death/respawn/scoring/restart, and the accepted movement regression. Sandbox-only `user://` log and macOS CA lookup warnings were present during automated runs. A hands-on Metal playtest remains required before tuning values are accepted.

2026-09-20 playtest follow-up: the initial bot felt like unavoidable random damage because it snapped to a perfectly accurate shot every 0.7 seconds, while death silently disabled movement for 1.5 seconds. Default bot damage is now 10, fire cadence 1.1 seconds, reaction delay 0.75 seconds, aim time 0.45 seconds, and hit chance 55%. A bot muzzle flash communicates shots, the damage overlay is shorter/subtler, respawn is 0.8 seconds, and the HUD explicitly labels the eliminated/respawning state. Bot, duel, rifle, and movement regressions pass after the change.

2026-09-20 directional feedback: accepted player damage can carry an optional world-space source position. The HUD maps the flattened source vector into camera-relative screen space and shows a small fading chevron around the crosshair. Automated coverage checks east/right, west/left, front, rear, rotated-camera mapping, radius, fade duration, bot source propagation, and input safety. All seven smoke suites pass.


## Authorized art calibration slice — 2026-10-02

The user selected the first mini-robot board and authorized the next-step calibration bay with Blender-authored assets. This is a limited presentation slice before further arena/networking work.

- [x] Seven original Blender assets: robot chassis, rifle/robot hands, wall shell, cargo pod, charger, bench, and planted container. Source and GLBs saved.
- [x] Separate inherited calibration scene; default main launches it. Original canyon remains independently runnable with F6.
- [x] Bright sky/daylight, white/graphite materials, cyan technology, orange opponent accents, readable dark HUD backings.
- [x] Imported robot can take damage; visible helmet/chest feedback replaces the hidden baseline body flash. Existing rifle, health, duel, and movement systems retained.
- [x] F1 pauses/resumes opponent; F2 compares FOV and restores baseline ADS; F3 toggles stats.
- [x] Existing seven headless suites pass after integration. New calibration smoke passes asset integration, collision floor, actual bot hitscan damage, inspection toggle, FOV/ADS restoration, and debug toggle.
- [x] Native Metal/Mobile GUI preview on Apple M3 Pro inspected for hip and ADS framing at a 1920x1080 window. Initial exporter selection/orientation issues corrected; open sight and smooth bevel shading verified.
- [ ] User playtest: perceived scale, close-up weapon framing, aiming feel, white-wall enemy visibility, collisions, reload feel, match restart.
- [ ] Representative frame-time profiling. No new 120 FPS claim.

Headless runs emit a sandbox macOS certificate lookup warning but no project parser/runtime errors. Simulation-scale conversion, skeletal rigging, more weapons/classes, complex bot navigation, full Garden Circuit, and multiplayer remain deferred.


### Authorized audio follow-up — 2026-10-02

Added original mechanical footsteps for both characters, spatial bot gunfire on every shot (including misses), and a local shield hit cue. Own footsteps are quieter; bot direction/distance are handled by positional mono playback. Footsteps follow grounded displacement; death/respawn/F1 reset audio. No controller or combat tuning changed.

Validation: new character audio smoke passes real bot fire/misses, walking, spatial setup, pause/death/respawn, local footsteps/idle/airborne, and incoming damage. Bot, duel, movement, rifle, and calibration smoke regressions all pass. A native Metal/CoreAudio mixer probe confirmed nonzero gun output and distance falloff: RMS approximately 0.0476 at 5 m versus 0.0060 at 30 m. The sandbox headless certificate warning remains unrelated. Human listening/volume balance is pending the user's playtest; sound obstruction through walls is not implemented.


### Miniature-scale and laptop-input follow-up — 2026-10-02

Benches and robots retain their accepted dimensions. Calibration wall height is 1.8×, planters/cargo/chargers are 1.7×, and skyline towers grow from 10 to 20 units high. Floor divisions are spaced twice as far apart. Matching collision boxes grow with wall/prop meshes; arena footprint, spawns, controller, weapon framing, and movement speeds stay the same.

Captured mouse combat is handled before decorative HUD controls can swallow a click. V is an alternate semi-auto fire binding; keyboard echo cannot repeat a shot. Visible-cursor recapture still requires a click without firing. The game can only act on input delivered by macOS: physical trackpad clicks while typing still require a user playtest; an external mouse or V provides an alternate input if the trackpad does not deliver a click.

Deferred user preferences: sprint toggle (reconfirmed; do not implement yet), crouch, more fluid movement, and an arms-back miniature robot running animation. The user selected the bench size as the environmental reference and explicitly kept robot size fixed.

Validation: native Metal input smoke passes real Godot event routing for W + Shift + click, continued sprint/movement, firing through a blocking HUD, V fallback, keyboard echo rejection, and cursor recapture safety. Movement, rifle, calibration, audio, and duel headless smoke checks pass. The normalization test's start shifts into the clear center lane because enlarged side planters intercept its previous diagonal route; the controller itself is unchanged. Calibration checks unchanged bench/chassis scales and high wall collision. Native 1920×1080 scenery preview inspected; physical trackpad behavior remains a user playtest item.


### Authorized hybrid sprint / vertical movement — 2026-10-02

Implemented the previously deferred sprint toggle with hold support: short taps toggle, long holds sprint momentarily and preserve the prior latch. Calibration shows WALK/SPRINT. Player jump now has lower gravity (24→14), faster launch (8.5→11), finite held lift (0.35 seconds at 0.55 gravity), and early-release control (a tap cuts upward speed ×0.5, easing toward no cut at the end of the hold window). Air acceleration increases 5→8 for landing control. Ground walk/sprint speed remains 7/10, character and scenery sizes unchanged. Full jump peak is about 5.93 units; a tap is about 1.22 and a ten-frame hold about 3.68.

This supersedes the earlier sprint-toggle deferral. Crouch and the arms-back running animation remain later work. A jump is not a mantle, double jump, flight mode, or automatic repeat on landing.

Validation: new vertical movement smoke passes tap/hold sprint state and actual speed, three jump-height measurements and near-full smoothness, standing on real bench/cargo/planter/charger colliders, no renewed airborne lift, finite lift/no repeated held jump, ceiling impact, and death/respawn/capture reset. Native Metal event coverage passes two Shift taps and long-hold release, plus moving/sprinting gunfire and recapture safety. Movement, rifle, duel, audio, and calibration regressions pass; initial-floor settling fixtures allow longer for lower gravity. Headless runs retain the unrelated sandbox certificate warning. Human tuning of floatiness, airtime, and air braking remains a playtest item.


2026-10-02 user playtest acceptance: after testing the sprint/jump update, the user reported “looks good to me so far” and asked to save it to memory. The current build is the accepted baseline for future work; preserve its scale and movement feel unless further tuning is requested. Individual hardware/performance checks are not implied by this general acceptance. Persistent baseline and tuning values are recorded in AGENTS.md.


### Blender Garden Circuit review and organized sources — 2026-10-02

User-authorized original 3v3 KOTH visual arena is now stored in the repo, with approximately 55 cm robot references and human-sized surroundings. Six spawn markers, central objective, ground routes, two galleries/four ramps, pickup placeholders, and six review cameras are present. Geometry/render passes include 66 sampled architecture-only spawn shielding rays and clear service lane centerlines; these are not an in-game balance test. Asset organization separates player/enemy robots, rifle/hands, props, and map files. Source index: `tools/blender_source/README.md`. A consolidated visual map GLB is in `art/maps/garden_circuit/`. No playable KOTH/team logic, navigation, or controller changes are included. The user later authorized committing/pushing this work; current runtime calibration paths are preserved.


2026-10-02 future direction saved: browser-link sharing is the preferred access path, private two-player rooms precede 3v3 internet play, and optional Jev tactical decisions are an exploratory bot idea. Detailed preferences, constraints, and conditional cost estimates are in `docs/product-direction.md`; none of those systems is implemented by the memory update.

Publication validation: Godot imports the new map successfully. Player movement, rifle, duel lifecycle, vertical movement, calibration art, and native moving-fire checks pass. The duel smoke now checks synchronous death/HUD signals before a short respawn timer can expire, waits on respawn completion instead of a fixed sleep, and frees its scene before exit; gameplay behavior is unchanged.
The duel/calibration headless checks still emit resource/ObjectDB teardown diagnostics on exit; their assertions pass, but this checkpoint does not claim those existing cleanup diagnostics are resolved.

### Garden Circuit movement and Esc settings — 2026-10-02

User authorized integrating the existing Blender arena, keeping a freezeable test bot, adjustable mouse sensitivity, menu variations and a new branch. Default main scene now runs Garden Circuit, preserving accepted locomotion and calibration robot/rifle. Three real menu layouts were rendered; the light cyan-accented right panel is selected. Local sensitivity persists; Esc pauses/resumes gameplay. Native map/settings test passes floor, lane movement, jumps/landing, sloped ramp contact, solid perimeter, F1 freeze, Esc input, persistence and menu freeze. Rifle and offline duel regression checks pass. Physical-input feel, full-route exploration and performance remain user playtests; the simple bot has no arena navigation.

Additional checks: native moving/sprinting mouse fire, V fallback and recapture safety pass; preserved calibration, normalized movement, rifle, damage-direction HUD and character audio regressions pass. Headless duel/HUD/audio checks report two ObjectDB instances and one resource still in use during test exit; native map/settings and input checks exit cleanly. No performance benchmark or complete arena-navigation claim is made.

### Stability, obstacle and CS-sensitivity follow-up — 2026-10-02

User reports ground shimmer and pass-through objects and authorizes matching CS sensitivity units. Fixed coincident slab/foundation planes in Blender, rebuilt export, disabled map LOD/compression, enabled MSAA, added continuous floor and solid planting collision, and enabled collision from either face. Native audit passes 371 solid obstacle samples from both sides, level floor traversal and capsule blocking at the cyan planter. Tiny cargo trim and flat ready-light/socket decals are backed by solid main objects and are excluded as independent barriers; leaves remain decorative. A stationary ground image patch stays pixel-identical across 30 rendered frames, establishing that sampled stationary view only.

Esc controls accept six-decimal CS sensitivity, show DPI/eDPI/cm360 and migrate prior saved values. Native event test at sensitivity 1.234567 and 1000/200 supplied counts verifies yaw 27.160474° and pitch 5.4320948°, Retina normalization, persistence, bot freeze, Esc lifecycle, movement/ramp/jump behavior. DPI changes do not alter the gain. Physical cm360, custom CS yaw/acceleration and scoped feel are not verified. Remain on feature/garden-movement-settings; keep publishing local unless the user explicitly approves the previously rejected GitHub push.

## October 3 — authorized map expansion

User requested a larger TF2-KOTH-style map with vertical components. Garden Circuit now uses an original 32 × 44 m courtyard, unchanged miniature robot/furniture scale and accepted movement, protected docks, ground routes, 1.65 m galleries and 3.30 m upper orchard terraces. Four ground ramps and four upper ramps, open underpasses, interrupted high-ground screens and drop edges connect the routes. Blender source and runtime export are both updated. Existing offline duel, F1 freeze and Esc CS controls remain; no KOTH/team/multiplayer or advanced navigation milestone is added.

Final native validation passes: four complete capsule climbs covering all eight ramps, open underpasses, safe tier drops, four walking objective entries and 90 sampled shielded spawn views. The tested cyan dock dogleg route takes 13.23 seconds of walking movement. All 454 exported solid obstacle face samples block rays from both sides; real seam traversal and planter capsule blocking pass. Native jump/F1/Esc/CS sensitivity and persistence regressions pass. Rendered overview, tactical, gallery, dock and upper-route views were reviewed; the saved GLB is verified in the native Metal build. No balance or performance benchmark is recorded.

## October 3 — lighter gravity, ledge recovery and air strafing

User authorizes movement tuning: gravity 14 → 13.2; one unused jump retained during a walk-off fall until landing; directional Source-style air acceleration (coefficient 8, wish projection cap 2.5). Ground tuning, sprint, finite variable-height jump, CS controls and map geometry stay intact. Real ledge-fall recovery onto the platform, repeat-launch rejection, momentum preservation, strafe speed gain and falling acceleration pass in `air_movement_smoke.gd`. Existing variable-jump/ceiling/lifecycle and calibration prop landings pass. Native Garden settings, freeze, jump and CS persistence pass; all arena ramp climbs, underpasses, tier drops, four walking objective approaches and 90 sampled spawn views pass. The representative ground walking time remains 13.23 seconds. These are engineering checks; user feel acceptance and performance remain unverified.

## October 3 — walk over small ledges

User requests automatic walking over low spawn pads and tiny height changes. Added 0.35-unit (~10.85 cm map-scale) grounded step allowance with full-capsule clearance sweeps and static walkable tread validation. Horizontal movement executes once, without upward jump velocity; airborne movement, taller obstacles and insufficient headroom cannot step. Fixtures pass for 0.05/0.26/0.34-unit climbs, blocking at 0.36 units, a low ceiling and airborne safety. All six actual spawn pads pass in headless and native physics after excluding the frozen bot body from that terrain-only fixture. Variable-height jump/prop landing and air-strafe/ledge-recovery checks pass. Native settings/jump/F1/Esc/CS persistence and expanded-map ramps, underpasses, drops, objective entries and 90 sampled spawn views pass. Representative walking time stays 13.23 seconds. No user feel acceptance or frame-rate claim is inferred.

## October 3 — miniature world scale

User requests a much smaller-feeling character in an abnormally large human garden campus, with Olympus as atmosphere inspiration. This explicitly supersedes the earlier fixed furniture scale. Robot height remains approximately 0.55 m, with unchanged camera, movement and sensitivity. Original benches are now 3× larger (4.46 m wide, seat mesh top 1.51 m, underside 1.19 m); two extra giant benches appear beside spawn. Added 2.25 m café tables and robot-sized cups, 6.6 m doors, taller planters/trees, 1.8× taller perimeter/pavilions, 2.1× skyline towers and original white garden arches reaching 19.5 m. All geometry is original; no commercial map or asset is copied.

The 32 × 44 m courtyard, ground floor, 1.65/3.30 m tiers, ramp geometry, hill apron and six spawn markers remain. Human scenery provides the scale cues without changing the accepted controller. Updated editable Blender source, solid runtime export, source previews and player-eye native screenshot. The expanded source is also copied to this task's outputs.

Verification: native expanded-map ramps, underpasses, tier drops, four walking hill entries and 90 sampled spawn sightlines pass; representative walking time remains 13.23 seconds. All 482 sampled authored obstacle faces block rays from both sides, with level paving and actual planter blocking. All six spawn pads pass without jumping. The new miniature-world fixture confirms oversized seat dimensions and actual grounded capsule passage beneath the solid bench. Native eye-level imagery was reviewed. Native jump/ramp movement, F1/Esc lifecycle, six-decimal CS input, Retina normalization and sensitivity persistence also pass. User feel acceptance, team balance and frame-rate benchmarking remain unverified. Keep local publication restrictions and deferred multiplayer/KOTH systems.

## October 3 — wall-visible weapon and clear ramp junctions

The user likes the miniature-world scale (local commit 12f2d45), then reports the gun disappearing at wall contact and blocked movement/jumping near an upper ramp. They explicitly request checking all blockers. Keep the accepted miniature art and current locomotion.

The first-person rifle now uses copied local materials with Godot's `use_z_clip_scale` and scale 0.1, keeping its screen size, lighting and internal depth while bringing rendered geometry inside the capsule clearance. Near plane is 0.01. Both original and imported rifle/hand meshes and muzzle flashes are configured; enemy/shared world materials retain ordinary depth. Camera-origin hitscan, wall occlusion, ADS/FOV, recoil, reload and gameplay collision remain. Native hip/ADS pixel comparisons at actual wall contact confirm the rifle stays visible; rifle combat/regression checks pass.

The four upper ramps previously started at x ±9.5 m and cut across the middle galleries. Their starts now sit at x ±11.3 m with landings at ±14.8 m: same 3.5 m run, slope and tier heights. Matching upper-deck notches and outer links avoid solid deck overlap; all middle-gallery walking lanes stay open. Small tree branches now share foliage's decorative collision policy to prevent hidden snags; basins, soil, base reveals and trunks remain solid. Source, runtime export and previews match.

Headless and native physics checks pass for six full-length gallery lanes, 40 full-height middle-gallery jumps, four upper-ramp jumps, connected high-tier walking routes and 20 full-height upper-terrace jumps, plus jumping over all six center-facing gallery guards. Fast mode uses 600 ticks/s and time scale 10 solely in this static-map fixture, retaining a 1/60 simulated delta; production remains unchanged. Native checks pass for all eight ramp connections, underpasses, safe tier drops, four hill entries and 90 sampled protected spawn sightlines; representative dock-to-hill movement stays 13.23 seconds. All 386 sampled solid obstacle faces block rays from both sides, and native movement/jump/F1/Esc/CS sensitivity controls pass. Walking beneath the giant bench also passes. All six spawn pads still support walking without a jump. These checks cover authored routes and sampled surfaces, not every possible player trajectory or a performance benchmark. Keep local publication restrictions.

## October 3 — playable offline KOTH authorization

The user explicitly requests contested capture, independent 3:00 ownership clocks, TF2-informed capture pacing, win/restart, objective-aware bot behavior, remaining lower-ledge fixes and repeated critical evaluation. They also request parallel GPT-6.1 Sol agents. This supersedes earlier KOTH and basic navigation deferrals for this offline slice. Multiplayer, API services and publication remain outside this change; preserve the accepted movement and miniature art.

Garden Circuit now uses KothManager (reusing DuelManager health/respawn wiring), pure KothRules and an observing KothHUD. Production tuning is 12-second single capture, 15-second initial lock, 180-second clocks and 3-second respawns. Grounded living feet in the 1.8 m ring count. Both teams freeze capture and clocks. Empty owned hills keep counting; recapture preserves the prior clock. Zero with an enemy on the hill enters overtime; clear it to win. Gameplay freezes after victory/defeat and Enter resets. Esc pauses simulation; F1 test-bot preference survives restart. Calibration/canyon retain first-to-five duel behavior.

Lower gallery edges now have six visible flush structural skirts and mirrored 2.4 m portals. Ordinary approaches no longer enter the low deck underside before jumping; unguarded spans permit held-jump mounting. Taller guard spans retain intentional collision and can be approached via adjacent open spans. The bot uses original mirrored ground waypoints, capsule stepping and local obstacle steering, holds the hill instead of chasing, and fights visible enemies. Widening the spawn lanes to x ±7.15 m resolved a bench-leg snag found at 120 Hz.

Validation after KOTH integration: rules boundaries and 60 randomized delta partitions; grounded capture/contest, airborne/dead exclusion, pause, timed respawns, winner freeze, Enter/reset, preserved F1 and 24 repeated rounds; production clock scenario with 120 seconds contested and two recaptures; three actual full-clock bot wins (623.75 seconds combined simulation) with death/respawn clock retention. Objective routes passed twice at 60/120 Hz (24 capsule routes, 15.57–17.20 seconds arrival). Lower/gallery checks, 392 sampled obstacle faces, six spawn pads, giant bench passage, wall-visible hip/ADS rifle, rifle combat, air movement and small-step regressions pass. Native Metal HUD screenshots were reviewed and overlap corrected. Final native expanded-map ramps, underpasses, separate upper/gallery safe drops, four hill entries, 90 spawn sightlines and winner-menu/restart checks pass. Simulated dock-to-hill walking time remains 13.23 seconds. Tests cover authored routes and explicit scenarios, not every player trajectory, human balance or frame-rate performance.

## October 3 — user playtest and proposed next milestone

The user reports the expanded KOTH game works and they tested it. Current baseline is accepted for continued iteration. Recommended next milestone: fun, readable offline 2v2 KOTH, beginning with current combat/pacing feedback and team-aware bot foundations. Private human play/browser feasibility and one contrasting weapon follow. These steps are planning notes; implementation awaits a new request. The user explicitly authorizes committing/pushing the current game and memory updates.
