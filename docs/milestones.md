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
