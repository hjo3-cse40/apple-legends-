# Apple Legends — product direction and persistent memory

Updated October 3, 2026. This records the user's chosen direction, future ideas, and current implementation boundaries.

## Accepted gameplay and presentation

Tiny expressive robots in a human-sized white garden campus, with graphite, cyan/orange technology accents, greenery, oversized furniture, and readable fast combat. Main visual board is the primary direction; the second board supports personality. Preserve the accepted current scale, audio, moving fire, hybrid Shift sprint, and variable-height jump feel. Robot reference is roughly 55 cm, around human leg height. The default Godot scene now runs the playable Garden Circuit arena with the existing offline duel, robot/rifle models and accepted locomotion. The original calibration scene remains available separately.

## Game mode and map

The user wants to explore 3v3 King of the Hill. Capture the Flag was withdrawn. A central zone changes ownership and counts down the owning team's remaining clock; the goal is to reach zero. Battle royale is a separate much later possibility. Tone should be fun and playful, with expressive robots and fast fights, drawing broad energy from team arena shooters without copying their content.

Suggested initial rules remain tuning proposals: 120 seconds per team, approximately three seconds to capture, ownership persisting after leaving, countdown paused during contest/takeover, and last-second contest extending play. The exact respawn timing must be tested separately from the existing 0.8-second duel setting. No KOTH/team logic is implemented yet.

Garden Circuit now has original editable geometry, a central objective, six protected spawn markers, ground routes, two raised galleries/four ramps, and optional pickup sockets. All Blender assets, references, renders, and source organization are indexed in `tools/blender_source/README.md`. The visual map GLB is `art/maps/garden_circuit/GardenCircuit.glb`. Layout/render checks do not establish in-game pacing or frame-rate performance. Solid map collision is integrated and audited; advanced bot navigation and KOTH/team rules remain future work.

## Playful utility pickups

The user is interested in random items inspired by the feeling of collecting and using a surprise item in Mario Kart. Proposed approach: one held utility gadget, automatic pickup, a configurable use action, clear icon, and readable counterplay. Candidate effects are a decoy robot, a short-range displacement pulse, and a temporary shield cell. These are ideas, not implemented features. Prove one fixed effect and pickup/use loop before randomizing a small pool. Avoid making objective wins depend on an unreadable random damage spike.

## Preferred sharing experience: a browser link

The user explicitly likes sending a web link so their girlfriend and friends can play without installing the game. Keep building in Godot and plan a web export, rather than rewriting the game as a separate JavaScript project.

Proposed sequence:
1. Validate a browser build of the existing offline bot duel, including performance, input/mouse capture, audio, and visuals.
2. Implement/tune offline objective rules and navigation in the already integrated arena.
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

## Latest runtime state and user acknowledgment — October 3, 2026

The user said the menu “looks okay,” then requested fixes for ground jitter, transparent/pass-through objects and CS2/CS:GO sensitivity units. After the fixes were reported, the user said “ok update memory.” Record this as acknowledgment and a request to persist the current state; it does not establish a comprehensive physical-input or performance playtest.

Current implementation: local branch `feature/garden-movement-settings`; map/settings integration commit `16de62f`, stability/collision/CS controls commit `c4591ea`. Checkout: `/Users/samjo/Documents/Codex/2026-10-02/for-x20-2/work/apple-legends`. The original `/Users/samjo/Apple Legends` checkout remains on its existing branch. Launch the feature build through `/Users/samjo/Documents/Codex/2026-10-02/for-x20-2/outputs/Play Apple Legends.command`.

