## Latest Laya integration — October 6, 2026

User explicitly authorized installing Laya and implementing/test-driving bot decisions. Build0.4.4/apple-legends-lan-5 adds host-only asynchronous Local/Shadow/Enabled controls, bounded perceived-state tactical candidates, lifecycle/freshness/geometry guards and offline local fallback. Python3.13.4/laya0.3.28 is isolated in ~/laya/.venv, pinned English convaiinnovations/laya revision7b928d828b7b0e022f929d9bd2e44165aa270148; ~/laya/bot_worker.py is the standalone game adapter. Exported apps contain neither Python nor model weights; joining Macs run no inference. See docs/laya-bot-planner.md and delivered Laya Setup and Controls.md/Laya Bot Evaluation.md.

Local tactics remain default. Stock model showed no convincing overall improvement; repeated same-state option reversal revealed positional bias. Final wrapper canonicalizes observations/candidates and averages two opposite option-slot passes using unchanged weights. Compare final Enabled with same-code Local separately from stock results; no model training, human-parity claim or paid inference. Player movement/network mechanics/HP/damage/map preserved. A neutral obstacle replay reaches the hill in~2.6s and does not reproduce a20s live stall; no speculative movement patch. Three authorizedGPT-6.1 agents reused; noAstra/6Sol/Jevcredits/push. Exact evaluation results and hardware limits belong in the delivered report. Preserve source-freeze data for each test block.

## Latest bot follow-up — October 5, 2026

User requested deeper bot testing plus local decision-model options. Build0.4.3/lan-4 adds two verified hill ground entries after the protected spawn exit, purposeful combat during transit, persistent verified reload cover, slower committed maneuvers and waypoint-progress recovery. Player movement and networking mechanics are preserved. Read docs/local-bot-intelligence-options.md for Laya, FunctionGemma, Qwen/MLX, learned policies and behavior tooling; no model installed, paid calls or new runtime. Full test evidence is recorded in delivered Bot Playtest Results.md. Three authorizedGPT-6.1 agents handled implementation, independent live-match evaluation and safety review; no Astra/6Sol. Local commits only, synchronize/import the normal Godot project after changes as below.

## Latest implementation handoff — October 5, 2026

User’s real1v1/same-team3v3 playtest exposed joining jitter, respawn mismatch and weak bots. Authorized three6.1 agents implemented0.4.2/lan-3 fixes, bot difficulty/sprint/safe hops, louder gunfire and saved dual keyboard/mouse bindings withSpace+wheelDown jump. Existing movement tuning preserved. Read current docs/lan-session-handoff.md plus docs/movement-bots-modes.md and delivered verification notes. Astra/6Sol require explicit user approval and were not used. No new game modes/model services or GitHub push implemented. Real partner retest still needed.

## Latest handoff — October 5, 2026

User confirmed real playtesting with girlfriend over home Wi-Fi works. Current build0.4.1/apple-legends-lan-2; normal project /Users/samjo/Apple Legends is synchronized and imported. Read docs/lan-session-handoff.md for complete current state, accepted visual direction, project/build paths, joining guide, version convention, tests and import requirement. This supersedes older notes that two-device LAN remains unverified. Exact team composition, session length and AirFPS were not provided. User is saving for another chat; no further work authorized by this save request.

# Project rules

Build an original, lightweight Apple Silicon FPS incrementally. Baseline: M3 / 18 GB RAM; second test machine: M5 / 24 GB. The working title is **Apple Legends**; an apple-inspired identity is being explored, while final characters, art direction, and signature mechanics remain undecided. Do not copy commercial game content, layouts, names, characters, or assets.

