# Milestones

M0 foundation → M1 movement → M2 gunplay → M3 feel/polish → M4 multiplayer → M5 small arena → M6 BR systems → M7 mini BR → M8 original content/polish.

## M0 acceptance

- [x] Minimal Godot project with a designated launch scene, fixed camera, visible fixture, and status overlay.
- [x] README, persistent agent rules, architectural rationale, and milestone criteria exist.
- [x] No third-party dependencies, gameplay framework, or later gameplay systems added.
- [ ] Local Git repository has an initial commit and clean working tree.
- [x] Godot 4.7.2 installed and exact version confirmed on development machine.
- [x] Editor import and headless startup complete without errors.
- [x] F5 visually shows the canyon range and HUD; no startup errors were observed.
- [x] Native Apple Silicon execution and Metal renderer confirmed on the M3 Pro.

M0's runnable checkpoint is a static scene; M1 delivers interactive play. Do not call M0 fully verified until the pending runtime checks pass.

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

Each step should be a small logical commit after its relevant checks. M2 starts only after explicit authorization and a satisfactory movement baseline.

## Validation record

2026-09-16 M0: host reports arm64; Git 2.39.5 and Xcode developer directory available. Initial scaffold committed as `6d90d57`.

2026-09-16 M1 implementation: `/Applications/Godot.app/Contents/MacOS/Godot --version` reports `4.7.2.stable.official.ed1daf0bf`. Editor import and a 30-frame headless launch completed without parser/runtime errors. `tests/player_movement_smoke.gd` passed forward movement, diagonal normalization within 2%, jump/landing, floor/wall collision, mouse yaw/pitch, and pitch clamping. GUI startup showed the correctly lit range and grounded HUD through Metal on the M3 Pro. Focus handling, subjective mouse feel, wall/ceiling behavior, frame-cap measurements, and the 10-minute session remain manual checks.