- Garden Circuit imports the authoritative Blender map at 1/0.31 game units per meter, preserving robot scale and accepted walk/sprint/jump tuning. Existing robot, rifle/hands, audio, offline duel and respawns remain. F1 freezes the test bot; F2/F3 retain FOV/stats inspection. The simple bot may get caught on cover; no navigation upgrade was implemented.
- Esc opens the selected white/graphite/cyan right-side settings panel, pauses simulation and respawn timers, and releases the mouse. Esc/Resume restores captured-mouse gameplay and preserves bot freeze. Three menu variations were rendered; the right panel is the default.
- Ground foundation/slab top planes formerly coincided. They now sit below the paving; a continuous floor collider avoids seam dips. Automatic map LOD and vertex compression are disabled to preserve thin geometry; 4× MSAA reduces edge shimmer. A hidden authored batch supplies collision for 100 solid planting components, including basins, soil surfaces, trunks and branches. Solid triangle collision works from both sides. Leaves, flat light decals and tiny cargo trim are decorative/backed by solid obstacles. Blender source and runtime export are both updated; regeneration is `tools/blender_source/maps/garden_circuit/provenance/export_runtime_map.py`.
- Mouse controls now accept CS2/CS:GO-style hipfire sensitivity directly with six decimal places, using default yaw/pitch coefficient 0.022 degrees per delivered count. Godot 4.7.2's added macOS Retina factor is removed in this path; baseline calibration input remains unchanged. DPI is a reference field for eDPI and expected cm/360, not another aiming multiplier or a hardware-DPI change. Existing saved rad/screen-pixel values migrate to preserve their gain; reset is CS sensitivity 2.5. Values save locally to `user://controls.cfg`. Standard angular math is verified; same-DPI physical cm/360 still needs a mouse playtest. Custom CS yaw, acceleration, stretched-FOV feel and scoped/ADS behavior are not emulated.

Verification evidence: native checks pass for 371 authored solid obstacle samples from both sides, capsule blocking at the cyan planter, level movement across paving seams, floor/ramp/jump behavior, F1 freeze and Esc lifecycle. Typed sensitivity 1.234567 with supplied 1000/200 counts gives yaw 27.160474° and pitch 5.4320948°, including Retina normalization. Exact value/DPI persistence and DPI not altering gain pass. A stationary ground image patch was pixel-identical across 30 rendered frames; this is limited to that sampled view. Calibration locomotion regression passes. No frame-rate benchmark or whole-map/hardware guarantee is recorded.

Latest screenshots: `/Users/samjo/Documents/Codex/2026-10-02/for-x20-2/outputs/cs-settings.png` and `/Users/samjo/Documents/Codex/2026-10-02/for-x20-2/outputs/garden-fixed.png`.

Publication status: these feature commits are local. The attempted feature-branch push was rejected by automatic approval review because this request did not explicitly authorize publishing and the remote ownership was not verified. The approval question received no answer. Do not retry publishing this branch without explicit user approval. The earlier October 2 publication authorization described above concerned the prior work and is not a resolution of this rejection. Keep configured human authorship and omit AI co-author/attribution trailers.

## Latest expanded arena — October 3, 2026

The user requested a larger map at TF2-KOTH-style scale with more vertical play, authorizing the map expansion while preserving existing movement. The expanded build is on local branch `feature/garden-koth-expansion`, based on the accepted playable `b59ec60` checkout. Current expansion checkout: `/Users/samjo/Documents/Codex/2026-10-03/for-the-apple-legends-i-wanna/work/apple-legends-expanded`. Launch it through `/Users/samjo/Documents/Codex/2026-10-03/for-the-apple-legends-i-wanna/outputs/Play Expanded Apple Legends.command`; the earlier launcher still points to the smaller build.

The courtyard is now 32 × 44 m (3.26 times the former area). Human furniture/robot size and accepted controller tuning are preserved. Ground routes, open underpasses, 1.65 m galleries and 3.30 m upper orchard terraces are joined by four ground ramps and four upper ramps, with interrupted sight screens and drop shortcuts. Widened protected docks and midfield islands introduce doglegs. The central point has shallow approach strips over its old raised lips, so players can walk onto it from any direction. Blender source, runtime GLB, floor collider, markers and seven review views are updated.