## Scope and workflow
- Current milestone: M3 offline duel vertical slice, explicitly authorized after M2 gunplay. Consult docs/milestones.md before changing scope.
- 2026-10-02: the user explicitly authorized the next-step Blender art calibration bay. Image 1 is the chosen visual direction, image 2 supporting personality. Keep the working duel/controller and original canyon baseline; this authorization is limited to the calibration slice, not the full garden arena, new classes/weapons, or multiplayer.
- 2026-10-02 follow-up: preserve current robot and bench sizes; enlarge surrounding scenery/collision to sell miniature scale. Native moving/sprinting fire and V keyboard fallback are authorized. Sprint toggle was deferred at that stage; the later authorization below supersedes that. Record crouch, more fluid movement, and arms-back miniature running animation as later follow-ups; final current request is scenery scale and laptop input.
- 2026-10-02 locomotion follow-up: user now authorizes hybrid Shift sprint (tap toggle, long hold momentary) and lighter variable-height Space jumps that reach existing prop platforms. Keep robot/environment sizes fixed. Crouch and running animation remain deferred; later Garden Circuit authorization below supersedes the sensitivity deferral.
- MAKE IT WORK → MAKE IT FEEL GOOD → NETWORK IT → PROFILE/OPTIMIZE → ADD CONTENT.
- Do not skip milestones or implement later systems without an explicit request.
- Inspect existing code and Git state before editing. Preserve user changes.
- Break large tasks into small steps; implement and test the highest-risk part first.
- Explain significant architecture choices and tradeoffs before major commitments.
- No silent broad rewrites. Preserve working behavior and checkpoint before significant refactors.
- Make small, logical commits of working changes. Never fabricate test results or Git identity.
- Maintain concise README, architecture notes, and milestone status, including unverified checks.

## Implementation
- Godot 4.7.2 standard, GDScript, static typing where practical; upgrade deliberately.
- Prefer engine features, composition, focused scripts, and descriptive names.
- Avoid speculative frameworks, deep inheritance, unnecessary plugins, and dependencies.
- Keep scenes and scripts together by feature; add folders only when needed.
- Keep gameplay separate from UI. UI observes gameplay state.
- Expose tuning values; use Resources when shared configuration warrants them.
- Run movement simulation in _physics_process(delta); handle mouse input separately.
- Briefly explain new Godot concepts and their purpose so the user learns the architecture.

## Movement and networking
- M1: responsive aiming, predictable ground acceleration/braking, jump, sprint, modest air control, stable collisions, configurable sensitivity, and debug readouts.
- Defer crouch unless requested or clearly needed. No wall running, sliding, grappling, or bunny-hop systems yet.
- Keep input sampling distinguishable from simulation without building a networking framework now.
- Future server owns damage, health, inventory, and authoritative state. Client messages express intent, never trusted outcomes.
- Prediction/reconciliation, remote interpolation, and lag compensation require later explicit design and tests. Do not assume deterministic cross-machine physics.

## Verification and performance
- Diagnose root causes before changes; use logs, debug views, and profiling rather than random edits.
- Verify relevant scene startup, behavior, and regressions; document manual checks when automation is unsuitable.
- Native ARM64 and stable frame pacing matter. 1080p / 120+ FPS on M3 is aspirational, not an M0/M1 gate.
- Avoid obvious waste, then optimize from measured evidence. Keep presentation and simulation cadence separate.
- M2 scope: one semi-auto rifle, ADS, recoil/feedback, ammo/reload, and resetting targets. No multiplayer, BR systems, progression, or polished character art.
- M3 scope: reusable health, one simple offline bot, death/respawn, first-to-five scoring, and procedural weapon feedback. Keep networking, progression, advanced AI, and polished character art deferred.
- Preserve accepted movement except the explicitly authorized hybrid sprint and lighter variable-height jump follow-up. Further movement-speed tuning remains deferred; the later authorized CS sensitivity controls are implemented.

## Accepted baseline — user playtest, 2026-10-02

The user says the current result looks good and explicitly requested saving it to memory after testing the hybrid sprint/variable jump milestone (commit 6e80c77). Treat the current calibration visuals, oversized surroundings with unchanged robots/benches, spatial robot audio, moving fire/V fallback, hybrid Shift sprint, and light variable-height Space jumping as the accepted baseline. Preserve this feel unless the user requests further tuning. This is general playtest acceptance, not confirmation of every hardware-specific trackpad behavior or a performance benchmark.

Historical accepted movement tuning (superseded by the October 3 air-movement follow-up below): walk 7, sprint 10, gravity 14, jump launch 11, air acceleration 8; Shift tap threshold 0.22 seconds; held jump lift window 0.35 seconds with gravity scale 0.55 and a smoothly eased early-release cut. Crouch, arms-back running animation, more content, and multiplayer remain future work requiring a new request.

## Blender arena and asset organization — 2026-10-02

The user explicitly authorized building a larger 3v3 KOTH map in Blender, emphasizing roughly leg-height robots in human-sized surroundings, for Blender review. The user then authorized organizing robots, guns, enemies, and other Blender assets separately and moving everything into this repo. This supersedes the earlier calibration-only limitation for Blender arena art, without authorizing an automatic replacement of the running Godot scene or implementation of team/KOTH/networking systems.

