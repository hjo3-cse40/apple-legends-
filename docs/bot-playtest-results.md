# Apple Legends 0.4.3 — bot playtest results

## What changed

The bots already sprinted, jumped and fought near the hill, but shared one approach and mostly followed waypoints while shooting during travel. They now use two capsule-verified ground hill entries after the common protected spawn exit. Pressure uses the side entry, anchor the direct entry, and support can vary between lives. The route remains committed during a life.

Bots can maneuver while fighting on the approach, manage engagement distance, space from teammates, and use verified nearby cover while reloading or retreating. An already selected cover destination survives losing sight of the opponent. Choices last longer instead of twitching between two strafe clocks. Anchors prioritize an unowned or contested hill.

An early revision made some bots circle outside the hill. The tests caught it and that revision was rejected. Final transit maneuvers are perpendicular to the actual waypoint direction so they cannot cancel the intended advance. Close to gateways bots finish the route; bounded engagement/advance periods and waypoint-distance tracking recover loss of progress. Existing player movement, bot health/damage and networking mechanics are preserved.

## Actual match comparison

Six production host bots on the production Garden Circuit map, two fixed-seed Normal rounds before and after, with real shots, damage, magazines, reloads, deaths, respawns and KOTH clocks. Each round had a 600 simulated-second cap and all four finished with a winner. A test-only spectator replaces the host human seat; gameplay parameters are not changed. Headless runs accelerate wall time while retaining 1/60-second physics steps. Seeds are 173 and 1182, plus fixed per-bot offsets. Source hashes are recorded in the accompanying JSON.

| Run | Match duration | Captures | Contested time | All six first hill arrivals | Longest sampled waypoint dwell |
|---|---:|---:|---:|---:|---:|
| Before, seed 173 | 382.6s | 5 | 91.1s | 17.9–30.6s | 34s |
| Before, seed 1182 | 352.9s | 5 | 108.2s | 14.5–40.2s | 35s |
| After, seed 173 | 285.7s | 5 | 43.7s | 11.4–22.6s | 13s |
| After, seed 1182 | 333.0s | 7 | 51.6s | 11.6–20.9s | 27s |

The updated bots performed actual transit engagement/flank maneuvers for about 126 and 137 aggregate bot-seconds in the two rounds, alongside normal sprinting, jumps, reloads, retreats and capture/defense. They fired 804/960 shots, reloaded 83/97 times and had 43/52 deaths. Those are descriptions, not a score for intelligence.

The new routes and tactics changed the match balance: contested time decreased in both tested seeds. Faster wins do not prove better opponents. First arrivals and waypoint dwell improved, but brief stalls remain: the longest stationary travel burst was four seconds in one updated round, versus two seconds before. The pressure bot reached the grounded hill 1.75 seconds after the four-second stall ended. One support waypoint lasted 27 seconds but distance fell from 47.34 to 3.23 units; that life completed ingress in 34.37 seconds and fought until death. These are finite recoveries, not proof that orbiting is impossible. Displacement-only checks are insufficient, so the fixture also records waypoint dwell and hill reach per life. These runs do not establish all maps/seeds, human preference, Expert parity with a human, MacBook Air frame pacing or two-device Wi-Fi performance.

## Focused checks

- Both ground entries from all six spawn positions: actual capsule movement reaches and holds the hill; route stays fixed within a life.
- Controlled transit before/after: the old bot had no lateral displacement while shooting; the final bot moved about 0.915 game units sideways while retaining 18.09 game units of forward progress versus 19.53 before, with four shots in both trials. This synthetic trial isolates steering; it does not measure combat strength.
- Physically blocked waypoint: the final bot advanced past the occupied waypoint and made 8.96 game units of forward progress; the captured baseline stayed on the blocked waypoint after three seconds. Collision with the solid body remained intact.
- Reload cover outside the hill: collision-verified cover is selected and approached, including after sight/target is lost.
- Independent Normal and Expert route checks. Expert seed 1073: all six reached the grounded hill in 12.68–17.27 seconds; each occupied it for 15.32–26.30 seconds during a 45-second check; longest post-arrival absence was 1.27–3.92 seconds. Assertions check entry, occupancy and bounded return rather than one arbitrary final snapshot.
- Cover, difficulty, real sprint/jump, ceiling/edge safety, respawn and host controls pass. Some headless fixture shutdowns emit resource/ObjectDB warnings; these are recorded separately from gameplay assertions.

## Native observation and release

A separate real-time 60Hz native Metal run on the M3 Pro completed cleanly: two captures, 9.9 contested seconds, 127 shots, six deaths and 13 reloads. Captures at 15/30/45/60 seconds show arrivals, damage, reinforcements and Amber-to-Cyan recapture. This is rendered behavior evidence, not a frame-time or humanlike-play benchmark. The updated Universal2 app exported successfully; ad-hoc signature verification and ZIP integrity passed.

## Expert combat limits

A held-out 120-second actual Expert match (seed 1073) exercised 340 shots, 21 deaths, 34 reloads and three captures. All six eventually reached the grounded hill, but Amber arrived in 11.6–14.6 seconds while Cyan arrived in 38–39 seconds after combat losses. Cyan bots reached the hill in fewer lives. Stationary travel stalls were at most one second and waypoint dwell at most 12 seconds. This shows approach/combat imbalance, not proven human-level Expert play; timing and route tests alone do not establish fairness or strength. Expert should remain a playtest profile pending human feedback.

## Decision models

No model was installed or invoked; no Jev credit was spent. See **Local Bot Intelligence Options.md** for primary-source research and the staged recommendation: improve concrete local behaviors first, test Laya asynchronously on the host in shadow mode, then consider a trained policy for movement/aim. A model picking a valid action is not proof that the action is strategically good or reachable.