Native checks verify four complete capsule climbs across both levels, underpasses, safe upper-to-gallery-to-ground drops, four walking entries onto the hill and 90 sampled spawn sightlines. A scripted walking route from the cyan dock around the left screen/cover to the hill measured about 13.2 seconds of movement; this is one representative path, not a whole-map balance claim. Solid obstacle audit, floor seam traversal, planter blocking, jump/F1/Esc/settings and CS sensitivity persistence pass natively. Preserve this as engineering evidence, not user playtest acceptance. Team KOTH rules, advanced bot navigation, multiplayer, physical mouse calibration and frame-rate benchmarking remain deferred.

This expansion is local and unpublished. The earlier publication rejection remains unresolved; do not push without explicit approval. Human Git identity is unchanged and no AI co-author is added.

## Latest movement follow-up — October 3, 2026

The user requested slightly lower gravity while retaining falling weight/momentum, jumping back during a ledge fall, and Source-style air strafing. Player gravity is 13.2, down approximately 5.7% from 14. Jump launch stays 11, with the same finite held-jump lift and early release. Measured calibration tap/medium/full peaks are approximately 1.284/3.824/6.209 game units; the full peak was previously approximately 5.935. Ground walking/sprint speeds and accelerations are unchanged.

A player who walks off an edge retains one jump until landing, allowing Space to reverse descent even beyond a brief coyote window. A launch consumes it, so there is no second air jump after either a normal jump or recovery. Ground contact restores it; death, respawn and capture release clear it.

Air control now follows Source's directional acceleration principle rather than interpolating the whole horizontal velocity toward walking speed. It limits velocity projected onto the wish direction (cap 2.5), applies coefficient 8 × requested speed × frame time, and preserves perpendicular momentum. Hold A and smoothly turn left, or D and turn right, in the air to steer/build strafe speed. Releasing movement preserves carry; holding forward at takeoff speed does not keep accelerating. These are Apple Legends tuning values, not a claim of exact TF2/CS movement replication. No automatic hop, ground movement rewrite or total air-speed cap is added. Reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/gamemovement.cpp (AirAccelerate).

The new deterministic physics check passes for an actual ledge walk-off, a sustained fall, one-use recovery onto the original platform, landing reset, normal-jump repeat rejection, real airborne momentum/strafe gain, wish-direction cap and falling acceleration. Existing hybrid-sprint, variable-height jump, ceiling, lifecycle and four calibration-prop landing checks pass. Native expanded-arena checks are recorded in the milestone notes. No user playtest acceptance or network/performance claim is inferred.

## Small ledge traversal — October 3, 2026

The user requests automatically walking onto spawn pads and tiny ledges rather than jumping for minor height changes. The step allowance is 0.35 game units (~10.85 cm at current map scale). Grounded movement without a jump can raise the player onto a low static tread after full-body up/across/down sweeps, floor-angle validation and a check that the top is within the allowance. The capsule retains horizontal motion and receives no vertical jump impulse. Low ceilings, taller steps and airborne walls remain blocking. Gravity, unused ledge recovery jump, Source-style air acceleration, sprint and CS sensitivity are unchanged.

The fixture checks pass for 0.05/0.26/0.34-unit steps, a blocking 0.36-unit step, insufficient overhead clearance and no airborne step lift or jump reset. All six authored spawn pads are crossed without jumping; the fixture excludes the frozen bot's body occupying Amber spawn 1 to isolate terrain traversal. Existing variable-height jump/prop landing and ledge recovery/air-strafe checks pass. Native verification is recorded in the milestone notes. Saved locally on the existing expansion branch; publication remains restricted pending explicit approval.

## October 3 — miniature world scale