Source index: `tools/blender_source/README.md`. Map: `tools/blender_source/maps/garden_circuit/GardenCircuit.blend`. Player/enemy robots, rifle/hands, and props have separate editable files beneath `characters/`, `weapons/`, and `props/`. Map Outliner separates Map, Characters (player/enemy with body/held weapons), Gameplay markers, and Review setup. The consolidated visual export is `art/maps/garden_circuit/GardenCircuit.glb`. Existing calibration GLBs and the accepted controller remain unchanged. The original workshop remains the historical shared source. Separate robot/enemy files are presentation variants, not new gameplay classes. Map is in physical meters; original asset coordinates use 0.31 metric display scale. Sources are excluded from Godot via `.gdignore`. The user subsequently authorized committing and pushing this work; see the publication preference below.

## Future direction and publication preference — 2026-10-02

Persistent product memory is `docs/product-direction.md`. The user prefers browser-link sharing with their girlfriend/friends, eventually private two-player rooms expanding to 3v3 KOTH. Plan browser-compatible rendering and networking before committing to a native-only multiplayer design. The optional Jev (spoken “Jeff”) idea is remote tactical goal selection over competent local bots, with compact perceived state, cooldowns, stale-response rejection, and local fallback. Keep API credentials on a backend and never commit them. $5 credit is user-reported; cost figures in the memory document are conditional calculations, not measured gameplay usage. These preferences are not an instruction to implement multiplayer, deploy a website, or spend API credit immediately.

The user now explicitly requests committing all new repository changes and pushing to GitHub. This supersedes the earlier uncommitted/no-push preference for the current work. Use the configured human Git identity. Do not add Codex/AI attribution or AI co-author trailers to commit messages.

## Garden Circuit runtime authorization — 2026-10-02

The user now explicitly authorizes using the existing Garden Circuit Blender map in the running game, retaining the test bot and F1 freeze, adding Esc settings with saved sensitivity and reviewing menu variants on a new branch. This supersedes earlier runtime-map and sensitivity deferrals. Preserve accepted locomotion and original calibration scene. Team/KOTH rules, multiplayer and advanced bot navigation remain deferred.

## Current runtime memory — October 3, 2026

See `docs/product-direction.md` for the latest persisted state, checkout/launcher paths and validation limits. Current feature branch is `feature/garden-movement-settings`, with runtime integration `16de62f` and stability/collision/CS sensitivity `c4591ea`. The user acknowledged the reported fixes and requested updating memory; do not treat that as proof of a full hardware/performance playtest. Preserve the integrated arena, F1 bot freeze, Esc pause/resume, selected right-side settings design, accepted locomotion and saved CS hipfire units. Ground layers are separated with a continuous floor collider; solid planters/trunks are included and both-sided collision is audited. Physical mouse cm/360 and scoped/custom-CS behavior remain unverified.

The attempted push of this feature branch was rejected by automatic approval review, and the user has not answered the publication question. Keep this feature work local and do not retry pushing without explicit approval; the earlier publication preference does not resolve that rejection.

## Expanded map authorization and current checkout — October 3, 2026

The user now requests expanding Garden Circuit to TF2-KOTH-style scale with more vertical space. This authorizes the larger map geometry/runtime update. Current expansion branch is `feature/garden-koth-expansion` in `/Users/samjo/Documents/Codex/2026-10-03/for-the-apple-legends-i-wanna/work/apple-legends-expanded`. Use the new `outputs/Play Expanded Apple Legends.command` launcher from that task; the previous launcher still runs the compact map. Preserve the 32 × 44 m footprint, tiers at 1.65/3.30 m, eight connecting ramps, open underpasses, safe tier drops, spawn shielding and shallow walk-in hill apron, while retaining accepted robot/furniture scale, locomotion, F1 freeze and Esc CS controls. See `docs/product-direction.md` and current map review notes for native test evidence and limits. No new team/KOTH logic, advanced navigation or multiplayer was authorized. Keep local; the publication restriction above remains.

## Ledge recovery and air movement authorization — October 3, 2026

