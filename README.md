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
4. Walk with **WASD**, look with the **mouse**, hold **Shift** to sprint, and press **Space** to jump. **Left-click** fires one shot, hold **right-click** to aim, and press **R** to reload. The duel is first to five eliminations; press **Enter** or **Space** after victory/defeat to restart. Press **Escape** to release the mouse; left-click the game to recapture it without firing.
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

Next: manually tune bot accuracy, damage, movement speed, spawn safety, reload feel, and match pacing. Movement remains unchanged. Toggle sprint, faster sprint, and lower base sensitivity are recorded for later tuning. See [milestones](docs/milestones.md) and [architecture](docs/architecture.md).
