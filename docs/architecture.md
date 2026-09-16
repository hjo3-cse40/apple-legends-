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
