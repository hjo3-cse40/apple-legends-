# Architecture and technical assessment

## Decision: Godot + typed GDScript

A sensible choice for learning, rapid iteration, and a compact original FPS. Use the standard Godot 4.7.2 build. Native Apple Silicon support, built-in 3D collision/character movement, ENet-based multiplayer facilities, and headless execution provide a useful foundation. There is no demonstrated reason to switch engines at M0.

The principal risk is eventual competitive multiplayer scale, not the gray-box controller. Built-in RPCs and replication do not deliver a finished competitive prediction/reconciliation or lag-compensation system. Budget explicit work for input validation, snapshots, bandwidth, interest management, and server CPU costs in M4 and beyond. Start with two players and a small arena; do not promise a large BR player count. Internet hosting, connectivity, abuse prevention, and operations are separate later concerns.

GDScript is appropriate for initial gameplay orchestration. Large bot populations or expensive simulation loops may eventually need profiling-driven restructuring or native code; do not introduce those dependencies now. CharacterBody3D collision is not a promise of deterministic replay across machines. Reconciliation must tolerate differences. The 120+ FPS goal must be measured in representative exported builds on the M3, including frame times and actual render resolution.

## Renderer and timing

Start with Mobile + Metal: Mobile is also a desktop renderer, with fewer advanced effects and a useful fit for simple readable scenes. It does not guarantee superior performance for every workload. Compare with Forward+ later using measured frame times if lighting or scene complexity warrants it. Avoid advanced rendering feature commitments now. Keep default physics cadence (60 Hz) for the initial slice; higher physics rates cost CPU and do not automatically fix mouse latency. Revisit interpolation and cadence from observed behavior during M1.

## Current structure

M1 adds only the pieces needed for the first interactive slice:

- `scenes/levels/movement_lab.tscn`: original primitive-geometry canyon range, collision boundaries, barriers, and a low beam.
- `scenes/player/player.tscn` and `player.gd`: character body, collision capsule, pitch pivot, camera, and focused controller.
- `scenes/ui/debug_hud.tscn` and `debug_hud.gd`: crosshair, control reminder, and observed player state.
- `tests/player_movement_smoke.gd`: headless exercise of movement distance, diagonal normalization, jump, landing, floor/wall collision, and clamped look rotation.

The player tuning values are exported directly to the Godot Inspector. A movement settings Resource is unnecessary until more than one player/controller configuration needs to share the same data.

A **Node** is one scene-tree object with a focused responsibility. A **scene** saves a node subtree and can be instanced, so the player can be reused independently of a map. **CharacterBody3D** provides controlled collision movement with `move_and_slide()`; it does not supply a complete FPS controller. A **Resource** is serialized data, useful for tuning shared independently of scene instances. A **CanvasLayer** keeps the current status overlay separate from the 3D camera; the M1 HUD can use the same approach.

Input sampling should produce movement/look/jump intent; a clear movement step consumes intent in the physics loop. Use simple functions initially, not speculative command buses or transport interfaces. Mouse look consumes relative motion separately from physics; do not multiply mouse displacement by delta. Ground acceleration and gravity use physics delta. UI reads state, never owns movement. Future local prediction can reuse movement rules while the server validates intent and owns authoritative outcomes. No networking code or autoload singleton is required today.

## Sources checked 2026-09-16