User requests a much smaller-feeling character in an abnormally large human garden campus, with Olympus as atmosphere inspiration. This explicitly supersedes the earlier fixed furniture scale. Robot height remains approximately 0.55 m, with unchanged camera, movement and sensitivity. Original benches are now 3× larger (4.46 m wide, seat mesh top 1.51 m, underside 1.19 m); two extra giant benches appear beside spawn. Added 2.25 m café tables and robot-sized cups, 6.6 m doors, taller planters/trees, 1.8× taller perimeter/pavilions, 2.1× skyline towers and original white garden arches reaching 19.5 m. All geometry is original; no commercial map or asset is copied.

The 32 × 44 m courtyard, ground floor, 1.65/3.30 m tiers, ramp geometry, hill apron and six spawn markers remain. Human scenery provides the scale cues without changing the accepted controller. Updated editable Blender source, solid runtime export, source previews and player-eye native screenshot. The expanded source is also copied to this task's outputs.

Verification: native expanded-map ramps, underpasses, tier drops, four walking hill entries and 90 sampled spawn sightlines pass; representative walking time remains 13.23 seconds. All 482 sampled authored obstacle faces block rays from both sides, with level paving and actual planter blocking. All six spawn pads pass without jumping. The new miniature-world fixture confirms oversized seat dimensions and actual grounded capsule passage beneath the solid bench. Native eye-level imagery was reviewed. Native jump/ramp movement, F1/Esc lifecycle, six-decimal CS input, Retina normalization and sensitivity persistence also pass. User feel acceptance, team balance and frame-rate benchmarking remain unverified. Keep local publication restrictions and deferred multiplayer/KOTH systems.

## October 3 — wall-visible weapon and clear ramp junctions

The user likes the miniature-world scale (local commit 12f2d45), then reports the gun disappearing at wall contact and blocked movement/jumping near an upper ramp. They explicitly request checking all blockers. Keep the accepted miniature art and current locomotion.

The first-person rifle now uses copied local materials with Godot's `use_z_clip_scale` and scale 0.1, keeping its screen size, lighting and internal depth while bringing rendered geometry inside the capsule clearance. Near plane is 0.01. Both original and imported rifle/hand meshes and muzzle flashes are configured; enemy/shared world materials retain ordinary depth. Camera-origin hitscan, wall occlusion, ADS/FOV, recoil, reload and gameplay collision remain. Native hip/ADS pixel comparisons at actual wall contact confirm the rifle stays visible; rifle combat/regression checks pass.

The four upper ramps previously started at x ±9.5 m and cut across the middle galleries. Their starts now sit at x ±11.3 m with landings at ±14.8 m: same 3.5 m run, slope and tier heights. Matching upper-deck notches and outer links avoid solid deck overlap; all middle-gallery walking lanes stay open. Small tree branches now share foliage's decorative collision policy to prevent hidden snags; basins, soil, base reveals and trunks remain solid. Source, runtime export and previews match.

Headless and native physics checks pass for six full-length gallery lanes, 40 full-height middle-gallery jumps, four upper-ramp jumps, connected high-tier walking routes and 20 full-height upper-terrace jumps, plus jumping over all six center-facing gallery guards. Fast mode uses 600 ticks/s and time scale 10 solely in this static-map fixture, retaining a 1/60 simulated delta; production remains unchanged. Native checks pass for all eight ramp connections, underpasses, safe tier drops, four hill entries and 90 sampled protected spawn sightlines; representative dock-to-hill movement stays 13.23 seconds. All 386 sampled solid obstacle faces block rays from both sides, and native movement/jump/F1/Esc/CS sensitivity controls pass. Walking beneath the giant bench also passes. All six spawn pads still support walking without a jump. These checks cover authored routes and sampled surfaces, not every possible player trajectory or a performance benchmark. Keep local publication restrictions.

## October 3 — playable offline KOTH authorization

The user explicitly requests contested capture, independent 3:00 ownership clocks, TF2-informed capture pacing, win/restart, objective-aware bot behavior, remaining lower-ledge fixes and repeated critical evaluation. They also request parallel GPT-6.1 Sol agents. This supersedes earlier KOTH and basic navigation deferrals for this offline slice. Multiplayer, API services and publication remain outside this change; preserve the accepted movement and miniature art.