The user requests slightly lighter gravity, a jump while falling off a ledge to recover, and Source-style air strafing. Player gravity is now 13.2 (from 14); normal ground speed/acceleration, jump launch, variable-height hold, sprint and CS sensitivity remain. Walking off a ledge leaves one recovery jump available throughout the fall until landing; any jump consumes that availability. This is not a timed coyote window or an extra jump after a normal launch. Death, respawn and input capture release clear recovery state. Air movement uses directional velocity projection with a 2.5-unit wish-speed cap and acceleration coefficient 8; A/D plus mouse turning steers and can build speed while preserving momentum. No explicit total airborne speed cap or automatic bunny hopping is added. See `tests/air_movement_smoke.gd` and `docs/product-direction.md` for verification. This explicitly supersedes the historical movement-tuning restriction for these changes; keep the other controls and map geometry.

## Small ledge walking authorization — October 3, 2026

The user requests walking over low spawn pads and tiny height changes without jumping. The player now has an exported step height of 0.35 game units (~10.85 cm at the map's 0.31 m/unit scale). While grounded and not jumping, a blocked horizontal move may step upward after full-capsule up/across/down clearance tests and a ray check of the tread just inside the contact. Require static, walkable support within the height allowance; ceilings and taller walls remain blocking. No vertical jump impulse or airborne mantle is added. Preserve lighter gravity, ledge recovery, Source-style air strafing, sprint and CS controls. Tests cover near-limit square steps, rounded authored spawn pads, ceiling/tall-obstacle blocking and airborne safety.

## October 3 — miniature world scale

User requests a much smaller-feeling character in an abnormally large human garden campus, with Olympus as atmosphere inspiration. This explicitly supersedes the earlier fixed furniture scale. Robot height remains approximately 0.55 m, with unchanged camera, movement and sensitivity. Original benches are now 3× larger (4.46 m wide, seat mesh top 1.51 m, underside 1.19 m); two extra giant benches appear beside spawn. Added 2.25 m café tables and robot-sized cups, 6.6 m doors, taller planters/trees, 1.8× taller perimeter/pavilions, 2.1× skyline towers and original white garden arches reaching 19.5 m. All geometry is original; no commercial map or asset is copied.

The 32 × 44 m courtyard, ground floor, 1.65/3.30 m tiers, ramp geometry, hill apron and six spawn markers remain. Human scenery provides the scale cues without changing the accepted controller. Updated editable Blender source, solid runtime export, source previews and player-eye native screenshot. The expanded source is also copied to this task's outputs.

Verification: native expanded-map ramps, underpasses, tier drops, four walking hill entries and 90 sampled spawn sightlines pass; representative walking time remains 13.23 seconds. All 482 sampled authored obstacle faces block rays from both sides, with level paving and actual planter blocking. All six spawn pads pass without jumping. The new miniature-world fixture confirms oversized seat dimensions and actual grounded capsule passage beneath the solid bench. Native eye-level imagery was reviewed. User feel acceptance, team balance and frame-rate benchmarking remain unverified. Keep local publication restrictions and deferred multiplayer/KOTH systems.

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

## October 3 — girlfriend LAN multiplayer and distribution plan

User wants simultaneous play with girlfriend, private selectable lobbies, player/team slots and bot fill for 3v3 KOTH, eventually more chaotic TF2-inspired 5v5. Girlfriend has an Apple Silicon MacBook Air, reported as M4 or M5 with approximately 12 or 14 GB RAM; exact specifications are unconfirmed. They live together and can play on the same Wi-Fi.

Discussion recommendation: prioritize the existing native Godot game with a shareable Mac .app and LAN Host/Join, rather than making browser support the next dependency. This refines the earlier browser-link preference given both players have Macs and share a network; browser support remains a possible later option. Exported game includes the engine: girlfriend does not need Godot, Xcode, or development tools. Initial joining can use host LAN address; automatic LAN lobby discovery can follow. Ordinary home LAN play should not need a rented server or router port forwarding, subject to local network/firewall permissions. Actual Air performance remains unmeasured; early non-notarized builds may require a one-time macOS launch approval.

Proposed sequence: synchronize a two-human KOTH match first (movement, shots, damage, deaths, respawns, objective clocks), then private lobby with team selection, ready status, host Start, bot add/remove and fill-empty-slots option. Host/server owns bots, damage, health, scoring and match timing. First complete target is 3v3: two humans plus one bot against three bots, or one human and two bots per side. Make team size configurable instead of hardcoding six participants; tune and profile 5v5 later. Team-aware bots, role/weapon variety, alternate routes and regrouping contribute to chaos alongside player count. Browser multiplayer requires a browser-supported transport such as WebRTC/WebSocket rather than native ENet, so assess compatibility if browser becomes required.

Distribution recommendation: export matching versioned .app builds and AirDrop a ZIP; girlfriend replaces her old copy after updates. Add a join-time build/protocol version check with a clear update-required message to prevent mismatched builds. Automatic updating is deferred until useful for more testers. Browser hosting would ease distribution but still needs handling of stale clients.

The user now requests saving this discussion and will continue later. No networking, lobby, export, updater, deployment, or follow-up automation was implemented or authorized to start by this save request. Resume by revisiting the private LAN 3v3 milestone when the user asks to proceed; preserve existing combat/map changes.

## October 4 — authorized native LAN 3v3 playtest

User explicitly authorized implementing the lobby, flexible human/bot rosters up to 3v3, tactical AI, developer settings, agents/review, and a shareable playable Mac build. This supersedes the prior saved-only plan. Work is on feature/lan-lobby-team-bots in the expanded checkout. F5 now launches lan_main.tscn; original offline main.tscn is retained. Native LAN only; no web, 5v5, public matchmaking or auto-updater added.

LanSession owns ENet27777, version gate, team slots/ready and host mutation. TeamMatchManager owns damage, bots, respawn/KOTH and snapshots. Human movement is local with host collision/rate checks; this is not fully server-simulated movement or lag compensation. Bots react, aim imperfectly, strafe, reload, retreat to reachable cover and spread objective positions using authored ground lanes. Upper-tier bot routing and TF2 parity remain unclaimed. Esc opens local settings without pausing shared gameplay; host developer controls restart/freeze/disable and lobby roster edits.

Validation passed: two-process 2v2 and3v3 actual LAN matches including client shots/health/hit feedback, friendly immunity, death/respawn/restart, lobby/disconnect/reconnect; version/fullroom gates; bot1v1/2v2/3v3/team/cover/routes; team lifecycle including disabledbot respawn/restart; UI/settings; rifle/airmovement/KOTH. Native map expansion walking and392 exact obstacle ray checks pass. Headless cannot capture mouse, so walking fixtures require native rendering. Hill movement collision now uses smooth convex apron; exact dense artwork remains on query layer2 for bullet rays, with tall obstacle geometry retained on layer1. Native six-character 30-second fixed-camera M3Pro test measured119.1 meanFPS/minsample117, not an Air benchmark. Real two-device Wi-Fi, subjective difficulty and longer sessions remain untested.

Godot4.7.2 official macOS template is installed. Universal2 ad-hoc app/version0.4.0 exported to current chat outputs/Apple Legends.zip; partner needs only same exported app, not editor. See docs/lan-playtest.md. Future updates require replacing both copies and bumping LanSession build/protocol plus export versions. Current delivery is local; no GitHub push requested. Preserve movement/gun tuning and existing white garden art.

Final release verification: exported Universal 2 app signature passed; native packaged UI successfully created a party, filled all six slots, readied, launched Garden Circuit, opened developer tools and returned the party to the lobby. Release templates do not support external --script fixtures, so the packaged test used the real UI.

## October 4 — exact lobby reference refinement

User supplied the generated campus lobby image and explicitly requested matching it. Replaced plain backdrop and small live MiniBot preview with a clean illustrated garden plate, matching transparent porcelain portrait, translucent roster cards, correct live counts/ready/host tags, map card and bright cyan match button. 1280x720 design scales to fit and keeps connection controls before joining. Native renders at720p/1080p inspected. Fill switch adds optional bots on start; individual controls retained. Bot gameplay and geometry unchanged. Version0.4.1/apple-legends-lan-2: replace both apps, updated shareableZIP. Built-in imagegen assets/prompts recorded in docs/lobby-reference-assets.md. Lobby behavior + fill-on-start and two-process version tests passed.

## October 4 — original Godot project import repair

User ran /Users/samjo/Apple Legends and saw latest controls but missing backdrop/portrait. Source assets and .import metadata had been fast-forwarded correctly, but ignored .godot/imported texture caches were absent there. Ran Godot4.7.2 --headless --editor --path original-project --import to regenerate all4 lobby texture/icon imports. After every future source synchronization, run this import command in the actual original checkout BEFORE validating its normal Run; do not assume imports from the feature checkout transfer viaGit. Keep F5 main_scene=lan_main.tscn. Added usable background/portrait/toggle texture checks to existing lobby fixture. This repair only regenerates editor caches and adds validation/docs; game build remains0.4.1 and partnerZIP is unaffected.
