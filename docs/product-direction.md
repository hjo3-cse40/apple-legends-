# Apple Legends — product direction and persistent memory

Updated October 2, 2026. This records the user's chosen direction, future ideas, and current implementation boundaries.

## Accepted gameplay and presentation

Tiny expressive robots in a human-sized white garden campus, with graphite, cyan/orange technology accents, greenery, oversized furniture, and readable fast combat. Main visual board is the primary direction; the second board supports personality. Preserve the accepted current scale, audio, moving fire, hybrid Shift sprint, and variable-height jump feel. Robot reference is roughly 55 cm, around human leg height. The current working Godot scene remains the calibration duel; the new Garden Circuit arena is a Blender review asset awaiting integration.

## Game mode and map

The user wants to explore 3v3 King of the Hill. Capture the Flag was withdrawn. A central zone changes ownership and counts down the owning team's remaining clock; the goal is to reach zero. Battle royale is a separate much later possibility. Tone should be fun and playful, with expressive robots and fast fights, drawing broad energy from team arena shooters without copying their content.

Suggested initial rules remain tuning proposals: 120 seconds per team, approximately three seconds to capture, ownership persisting after leaving, countdown paused during contest/takeover, and last-second contest extending play. The exact respawn timing must be tested separately from the existing 0.8-second duel setting. No KOTH/team logic is implemented yet.

Garden Circuit now has original editable geometry, a central objective, six protected spawn markers, ground routes, two raised galleries/four ramps, and optional pickup sockets. All Blender assets, references, renders, and source organization are indexed in `tools/blender_source/README.md`. The visual map GLB is `art/maps/garden_circuit/GardenCircuit.glb`. Layout/render checks do not establish in-game pacing or frame-rate performance. Navigation and complete collision remain integration work.

## Playful utility pickups

The user is interested in random items inspired by the feeling of collecting and using a surprise item in Mario Kart. Proposed approach: one held utility gadget, automatic pickup, a configurable use action, clear icon, and readable counterplay. Candidate effects are a decoy robot, a short-range displacement pulse, and a temporary shield cell. These are ideas, not implemented features. Prove one fixed effect and pickup/use loop before randomizing a small pool. Avoid making objective wins depend on an unreadable random damage spike.

## Preferred sharing experience: a browser link

The user explicitly likes sending a web link so their girlfriend and friends can play without installing the game. Keep building in Godot and plan a web export, rather than rewriting the game as a separate JavaScript project.

Proposed sequence:
1. Validate a browser build of the existing offline bot duel, including performance, input/mouse capture, audio, and visuals.
2. Integrate the arena and implement/tune offline objective rules and navigation.
3. Build a private two-player room/invite experience for the user and their girlfriend.
4. Expand to six players / 3v3 with friends, optionally filling empty places with bots.

Current project uses the Mobile renderer. Godot's current web export uses Compatibility/WebGL 2, so a web configuration and rendering validation are needed. Start with desktop/laptop browsers; phone controls and performance are separate later work. Website hosting serves the client game files; live multiplayer needs its own connection/room and match service. No web build, hosting deployment, room system, or multiplayer implementation has been completed in this task.

Browser networking must be chosen deliberately before committing to a native-only ENet design. Evaluate WebRTC for fast gameplay traffic, with a service for room/signaling setup and connection/relay support as needed; WebSocket may suit an initial connection proof but transport choice requires testing. The authoritative match host/server must own damage, health, respawns, pickups, teams, and objective clocks. Synchronization, responsiveness, reconnect behavior, and internet connectivity require explicit implementation; a link alone does not create multiplayer.

Sources checked October 2, 2026:
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html
- https://itch.io/docs/creators/html5

## Optional future Jev decision layer

The user's spoken “Jeff” idea refers to Jev by TypeSafe. They report receiving $5 in API credit and are interested in letting future bots make decisions through it. This is an exploratory idea, not authorization to spend credit or integrate credentials now.

Keep competent local bot behavior first. Jev could occasionally select among legal tactical goals: capture, defend an entrance, flank, retreat, or collect a gadget. Godot continues navigation, movement, aiming, firing, physics, and damage without waiting for remote requests. Supply compact bot-perceived state and valid actions; avoid omniscient information. Ask after meaningful changes with a cooldown; reject stale/impossible decisions and fall back to local behavior after timeout or failure. Compare quality and measured latency against a local-only baseline before adopting it.

Conditional cost estimate, assuming official TypeSafe pricing checked October 2, 2026: $0.042 per million input tokens, free output. At 500 total input tokens per request and four bots over a ten-minute match, one request per bot every five seconds costs about $0.01008; every second costs about $0.0504. A $5 balance would cover about 119 million input tokens, or roughly 496 five-second-cadence matches under those assumptions. These are calculations, not measured game usage; retries, hosting, account credit conditions, provider differences, and future pricing can change the result. Current published rate limits are 100K tokens/second and 40 requests/second and may change. Price is not proof of decision quality or low end-to-end latency.

For a shared browser build, keep the API key on a backend; never embed it in downloadable client files or commit it. Future integration should have request/spend limits and a disable switch. No Jev requests were made and no credit was consumed by this planning work.

Official references:
- https://docs.typesafe.ai/models
- https://docs.typesafe.ai/introduction

## Repository and publication preference

On October 2, 2026, the user explicitly authorized committing all new repository changes and pushing to their GitHub repository. This supersedes the earlier local/uncommitted preference for this work. Commit messages and trailers must contain no Codex/AI attribution and no AI co-author. Preserve the configured human Git identity; do not invent or alter authorship. Future product ideas above remain planning memory until the user asks to implement them.
