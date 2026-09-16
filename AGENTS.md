# Project rules

Build an original, lightweight Apple Silicon FPS incrementally. Baseline: M3 / 18 GB RAM; second test machine: M5 / 24 GB. Theme, art direction, and signature mechanics are undecided. Do not copy commercial game content.

## Scope and workflow
- Current milestone: M0; consult docs/milestones.md before changing scope.
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
- No weapons, BR systems, matchmaking, progression, polished art, or forced theme in M0/M1.