Garden Circuit now uses KothManager (reusing DuelManager health/respawn wiring), pure KothRules and an observing KothHUD. Production tuning is 12-second single capture, 15-second initial lock, 180-second clocks and 3-second respawns. Grounded living feet in the 1.8 m ring count. Both teams freeze capture and clocks. Empty owned hills keep counting; recapture preserves the prior clock. Zero with an enemy on the hill enters overtime; clear it to win. Gameplay freezes after victory/defeat and Enter resets. Esc pauses simulation; F1 test-bot preference survives restart. Calibration/canyon retain first-to-five duel behavior.

Lower gallery edges now have six visible flush structural skirts and mirrored 2.4 m portals. Ordinary approaches no longer enter the low deck underside before jumping; unguarded spans permit held-jump mounting. Taller guard spans retain intentional collision and can be approached via adjacent open spans. The bot uses original mirrored ground waypoints, capsule stepping and local obstacle steering, holds the hill instead of chasing, and fights visible enemies. Widening the spawn lanes to x ±7.15 m resolved a bench-leg snag found at 120 Hz.

Validation after KOTH integration: rules boundaries and 60 randomized delta partitions; grounded capture/contest, airborne/dead exclusion, pause, timed respawns, winner freeze, Enter/reset, preserved F1 and 24 repeated rounds; production clock scenario with 120 seconds contested and two recaptures; three actual full-clock bot wins (623.75 seconds combined simulation) with death/respawn clock retention. Objective routes passed twice at 60/120 Hz (24 capsule routes, 15.57–17.20 seconds arrival). Lower/gallery checks, 392 sampled obstacle faces, six spawn pads, giant bench passage, wall-visible hip/ADS rifle, rifle combat, air movement and small-step regressions pass. Native Metal HUD screenshots were reviewed and overlap corrected. Final native expanded-map ramps, underpasses, separate upper/gallery safe drops, four hill entries, 90 spawn sightlines and winner-menu/restart checks pass. Simulated dock-to-hill walking time remains 13.23 seconds. Tests cover authored routes and explicit scenarios, not every player trajectory, human balance or frame-rate performance.

## October 3 — accepted KOTH playtest, project entry and next steps

The user confirms the updated game works and they tested it after correcting Godot's project entry. Treat the expanded miniature Garden Circuit, accepted movement/gunplay, lower-gallery fixes and playable offline KOTH as the current user-tested baseline. This does not establish multiplayer readiness, human team balance or a performance benchmark.

Godot Project Manager's existing Run entry uses `/Users/samjo/Apple Legends`. That original checkout was locally fast-forwarded from c9049a8 to cbfc153; its main scene now loads Garden Circuit KOTH. Asset import and the KOTH integration suite pass from that exact directory. Keep this registered project synchronized with accepted changes so Run launches the current game. The task checkout remains `work/apple-legends-expanded`; editor/play launchers are in this task's outputs.

Recorded next-step recommendation: tune current combat feedback and match pacing; implement team-aware target selection, friendly-fire rules, separate spawns, alternate objective routes and teammate avoidance; test offline 2v2 (player plus one ally versus two enemy bots); then private two-human play with early browser compatibility checks; finally add one contrasting weapon before a larger arsenal or 3v3. Proposed next milestone is a fun, readable offline 2v2 KOTH mode. This is a saved roadmap, not authorization to start those features yet.

The user now explicitly requests committing and pushing all new game changes to GitHub and saving this discussion to memory. This fresh authorization supersedes the earlier unresolved publication restriction for the current changes. Use the configured human Git identity, preserve local files and normal remote history, and exclude generated assistant caches from source control.

## October 3 — combat readability and objective audio

User requests a slower TTK, visible enemy health, more noticeable right-click ADS zoom, capture audio and map-wide late-clock urgency, with repeated testing/iteration. The holographic red enemy-highlight sight is explicitly a future idea. This pass keeps the accepted map/controller, one opponent and offline KOTH; team bots/new weapons/networking remain separate future milestones.

