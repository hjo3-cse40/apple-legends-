# Apple Legends — movement, bots, and modes

October 5, 2026. These are design recommendations; new game modes and model integrations are not implemented by this pass.

## Preserve the movement identity

Keep the existing Source-style directional air acceleration, momentum and manual hop timing. The speed you discovered is a useful signature for tiny robots crossing a huge garden. Build around it before changing speed caps. Evaluate competitive map routes with fast movement as well as ordinary walking; speed can otherwise bypass useful combat positions and objective timing.

Retain variable-height Space jumps as the default for Garden Circuit. They support short cover jumps and longer traversal. Give scroll-wheel jumps a consistent full-height launch, since a wheel tick has no hold duration. A later optional fixed-height mode can share the same launch and air physics. For a scored KZ course, lock the jump mode per course/ruleset and keep separate records if multiple modes are offered. Avoid silently changing the accepted movement while fixing networking.

A useful movement test course should include: flat acceleration lane; two-hop strafe lane; low/medium/high platforms; 90-degree airborne turn; ledge recovery; tight ceiling; and a long gap requiring conserved momentum. Show speed, peak speed, airtime, checkpoint times and optional ghost. Reset instantly to a checkpoint. Distinguish clean runs from practice runs using ledge recovery/checkpoints. The current unlimited-duration ledge recovery differs from traditional timed coyote jumping and should be an explicit course rule.

## Measured movement experiment

Native Godot physics tests on a flat fixture used the actual player capsule and scripted inputs. From an initial speed of 7 game units/s, two full-height hops with idealized perpendicular air-strafe input landed at 12.320 then 15.550 units/s. This confirms meaningful speed gain and retained momentum; it is not a human skill benchmark or a subjective play session.

| Jump input | Apex above launch, game units | Horizontal travel, game units |
|---|---:|---:|
| Quick Space tap | 1.284 | 6.184 |
| Space held 10 physics ticks | 3.824 | 10.500 |
| Full Space hold | 6.208 | 13.883 |
| Wheel pulse | 6.208 | 13.883 |

The three Space heights are substantially different. My recommendation is to keep that control for combat and exploration, with repeatable full-height scroll jumps for bhopping. A fixed-height option is worth testing in a dedicated KZ course rather than changing everyone’s existing controller. These are fixture distances under scripted movement, not guarantees on sloped or obstructed map routes.

## Make bots intentional and imperfect

Randomness should change route choice, attack angle, strafe timing and commitment, while health, ammunition, visibility and objective urgency drive goals. Purely random jumping and running can look active without producing better play.

Use a local decision layer scoring capture, defend, flank, engage, reload and retreat. Maintain a chosen action briefly to prevent rapid indecision. Individual styles can bias aggression and flank frequency; team roles can distribute attackers, anchors and flankers. Perception should use visible opponents and short-lived last-seen information rather than knowing everyone through walls. Physics, aiming, shooting, path following and safety checks stay local to the host.

Simple bots are movement practice: walk routes and visit the hill with little combat pressure. Normal bots sprint in transit, strafe in combat, vary approaches and retreat/reload. Expert bots react sooner, aim better and make stronger choices, while respecting occlusion and geometry. “Rivals a decent human” needs real human matches and win-rate evidence; it cannot be established by tuning a hit probability. A future difficulty evaluation should log objective contribution, wasted shots, stuck time, deaths and human win rate over multiple matches. Improve navigation before adding aim accuracy beyond what feels fair.

Future navigation work: explicit safe jump links, upper-tier routes, flank lanes, hazard/ledge detection and teammate spacing. A tactical decision model cannot create a traversal ability or path that the local controller lacks.

## Jev / Laya experiment

Jev produces typed decisions with probabilities according to [TypeSafe’s documentation/site](https://typesafe.ai/). Laya offers typed choice, score and yes/no decisions using open weights; its [official repository](https://github.com/NandhaKishorM/laya) and [model card](https://huggingface.co/convaiinnovations/laya) describe the runtime and Apache-2.0 license. Published speed claims do not establish latency or playing quality in this Godot game.

Recommended trial: ask one tactical question on the host every 1–2 seconds, such as “capture, defend, flank, regroup, or retreat?” Supply compact perceived state, valid reachable choices, health/ammo, teammates, last-seen threats, and KOTH urgency. Give each request a match/life/request ID; reject obsolete responses. Keep local decisions when replies time out or propose invalid choices. Never wait for a model in the physics loop, and never use it for per-frame aim or jumping. A hosted provider needs a credential-protecting backend; an open local model needs measured memory, CPU/GPU contention and packaging work. Neither is added as a dependency now.

First run models in shadow mode: compare their decisions against the local bot without letting them control it. Only promote if they improve objective play, variety or player preference at acceptable frame pacing. The existing local decision system is the baseline and fallback. This approach is consistent with combining local behaviors and utility selection discussed in [Game AI Pro](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter10_Building_Utility_Decisions_into_Your_Existing_Behavior_Tree.pdf).

## Mode order

| Mode | Original prototype direction | What it validates |
|---|---|---|
| KZ / movement lab — next | Robot-scale checkpoints through oversized garden furniture; precision route and high-speed route; instant reset, timer, speed readout | Whether the movement alone holds attention; jump consistency; map geometry |
| Duel / small round arena — next combat mode | 1v1 first, then 2v2/3v3; short rounds, equal starting equipment, no mid-round respawn; original compact map | Gunplay, movement under pressure, fair spawns and round flow with few players |
| Control — after those | Three original campus zones, score for ownership, respawns and rotating reinforcement paths | Team allocation, readable objectives and larger navigation demands |
| Battle royale — long term | First a small elimination survival test with shrinking playable area; only later a larger world, loot, squads and recovery | Survival pacing before committing to large-player networking/content |

Keep KOTH as the reliable playtest baseline. For the first KZ course use a separate original small map rather than reshaping Garden Circuit. For duel, favor a few strong movement routes and cover exchanges rather than an arsenal/economy immediately. For Control, evaluate rotations at bhop speed: three points are only strategically distinct if travel, sightlines and respawns preserve choices. For battle royale, establish authoritative movement, load testing, reconnect/spectating and a fair combat loop before scaling player count. It is a separate production milestone, not a switch on the current 3v3 lobby.
