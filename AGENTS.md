# Project rules

Build an original, lightweight Apple Silicon FPS incrementally. Baseline: M3 / 18 GB RAM; second test machine: M5 / 24 GB. The working title is **Apple Legends**; an apple-inspired identity is being explored, while final characters, art direction, and signature mechanics remain undecided. Do not copy commercial game content, layouts, names, characters, or assets.

## Scope and workflow
- Current milestone: M3 offline duel vertical slice, explicitly authorized after M2 gunplay. Consult docs/milestones.md before changing scope.
- 2026-10-02: the user explicitly authorized the next-step Blender art calibration bay. Image 1 is the chosen visual direction, image 2 supporting personality. Keep the working duel/controller and original canyon baseline; this authorization is limited to the calibration slice, not the full garden arena, new classes/weapons, or multiplayer.
- 2026-10-02 follow-up: preserve current robot and bench sizes; enlarge surrounding scenery/collision to sell miniature scale. Native moving/sprinting fire and V keyboard fallback are authorized. Sprint toggle was deferred at that stage; the later authorization below supersedes that. Record crouch, more fluid movement, and arms-back miniature running animation as later follow-ups; final current request is scenery scale and laptop input.
- 2026-10-02 locomotion follow-up: user now authorizes hybrid Shift sprint (tap toggle, long hold momentary) and lighter variable-height Space jumps that reach existing prop platforms. Keep robot/environment sizes fixed. Crouch, running animation, and mouse sensitivity remain deferred.
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
- Preserve accepted movement except the explicitly authorized hybrid sprint and lighter variable-height jump follow-up. Further speed tuning and lower mouse sensitivity remain deferred.

## Accepted baseline — user playtest, 2026-10-02

The user says the current result looks good and explicitly requested saving it to memory after testing the hybrid sprint/variable jump milestone (commit 6e80c77). Treat the current calibration visuals, oversized surroundings with unchanged robots/benches, spatial robot audio, moving fire/V fallback, hybrid Shift sprint, and light variable-height Space jumping as the accepted baseline. Preserve this feel unless the user requests further tuning. This is general playtest acceptance, not confirmation of every hardware-specific trackpad behavior or a performance benchmark.

Current movement tuning: walk 7, sprint 10, gravity 14, jump launch 11, air acceleration 8; Shift tap threshold 0.22 seconds; held jump lift window 0.35 seconds with gravity scale 0.55 and a smoothly eased early-release cut. Crouch, arms-back running animation, more content, and multiplayer remain future work requiring a new request.

## Blender arena and asset organization — 2026-10-02

The user explicitly authorized building a larger 3v3 KOTH map in Blender, emphasizing roughly leg-height robots in human-sized surroundings, for Blender review. The user then authorized organizing robots, guns, enemies, and other Blender assets separately and moving everything into this repo. This supersedes the earlier calibration-only limitation for Blender arena art, without authorizing an automatic replacement of the running Godot scene or implementation of team/KOTH/networking systems.

Source index: `tools/blender_source/README.md`. Map: `tools/blender_source/maps/garden_circuit/GardenCircuit.blend`. Player/enemy robots, rifle/hands, and props have separate editable files beneath `characters/`, `weapons/`, and `props/`. Map Outliner separates Map, Characters (player/enemy with body/held weapons), Gameplay markers, and Review setup. The consolidated visual export is `art/maps/garden_circuit/GardenCircuit.glb`. Existing calibration GLBs and the accepted controller remain unchanged. The original workshop remains the historical shared source. Separate robot/enemy files are presentation variants, not new gameplay classes. Map is in physical meters; original asset coordinates use 0.31 metric display scale. Sources are excluded from Godot via `.gdignore`. The user subsequently authorized committing and pushing this work; see the publication preference below.

## Future direction and publication preference — 2026-10-02

Persistent product memory is `docs/product-direction.md`. The user prefers browser-link sharing with their girlfriend/friends, eventually private two-player rooms expanding to 3v3 KOTH. Plan browser-compatible rendering and networking before committing to a native-only multiplayer design. The optional Jev (spoken “Jeff”) idea is remote tactical goal selection over competent local bots, with compact perceived state, cooldowns, stale-response rejection, and local fallback. Keep API credentials on a backend and never commit them. $5 credit is user-reported; cost figures in the memory document are conditional calculations, not measured gameplay usage. These preferences are not an instruction to implement multiplayer, deploy a website, or spend API credit immediately.

The user now explicitly requests committing all new repository changes and pushing to GitHub. This supersedes the earlier uncommitted/no-push preference for the current work. Use the configured human Git identity. Do not add Codex/AI attribution or AI co-author trailers to commit messages.

## Garden Circuit runtime authorization — 2026-10-02

The user now explicitly authorizes using the existing Garden Circuit Blender map in the running game, retaining the test bot and F1 freeze, adding Esc settings with saved sensitivity and reviewing menu variants on a new branch. This supersedes earlier runtime-map and sensitivity deferrals. Preserve accepted locomotion and original calibration scene. Team/KOTH rules, multiplayer and advanced bot navigation remain deferred.