- [Official macOS download](https://godotengine.org/download/macos/): 4.7.2 standard, universal ARM64/x86_64 app.
- [Renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html): Mobile/Forward+ tradeoffs and Metal support.
- [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html): transport/RPC facilities and authority considerations.
- [Dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html): headless/server export support.


## M2 boundaries

The rifle is a separate child scene under the first-person camera; player movement remains in its existing controller. Input expresses fire/reload/aim intent, and shot resolution happens in the physics loop using Godot's ray query. The HUD observes weapon state and hit signals. Target colliders own their health, damage response, and reset timer.

This is an offline practice implementation. When multiplayer is introduced, authoritative shot validation and damage application must run on the server; clients must not be allowed to call target damage as trusted outcomes. The current separation makes that change explicit without building networking infrastructure now.

## M3 offline duel

`HealthComponent` owns the reusable health contract while the player exposes a small damage/respawn API. `DuelBot` is a standalone `CharacterBody3D` with direct line-of-sight fire and a deliberately small approach/retreat/strafe controller. `DuelManager` owns scores, spawn selection, timers, match completion, and restart; the HUD only observes and presents that state.

Damage callers may optionally provide a world-space source position. The player converts accepted sourced damage into a signal, and the HUD projects its horizontal direction relative to the current camera into a small radial indicator. This keeps presentation out of the health component and does not couple damage feedback to movement or input handling.

The bot and local rifle call `apply_damage` directly because this milestone is offline. This is not a multiplayer authority model. M4 must move damage validation, health, respawns, and scoring to the server rather than trusting client-side outcomes. The current signals and focused components create seams for that later migration without introducing networking code now.


## Art calibration bay (2026-10-02)

The user authorized the first visual calibration step after selecting the mini-robot concept board. `calibration_bay.tscn` inherits the working movement lab scene, preserving the player/bot/HUD/duel node contracts. `calibration_bay.gd` removes the canyon presentation, adds imported Blender props with simple separate collision, replaces visible weapon and robot meshes, and adjusts lighting/HUD presentation. Main now instances this bay under the existing `MovementLab` name, preserving test paths. The original movement lab is still independently runnable.

The presentation script does not own damage, scoring, respawn, or movement simulation. F1 freezes only the bot physics callback; F2 deliberately changes the camera comparison and relative ADS tuning; F3 shows diagnostics. Inputs use unhandled events and ignore repeats. The bot's original Body mesh remains hidden to preserve its code hook; imported helmet/chest meshes receive a brief material flash on accepted health loss. The cosmetic imported chassis faces +Z, matching the bot's model-front look-at; the rifle is rotated to camera -Z.

Seven original Blender component assets use shared PBR materials, bevels, smooth normals, and embedded glTF geometry; no downloaded assets, paid generation services, or third-party asset credits are involved. Source lives beneath a .gdignore to avoid requiring Blender for Godot import. The reproducible Python builder is scene-isolated and export-selects only each asset.

Calibration retains the accepted simulation dimensions and sells relative miniature scale with larger props. Physical 0.5–1 m scaling, character rigging, bot navigation, weapon-camera separation/wall clipping, and a complete modular garden arena remain future work.

## Spatial character audio

`CharacterAudio` is a presentation child shared by player and bot scenes. It observes ground displacement after character physics, schedules steps by traveled distance, and listens to bot `shot_fired` and player `damaged` signals. Godot `AudioStreamPlayer3D` supplies direction and distance attenuation for mono robot footsteps and shots; local damage uses non-positional feedback. Death/respawn reset accumulated distance and stop movement/gun sounds, and disabled parent physics (F1 inspection) silences the bot. Movement, hit probability, and combat timing are unchanged. Original deterministic PCM assets are generated with the standard-library builder; no asset download or service is needed. Wall obstruction/reverb and ambient music remain future work.

## Scenery proportions and captured firing

Calibration exports separate wall-height and scenery-prop scale values. Wall panels and collision height share the same multiplier; the prop helper scales imported visuals and separate box centers/dimensions together. Benches, chassis, player capsule/camera, spawns, and arena footprint are deliberately unchanged. This creates oversized surroundings without changing the accepted controller's units or combat distances.

The rifle handles captured mouse combat in `_input` so it precedes GUI consumption. Other combat events use `_unhandled_input`, with both delegating to one handler. Handled captured clicks cannot be processed twice; cursor recapture stays in the player's existing path. V is an alternate InputMap fire event, and keyboard echo is ignored to preserve semi-auto cadence. No system trackpad preferences or input drivers are changed.

## Hybrid sprint and variable-height jump

Input sampling supplies movement, fresh jump press, held jump, and held sprint to simulation. A short Shift press toggles on release; a long hold uses momentary sprint and leaves the latch untouched. Duration is tracked by physics time, not keyboard repeat. Simulation uses the resulting sprint state without changing ground speed/acceleration. One reset helper clears latch, held input, and lift state on capture loss, death, and respawn.

Jump launch is immediate, grounded, and single-use. Held Space reduces ascending gravity during a finite 0.35-second window; early release reduces current upward velocity once, easing from a half-speed cut on a tap toward no cut at the end of the lift window and permanently ends that jump's lift. Falling, walking off a ledge, and airborne re-pressing cannot renew lift. Ceiling contact cancels lift. Existing `move_and_slide` floor contact supports landing on static prop tops without a separate mantle/teleport mechanic. Ground motion remains unchanged; gravity/launch and air steering are intentionally tuned for the authorized light vertical feel.

Reference: the user's Destiny example matches [player reports of holding jump for more height](https://www.reddit.com/r/DestinyTheGame/comments/69cws9/holding_jump_instead_of_just_tapping_it_will_make/). This is a feel reference rather than a verified reproduction of Destiny's class-specific physics. Collision behavior uses Godot's [CharacterBody3D contract](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html).

## Garden Circuit integration

`garden_circuit.gd` extends the existing calibration presentation, reusing robot/rifle/audio/HUD and F1/F2/F3 without rebuilding the arena art. Its inherited duel nodes keep their existing names and contracts. Exported marker positions feed both starting and respawn transforms. The map uses 1/0.31 simulation units per Blender meter. Static triangle collision is created once at startup for the solid mesh batches, including ramps, roofs and props; decorative planting/signage is excluded. This prioritizes accurate first-playtest collision; no frame-rate target is claimed. Esc settings uses an always-processing CanvasLayer and tree pause so both combat and respawn timers stop. Sensitivity updates the existing player field and persists with ConfigFile. Main remains an offline duel; KOTH, navigation and multiplayer are deferred.

## Stable map surfaces and CS control units

The Blender source formerly placed the foundation and slab top faces at z=0. These now sit at -0.06 and -0.025 m, below the paver tops at +0.015 m. A continuous floor box has its top at +0.015 m. The regenerated GLB has ten visual batches and one hidden solid-plant batch; glTF extras arrive in Godot under the `extras` metadata dictionary. The runtime excludes decorative planting/signage and the ground mesh from triangle collision, uses the hidden solid plants, and enables backface collision for other solid batches. Automatic LOD and vertex compression are disabled on this map to keep fine planar geometry intact.

Controls use Valve's default 0.022 degree yaw/pitch coefficient. The player retains its internal radians/count field; only the Garden settings path enables CS units and divides incoming `screen_relative` by Godot macOS's maximum attached display scale. DPI is informational because sensor counts already incorporate hardware DPI. Numeric entry is independent of the coarse slider and supports six decimals; saved legacy values migrate to equivalent physical gain. This matches the standard hipfire angular formula; hardware/device delivery and nondefault CS settings require physical validation.

References: https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/client/in_mouse.cpp and https://github.com/godotengine/godot/blob/4.7.2-stable/platform/macos/godot_content_view.mm .

## Expanded arena geometry

The map footprint is 32 × 44 m with floors at 0, 1.65 and 3.30 m. The Godot floor box matches the enlarged ground. The Blender source preserves physical prop scale and compiles the same ten visual batches plus the hidden solid planting batch; ramp triangles supply actual sloped contacts. Named markers carry resized spawn positions and gallery/terrace heights. The accepted player controller needs no speed, jump or collision changes. Runtime traversal checks use the real capsule to prove eight ramps connect cleanly, underpasses remain open and tier drops land safely; 90 sampled ground/gallery/upper views check spawn shielding. The export also updates the source asset summary to avoid stale geometry counts.

The original capture platform had vertical lips that blocked an actual walking capsule. Three shallow concentric approach strips now join ground paving through the existing inlay heights; the controller remains unchanged. Four cardinal walking-entry checks exercise this separately from jumping onto the point.

## Ledge recovery and directional air acceleration

The player rearms a ledge-jump flag only after actual `move_and_slide()` floor contact; a launch consumes it. Normal grounded launch and descending walk-off recovery share the existing finite lift/early-release path. This avoids an arbitrary coyote timer while preventing a second launch after a normal jump. Resetting intent clears the flag on lifecycle/capture changes. Gravity is 13.2, preserving constant falling acceleration without a slow-fall phase.

Air acceleration changes only the velocity component along the world-space input direction: subtract its dot product from the 2.5 wish-speed cap, and add the smaller of that remainder and acceleration coefficient 8 × requested speed × delta. Perpendicular carry is preserved. Ground acceleration/braking remain unchanged. The algorithm follows the directional structure of Valve's [AirAccelerate](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/gamemovement.cpp), using original game tuning.

## Small step-up traversal

`step_height` is 0.35 game units (about 10.85 cm in Garden Circuit). Only grounded frames without a jump launch attempt a step. A horizontal capsule sweep first identifies a blocking face; separate up/across/down sweeps verify clearance and static landing support. A short ray just inside the contact checks the tread's normal and actual top height: rounded capsule feet and beveled pads can initially contact a steep corner even when the tread is walkable. The candidate top must be within the allowance and floor angle. Only vertical position is adjusted, with horizontal travel handled once by `move_and_slide`; no upward velocity is injected. Tall obstacles, ceilings and airborne motion cannot use this path. Ground braking, gravity, jump and air acceleration remain unchanged. These probes use Godot's [PhysicsBody3D.test_move](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-test-move).

## Miniature environment proportions

Environment scale is authored in meters in Blender, rather than shrinking the player or changing the runtime conversion. `miniature_world.py` records the one-time dressing pass and refuses duplicate application. Furniture parents scale uniformly; architectural heights and planting groups enlarge around their ground anchors. Traversal meshes and gameplay markers retain their previous dimensions. All new benches, tables and arches compile into the existing batches with matching solid collision; decorative foliage remains non-solid. There are still ten compiled visual meshes (268,258 vertices, versus 262,170 before this pass); this is asset accounting, not a performance benchmark. Runtime/source scale metadata records the miniature-world pass.
