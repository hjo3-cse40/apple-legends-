# Native FPS Prototype

Original Apple Silicon FPS, starting with a small gray-box movement prototype. Working title only; game identity is undecided.

**Status:** M0 scaffold created. Godot startup/visual validation pending. No movement or gameplay scripts yet.

## Setup and run

1. Download **Godot 4.7.2 standard** (not .NET) from https://godotengine.org/download/macos/ and extract Godot.app into Applications. Use the same version on both Macs. The universal app includes native Apple Silicon support.
2. In Godot's Project Manager, choose Import and select this repository's `project.godot`.
3. Open the project and press **F6** with `main.tscn` open, or **F5** to run the project.
4. Expect a gray floor, fixed camera, and M0 status text. Movement is intentionally absent. Stop with F8 in the editor or close the game window.
5. Confirm the Output/Debugger panels show no errors and the startup output reports Metal. In Activity Monitor, confirm the running process is Apple/native rather than Intel.

Optional terminal checks after installing in Applications, from this repository:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --version
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 10
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Headless checks validate import/startup, not Metal rendering or input feel. Review output for errors as well as exit status.

Git and Xcode tools were already available on the inspected Mac; Godot was not found. Nothing was installed. No package manager, .NET SDK, third-party plugin, or full engine build is needed. Export templates matching the editor are needed only when producing app builds; defer them until then. Public macOS distribution/signing/notarization is a later task. An external code editor is optional; begin with Godot's built-in editor.

## Repository

```text
AGENTS.md                 Persistent development rules
README.md                 Setup and current status
project.godot             Engine settings and entry scene
scenes/main/main.tscn     Minimal static startup scene
 docs/architecture.md     Decisions and planned feature boundaries
 docs/milestones.md       Acceptance criteria and next steps
```

The floor is a visual startup fixture, not a collision arena. No player or input mappings exist yet. Generated `.godot/` state and builds are ignored; commit Godot-generated `.uid` files when introduced.

Next: complete the M0 runtime smoke check, then implement M1's smallest controller slice: collision floor/walls, CharacterBody3D capsule, mouse look, and WASD movement. See [milestones](docs/milestones.md) and [architecture](docs/architecture.md).
