# Apple Legends

An original, lightweight Apple Silicon FPS with tiny expressive robots and clean white technology. The default scene is the **LAN party lobby**, launching Garden Circuit KOTH with up to three players per team and optional bots. The calibration duel and canyon training range remain available separately.

**Status:** Build 0.4.3 private native Mac LAN playtest: host/join, choose teams, ready, optional bots up to 3v3, synchronized combat and KOTH. See [Play together](docs/lan-playtest.md) for exported-app instructions. Your partner does not need Godot. Offline scenes remain available.

The latest bot pass adds distinct hill entries, transit combat, persistent reload cover and progress recovery. Local decision-model options and their limits are documented in [local bot intelligence options](docs/local-bot-intelligence-options.md).

## Garden Circuit KOTH

Run F5 for the LAN lobby. For the original offline duel, open `scenes/main/main.tscn` and run F6. In that offline scene you are CYAN; the robot is AMBER. The hill unlocks after 15 seconds. One player captures in 12 seconds; each team has a separate 3:00 clock. Ownership continues when the owner leaves; recapture switches the active clock while preserving both remaining times. Both teams standing on the point freezes capture and both clocks. Only living, grounded characters inside the visible ring count. Jumping through the air above it does not capture.

At zero, an enemy still on the hill forces overtime until they capture or leave/get eliminated. A winner stops gameplay; Enter restarts the round. Death respawns after 3 seconds with full health/ammo. The bot routes around spawn cover, captures, defends and returns after respawning. F1 freezes the test bot; Esc pauses the entire match and opens saved sensitivity settings.

