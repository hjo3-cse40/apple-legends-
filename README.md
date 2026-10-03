# Apple Legends

An original, lightweight Apple Silicon FPS with tiny expressive robots and clean white technology. The default playable scene is now the **A1 art calibration bay**, using original Blender assets over the working offline duel. The original canyon training range remains available separately.

**Status:** M3 offline duel prototype: player health, a moving/shooting bot, death and timed respawns, first-to-five scoring, match restart, and improved weapon feedback alongside the accepted movement and gunplay. See docs/milestones.md for validation status.

## Art calibration — testing the new look

Open the project in `/Users/samjo/Apple Legends` and press **F5**. You will start in a bright white calibration courtyard with a robot opponent, a cyan-accented rifle and robotic hands, a display chassis, benches, planters, cargo pods, and charging columns.

- **F1:** pause/resume the opponent for inspection. You can still walk, aim, shoot, reload, and damage the bot.
- **F2:** compare the accepted 80° vertical FOV with approximately 90° horizontal at 16:9 (58.7155° vertical). ADS retains a 13° reduction; switching back restores 80°/67°. The label states the convention.
- **F3:** toggle FPS/movement diagnostics. Existing gameplay controls remain unchanged. Some Mac keyboards require Fn with function keys.
- The duel still ends at five eliminations. Enter/Space restarts as before.
- For the original canyon baseline, open `scenes/levels/movement_lab.tscn` and press **F6**.

The calibration scene retains simulation scale, capsule dimensions, speeds, sensitivity, damage, magazine capacity, reload timing, and respawn timing. Miniature proportions and oversized reference props establish perceived scale; this is not yet a physical 0.75 m controller conversion. The robot is an editable component model with a modest procedural motion accent, not a finished skinned animation rig. No new weapon, class, traversal, or networking system is added.

Blender source: `tools/blender_source/calibration_assets.blend`. The `.gdignore` alongside it prevents Godot from importing the workshop itself. Godot consumes seven exported `.glb` files in `art/calibration`, so playing does not require Blender running. `tools/build_calibration_assets.py` reproduces the models in a separate Blender scene; it preserves existing scenes, selects only the exported asset, applies bevels/normals, and saves the source. Its output location currently targets this checkout.

Please test: rifle size/hand placement, ADS sight visibility, opponent contrast against white walls, perceived miniature scale beside the bench, and whether the bright lighting feels comfortable. The calibration layout deliberately keeps the bot's central ground lane simple; complex navigation is deferred.

Repository: https://github.com/hjo3-cse40/apple-legends-

## Setup and run

1. Download **Godot 4.7.2 standard** (not .NET) from https://godotengine.org/download/macos/ and extract Godot.app into Applications. Use the same version on both Macs. The universal app includes native Apple Silicon support.
2. In Godot's Project Manager, choose Import and select this repository's `project.godot`.
3. Open the project and press **F6** with `main.tscn` open, or **F5** to run the project.
4. Walk with **WASD**, look with the **mouse**, tap **Shift** to toggle sprint or hold it for momentary sprint, and press/hold **Space** to control jump height. **Left-click or V** fires one shot, hold **right-click** to aim, and press **R** to reload. The duel is first to five eliminations; press **Enter** or **Space** after victory/defeat to restart. Press **Escape** to release the mouse; left-click the game to recapture it without firing.
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

Foundation, underlying slab and paving now have separated top planes. One continuous level floor collider prevents dipping at visual seams. Solid planters, soil surfaces, trunks and branches use a hidden authored collision batch; leaves and flat cosmetic decals remain decorative. All solid mesh batches enable backface collision. Map LOD and vertex compression are disabled to preserve thin geometry; 4× MSAA reduces edge shimmer. The map source and runtime export are both updated. `tests/garden_obstacles_smoke.gd` probes 371 authored obstacle samples from both sides, walks across tile seams and drives the capsule into a planter.

The CS coefficient is `radians(0.022) × sensitivity` per delivered mouse count on both axes. Godot 4.7.2 adds the maximum attached Retina display scale to macOS mouse deltas; the CS path removes it, while the original calibration input stays unchanged. Existing saved screen-pixel sensitivity is migrated with that scale so its gain is retained. CS custom yaw, acceleration, stretched-FOV feel and scoped/ADS behavior are not emulated. Angular math and synthetic native input are verified; matching physical cm/360 still needs a same-DPI mouse playtest, especially across operating systems or mouse drivers.
