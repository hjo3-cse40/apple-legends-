# Apple Legends

An original, lightweight Apple Silicon FPS with a playful apple-inspired working title. The first playable area is a small stylized canyon training range built from original primitive geometry.

**Status:** M1 movement prototype is playable. Walking, sprinting, jumping, mouse look, collision, a crosshair, and debug readouts are implemented. Weapons are intentionally deferred.

Repository: https://github.com/hjo3-cse40/apple-legends-

## Setup and run

1. Download **Godot 4.7.2 standard** (not .NET) from https://godotengine.org/download/macos/ and extract Godot.app into Applications. Use the same version on both Macs. The universal app includes native Apple Silicon support.
2. In Godot's Project Manager, choose Import and select this repository's `project.godot`.
3. Open the project and press **F6** with `main.tscn` open, or **F5** to run the project.
4. Walk with **WASD**, look with the **mouse**, hold **Shift** to sprint, and press **Space** to jump. Press **Escape** to release the mouse; left-click the game to recapture it.
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
scenes/ui/debug_hud.tscn            Crosshair, controls, and debug readouts
tests/player_movement_smoke.gd       Headless movement/collision smoke test
docs/architecture.md                 Decisions and feature boundaries
docs/milestones.md                   Acceptance criteria and next steps
```

Godot's generated `.godot/` state and builds are ignored. Godot-generated `.uid` files are committed because scenes use them to keep script references stable.

Next: manually test mouse feel, focus loss/recapture, wall glancing, and repeated jumping on the M3. Tune the exported player values in the Inspector before beginning M2 weapon work. See [milestones](docs/milestones.md) and [architecture](docs/architecture.md).