The three-minute ownership pattern follows [Valve's KOTH introduction](https://www.teamfortress.com/classless/day02.php). The 12-second capture, 15-second unlock and 3-second individual respawn are this prototype's tuning. Contested clocks deliberately pause to honor the requested no-progress rule. These rules also run on the LAN host for the shared team match.

## Combat readability pass — October 3

The semi-auto rifle deals 22 damage every 0.22 seconds: five body hits to eliminate a 100-health opponent, with a theoretical 0.88-second first-to-final-hit time. Hold right-click for a smooth 80° to 58° vertical FOV transition. The enemy has a red health bar and numeric health above its head while visibly in front of the camera. Walls, death and leaving the screen hide the readout.

Global original capture chimes distinguish Cyan (rising) and Amber (falling), with synthesized team callouts. Each team's retained ownership clock announces 30 seconds, 10 seconds and the final five seconds; contests pause those clocks. An overtime callout and a rate-limited contest chime support objective readability. Captions mirror audio, and round restart clears both cue history and captions. All shipped audio is ordinary WAV data; the optional macOS rebuild script uses the system Samantha voice. No network service is required. Holographic enemy-highlighting ADS remains a future weapon-design pass.

`tests/combat_readability_smoke.gd` verifies actual camera-ray damage, health visibility/death/respawn, repeated audio cycles and native mouse ADS/screenshots. Run without `--headless` to check captured right-click input and rendered output; the headless display cannot capture the mouse.

## Art calibration — testing the new look

Open `scenes/levels/calibration/calibration_bay.tscn` and press **F6**. You will start in a bright white calibration courtyard with a robot opponent, a cyan-accented rifle and robotic hands, a display chassis, benches, planters, cargo pods, and charging columns.

- **F1:** pause/resume the opponent for inspection. You can still walk, aim, shoot, reload, and damage the bot.
- **F2:** compare the accepted 80° vertical FOV with approximately 90° horizontal at 16:9 (58.7155° vertical). ADS narrows by 22° (clamped to 40°); switching back restores 80°/58°. The label states the convention.
- **F3:** toggle FPS/movement diagnostics. Existing gameplay controls remain unchanged. Some Mac keyboards require Fn with function keys.
- The duel still ends at five eliminations. Enter/Space restarts as before.
- For the original canyon baseline, open `scenes/levels/movement_lab.tscn` and press **F6**.

The calibration scene retains simulation scale, capsule dimensions, speeds, sensitivity, magazine capacity, reload timing, and respawn timing; the October 3 readability pass updates the shared rifle damage/cadence. Miniature proportions and oversized reference props establish perceived scale; this is not yet a physical 0.75 m controller conversion. The robot is an editable component model with a modest procedural motion accent, not a finished skinned animation rig. No new weapon, class, traversal, or networking system is added.

Blender source: `tools/blender_source/calibration_assets.blend`. The `.gdignore` alongside it prevents Godot from importing the workshop itself. Godot consumes seven exported `.glb` files in `art/calibration`, so playing does not require Blender running. `tools/build_calibration_assets.py` reproduces the models in a separate Blender scene; it preserves existing scenes, selects only the exported asset, applies bevels/normals, and saves the source. Its output location currently targets this checkout.

Please test: rifle size/hand placement, ADS sight visibility, opponent contrast against white walls, perceived miniature scale beside the bench, and whether the bright lighting feels comfortable. The calibration layout deliberately keeps the bot's central ground lane simple; complex navigation is deferred.

Repository: https://github.com/hjo3-cse40/apple-legends-

## Setup and run

1. Download **Godot 4.7.2 standard** (not .NET) from https://godotengine.org/download/macos/ and extract Godot.app into Applications. This editor setup is for development; playtest partners receive the exported app. The universal app includes native Apple Silicon support.
2. In Godot's Project Manager, choose Import and select this repository's `project.godot`.
3. Open the project and press **F6** with `main.tscn` open, or **F5** to run the project.
4. Walk with **WASD**, look with the **mouse**, tap **Shift** to toggle sprint or hold it for momentary sprint, and press/hold **Space** to control jump height. **Left-click or V** fires one shot, hold **right-click** to aim, and press **R** to reload. Capture the central point and run your team clock to zero; press **Enter** after victory/defeat to restart. **Escape** opens settings and pauses the match.
5. Stop with F8 in the editor or close the game window. Confirm the Output/Debugger panels show no errors and the startup output reports Metal. In Activity Monitor, confirm the running process is Apple/native rather than Intel.

Optional terminal checks after installing in Applications, from this repository:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --version
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 10
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Headless checks validate import/startup, not Metal rendering or input feel. Review output for errors as well as exit status.

Run the small automated movement/collision smoke check with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/player_movement_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/rifle_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/target_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/health_component_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/bot_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/duel_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/damage_indicator_smoke.gd
```

Godot 4.7.2, Git, and Xcode tools are available on the inspected Mac. No package manager, .NET SDK, third-party plugin, or full engine build is needed. Export templates matching the editor are needed only when producing app builds; defer them until then. Public macOS distribution/signing/notarization is a later task. An external code editor is optional; begin with Godot's built-in editor.

## Repository

```text
AGENTS.md                 Persistent development rules
README.md                 Setup and current status
project.godot                       Engine settings, controls, and entry scene
scenes/main/main.tscn               Small composition root
scenes/levels/movement_lab.tscn     Collidable canyon training range
scenes/player/player.tscn           Reusable first-person player
scenes/player/player.gd             Movement, jump, sprint, and mouse look
scenes/combat/                      Reusable health component
scenes/bots/                        Offline duel bot and state-driven combat
scenes/duel/                        Scoring, respawn, and match lifecycle
scenes/ui/debug_hud.tscn            Health, score, crosshair, ammo, and feedback
scenes/weapons/                     Semi-auto rifle and viewmodel
scenes/targets/                     Reusable practice targets
tests/player_movement_smoke.gd       Headless movement/collision smoke test
docs/architecture.md                 Decisions and feature boundaries
docs/milestones.md                   Acceptance criteria and next steps
```

The practice rifle has a 12-round magazine and infinite reserve ammunition. It now has a procedural reload animation, transient FOV kick, stronger muzzle flash, and short-lived impact sparks. The bot uses deliberately simple line-of-sight shooting plus approach/retreat/strafe movement. It has a visible reaction/aim delay, imperfect accuracy, a muzzle flash, and a compact camera-relative red hit-direction chevron so incoming fire is readable rather than instantaneous; it is not intended to imitate a human player yet.

Godot's generated `.godot/` state and builds are ignored. Godot-generated `.uid` files are committed because scenes use them to keep script references stable.

Next: manually tune bot accuracy, damage, movement speed, spawn safety, reload feel, and match pacing. Ground movement speeds remain unchanged. Hybrid sprint and variable-height jumping are implemented below; further speed and sensitivity tuning remain deferred. See [milestones](docs/milestones.md) and [architecture](docs/architecture.md).

## Robot audio

Bot shots and mechanical footsteps now use positional mono audio: stereo direction and distance falloff help locate the opponent. Shots sound on misses as well as hits. Your own footsteps are quieter, with a short shield tick on incoming damage. Step cadence follows actual ground travel (including sprint speed); idle, airborne, dead, and F1-paused characters do not generate steps. Sounds do not currently model sound obstruction through walls.

Original WAV assets are in `art/audio/`; rebuild them with `python3 tools/build_audio.py`. Volume, stride length, and spatial reach are exposed in `scenes/audio/character_audio.gd` and the character scene overrides. Run `tests/character_audio_smoke.gd` with the same headless command above. Listen during a normal F5 playtest to judge final volume balance.

## Miniature scenery and laptop testing

The calibration bay now surrounds the unchanged robots and benches with taller walls/skyline and enlarged planters, cargo, and chargers. Tune `architecture_height_scale` and `scenery_prop_scale` on the calibration scene; collisions follow those values. Movement and the playable footprint are unchanged.

Fire with **left-click or V**, including while walking or holding Shift to sprint. Captured mouse firing is processed before the HUD. V offers keyboard firing while using the trackpad to aim; the semi-auto rifle still needs a fresh press for each shot. Physical trackpad simultaneous-input behavior needs a hands-on test, since the game cannot receive clicks filtered by the OS/device. Native input coverage (not headless) is available with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/moving_fire_smoke.gd
```

Crouch and the suggested arms-back running animation are recorded for a later step. Sprint toggle is now implemented as described below.

## Light vertical movement

Tap **Shift** (under 0.22 seconds) to toggle sprint on/off. Hold it longer for momentary sprint; releasing a long hold preserves your prior toggle setting. The calibration status shows WALK/SPRINT. Escape, focus loss, death, and respawn clear sprint/jump intent.

**Space** jumps immediately. Tap for a small hop, or hold up to 0.35 seconds for full height; release sooner to shorten the rise. Measured flat-ground peaks are about 1.2, 3.7, and 5.9 units for tap, short hold, and full hold. Gravity is 14 (previously 24), launch speed 11 (previously 8.5), and air steering acceleration 8 (previously 5). Countersteer to brake air momentum and land on narrow props. Holding Space does not automatically jump again on landing. Full jumps reach benches, enlarged cargo and planters, and charger tops; perimeter walls remain boundaries.

Run `tests/vertical_movement_smoke.gd` headlessly for sprint state/speed, jump-height control, real prop landings, ceiling impact, and lifecycle checks. Final perceived floatiness and platform control need your playtest.

## Editable Blender sources

Start with [the Blender asset index](tools/blender_source/README.md). Separate files cover the Garden Circuit map, cyan player robot, amber enemy robot, rifle/first-person hands, and campus props. The map has clear Map, Characters, Gameplay, and Review Outliner groups. Sources remain under `.gdignore`; current runtime calibration paths and gameplay are unchanged. The new visual map GLB is in `art/maps/garden_circuit/`.

Future browser sharing, private multiplayer, KOTH/gadget ideas, and the optional Jev tactical-bot experiment are recorded in [product direction](docs/product-direction.md). These are plans; the current build remains offline.

## Garden Circuit playtest

The default game now opens the authored Garden Circuit map. Blender sources remain in `tools/blender_source/maps/garden_circuit/GardenCircuit.blend`; the game uses `art/maps/garden_circuit/GardenCircuit.glb`. The arena is scaled by 1/0.31 to preserve the accepted robot sizes, speeds and jump feel. Solid exported surfaces provide static triangle collision; foliage and signs are decorative. The original calibration scene remains available separately.

**WASD** moves, **Shift** taps/toggles or holds sprint, **Space** controls jump height, **LMB/V** fires, **RMB** aims, **R** reloads. **F1** freezes/unfreezes the test bot; **F2/F3** retain FOV/stats inspection. **Esc** opens the settings panel and pauses the world; Esc or Resume returns to captured-mouse play. Enter your CS2/CS:GO hipfire sensitivity directly (six decimal places), with a reset to 2.5. Use the same hardware DPI and default CS yaw/pitch 0.022. The DPI reference field reports eDPI and expected cm/360; it does not change hardware DPI or multiply aiming again. It saves locally in Godot's `user://controls.cfg`. The menu also exposes bot freeze and preserves that choice on resume.

Native integration check: `Godot --path . --script res://tests/garden_settings_smoke.gd`. The bot retains its simple offline duel logic and does not yet navigate around complex cover. Capture rings and pickups remain visual placeholders; this is a map exploration/duel build, not team KOTH rules.

### Map stability and collision follow-up

Foundation, underlying slab and paving now have separated top planes. One continuous level floor collider prevents dipping at visual seams. Solid planters, soil surfaces, trunks and branches use a hidden authored collision batch; leaves and flat cosmetic decals remain decorative. All solid mesh batches enable backface collision. Map LOD and vertex compression are disabled to preserve thin geometry; 4× MSAA reduces edge shimmer. The map source and runtime export are both updated. `tests/garden_obstacles_smoke.gd` probes 454 authored obstacle samples from both sides, walks across tile seams and drives the capsule into a planter.

The CS coefficient is `radians(0.022) × sensitivity` per delivered mouse count on both axes. Godot 4.7.2 adds the maximum attached Retina display scale to macOS mouse deltas; the CS path removes it, while the original calibration input stays unchanged. Existing saved screen-pixel sensitivity is migrated with that scale so its gain is retained. CS custom yaw, acceleration, stretched-FOV feel and scoped/ADS behavior are not emulated. Angular math and synthetic native input are verified; matching physical cm/360 still needs a same-DPI mouse playtest, especially across operating systems or mouse drivers.

## Expanded Garden Circuit — October 3, 2026

The default arena now has a 32 × 44 m courtyard, longer screened approaches and flanks, 1.65 m galleries and 3.30 m orchard terraces. Four ground ramps and four upper ramps connect every tier; ground underpasses and drop shortcuts remain open. Robot/furniture scale, controller tuning, F1 bot freeze and Esc sensitivity settings are preserved. The hill stays central and readable, with a shallow all-direction apron removing the old platform lip. TF2 KOTH supplies a pacing reference; this is original geometry with offline duel rules.

Run `Godot --path . --script res://tests/garden_expansion_smoke.gd` natively for real capsule climbs, tier drops, underpasses, travel timing and 90 sampled spawn views. Run `garden_obstacles_smoke.gd` and `garden_settings_smoke.gd` natively for collision and input/settings regressions. Headless mouse capture is unsuitable for these input-dependent checks. No 3v3 balance or frame-rate benchmark is claimed.

### Ledge recovery and air strafing

Gravity is slightly lighter (13.2 from 14), with continuous downward acceleration. After walking off a ledge, press Space during the fall for one recovery jump; landing resets it. A normal jump already uses that launch. In the air, hold **A + smoothly turn left**, or **D + smoothly turn right**, to strafe while preserving momentum. Ground controls, sprint, variable-height Space and sensitivity are retained. `tests/air_movement_smoke.gd` exercises real ledge recovery and airborne steering; `vertical_movement_smoke.gd` checks variable jump height and prop landings.

### Walking over small ledges

Low steps and spawn pads up to 0.35 game units (about 11 cm at Garden Circuit scale) can be walked over without Space. The full capsule must have clearance and a walkable tread; taller obstacles still require jumping. Step-up only applies while grounded and does not add upward jump momentum. `step_up_smoke.gd` checks low/near-limit steps, ceiling and taller-wall rejection and airborne safety; `garden_spawn_steps_smoke.gd` crosses all six authored pads with the fixture bot's collision excluded.

## Miniature garden world

Garden Circuit now uses giant human furniture and architecture around the unchanged 55 cm robot: benches are 3× larger, doors 6.6 m tall, café tables 2.25 m tall, and white garden arches reach 19.5 m. Larger trees and skyline towers reinforce the bright original garden-campus atmosphere. The courtyard and climbing routes retain their existing gameplay dimensions.

`tests/miniature_world_smoke.gd` checks solid oversized bench proportions and walking beneath its seat. The map route and 482-surface collision checks pass; see milestone notes for verification limits.

## Wall visibility and gallery clearance

The gun stays visible at wall contact through local viewmodel depth compression, with unchanged aiming and wall-blocked hitscan. Upper ramps now start outside the middle-gallery lanes and meet notched high-tier landings. Decorative tree branches no longer snag the player; trunks and planters stay solid. `garden_gallery_clearance_smoke.gd` checks gallery/high-tier walking and 70 jump locations; `viewmodel_wall_smoke.gd` checks native hip/ADS visibility and shared-material isolation. See milestone notes for checks and limits.

## October 5 playtest improvements

Sequence-aware client correction and respawn packet gates address joining-player jitter; timestamped remote interpolation smooths packet cadence. Esc offers saved two-slot keyboard/mouse bindings (Space + wheel-down jump by default), and host developer tools expose Simple/Normal/Expert bots with sprinting, varied combat movement and safe hops. Gunfire gain is consistent across peers and increased. Movement tuning remains unchanged. See docs/lan-playtest.md and docs/movement-bots-modes.md for behavior, limits and future design.