Shared rifle tuning is 22 damage / 0.22-second cadence: five hits against 100 health, theoretical 0.88 seconds from first to lethal hit (previously three / 0.36). ADS blends from 80 to 58 degrees vertical FOV; calibration F2 comparison uses a 22-degree reduction clamped at 40. EnemyHealthHUD observes the actual bot health and anchors a red bar/numeric readout above its head; physics line-of-sight hides it through walls, behind/off camera, on enemy death and while the viewer is dead. Existing damage authority, recoil, movement and reload behavior remain.

ObjectiveAudio observes retained team clock snapshots using non-spatial AudioStreamPlayers. Original rising/falling team capture chimes and portable OS-synthesized placeholder voice clips announce captures, each team's 30/10-second warning, final five seconds and overtime. Contests freeze countdown, use an edge-triggered chime with a four-second cooldown and do not duplicate warnings; recapture preserves per-team warning history. Fresh urgent speech replaces stale speech, winning stops countdown voice, and restarting clears sounds/history/captions. Runtime requires no OS speech engine or online service. tools/build_objective_audio.py regenerates the committed WAVs on macOS with Samantha.

Validation: native Metal actual right-click ADS/release, full and damaged enemy HUD in hip/ADS, five real hits, wall occlusion, dead viewer/enemy and respawn; 16 repeated audio rounds split between teams with 30/10/final-five/contest/overtime, warning history through recaptures and reset captions. KOTH rules (60 randomized timelines), integrated 24 repeated rounds with full-clock recaptures, rifle/reload/occlusion, damage direction and air movement regressions pass. Three actual full-clock bot matches pass (623.73 simulated seconds, accelerated test cadence), including a death/respawn and alternating spawn slots. Native wall-contact weapon visibility passes at the new ADS FOV; native Garden settings/movement/jump/F1/Esc/CS persistence pass. WAV durations/levels checked for nonempty audio without clipping. Native screenshots reviewed; fixed stale capture captions surviving Enter restart during iteration. Headless runs emit the known macOS certificate warning and some fixture shutdown resource warnings; native checks have no gameplay errors. Automated scenarios and screenshots do not establish subjective fun, human balance or a performance benchmark. User feel/audio preference remains to be playtested.

Changes are local for this pass; no new GitHub publication is requested. Keep Godot's registered /Users/samjo/Apple Legends checkout synchronized after verification.

## October 3 — saved session handoff

The user requests saving everything to memory and will continue later. Do not start additional gameplay features or schedule follow-ups. The combat-readability pass is implemented and automatically verified, but this message does not confirm a new human playtest or subjective acceptance of the changed rifle/announcer.

Current source branch: feature/combat-readability. Gameplay commit: 259085c; Godot test-script UID follow-up: 2fcecae. Both this checkout and the registered Godot project at /Users/samjo/Apple Legends were synchronized to 2fcecae before this memory update. These changes are local and have not been pushed to GitHub.

Session deliverables: /Users/samjo/Documents/Codex/2026-10-03/focus-on-core-gameplay-first-then-2/outputs/Play Apple Legends.command (launches the feature checkout), Combat Readability Pass.md, hip-health.png and ads-health.png. Godot's usual Run entry uses /Users/samjo/Apple Legends. The working directory of this chat contains deliverables, while game source remains in the expansion task's work/apple-legends-expanded checkout.

Resume with the user's live playtest of five-hit rifle pacing, enemy-health readability, 80-to-58-degree ADS and synthesized global capture/countdown volume. Adjust those settings from actual feedback. Then the proposed roadmap remains team-aware bot foundations and offline 2v2, followed by private human/browser networking feasibility and one contrasting weapon. The holographic red enemy-highlight ADS concept remains deferred. These are saved follow-up ideas, not authorization to implement them automatically.
