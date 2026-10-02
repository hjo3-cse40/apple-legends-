# Project rules

Build an original, lightweight Apple Silicon FPS incrementally. Baseline: M3 / 18 GB RAM; second test machine: M5 / 24 GB. The working title is **Apple Legends**; an apple-inspired identity is being explored, while final characters, art direction, and signature mechanics remain undecided. Do not copy commercial game content, layouts, names, characters, or assets.

## Scope and workflow
- Current milestone: M3 offline duel vertical slice, explicitly authorized after M2 gunplay. Consult docs/milestones.md before changing scope.
- 2026-10-02: the user explicitly authorized the next-step Blender art calibration bay. Image 1 is the chosen visual direction, image 2 supporting personality. Keep the working duel/controller and original canyon baseline; this authorization is limited to the calibration slice, not the full garden arena, new classes/weapons, or multiplayer.
- 2026-10-02 follow-up: preserve current robot and bench sizes; enlarge surrounding scenery/collision to sell miniature scale. Native moving/sprinting fire and V keyboard fallback are authorized. Sprint toggle is explicitly deferred. Record crouch, more fluid movement, and arms-back miniature running animation as later follow-ups; final current request is scenery scale and laptop input.
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
- Preserve accepted M1 movement. Deferred user feedback: toggle sprint, slightly faster sprint, and lower mouse sensitivity; do not change these until requested.
