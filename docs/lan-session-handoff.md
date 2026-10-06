## Latest Laya integration — October 6, 2026

User explicitly authorized installing Laya and implementing/test-driving bot decisions. Build0.4.4/apple-legends-lan-5 adds host-only asynchronous Local/Shadow/Enabled controls, bounded perceived-state tactical candidates, lifecycle/freshness/geometry guards and offline local fallback. Python3.13.4/laya0.3.28 is isolated in ~/laya/.venv, pinned English convaiinnovations/laya revision7b928d828b7b0e022f929d9bd2e44165aa270148; ~/laya/bot_worker.py is the standalone game adapter. Exported apps contain neither Python nor model weights; joining Macs run no inference. See docs/laya-bot-planner.md and delivered Laya Setup and Controls.md/Laya Bot Evaluation.md.

Local tactics remain default. Stock model showed no convincing overall improvement; repeated same-state option reversal revealed positional bias. Final wrapper canonicalizes observations/candidates and averages two opposite option-slot passes using unchanged weights. Compare final Enabled with same-code Local separately from stock results; no model training, human-parity claim or paid inference. Player movement/network mechanics/HP/damage/map preserved. Early neutral/moving-state replays did not reproduce sustained locks. Exact post-contact268s state subsequently reproduced15s zero travel with only floor contacts. A verified bot-only fix sets grounded vertical velocity0 instead−0.5, preserving floor_snap_length=.25 and airborne/hop/player behavior. Both preserved-before/current policy arms prove baseline0travel15s vsgoal2.37s after,900/900framesgrounded; actual wall/ceiling/cover/route guards pass. Keep this controller fix separate from Laya model-quality claims and retain pre-fix studies. A subsequent frozen study reproduced a separate243-second target-free wall-following failure. Captured before/after replay proves the preserved controller never reaches hill in30s, while final target-free capsule/support-verified wall-tangent recovery reaches hill13.35s with1800/1800framesgrounded. Climbable steps and valid-target combat retain the existing controller; an early regression was rejected and all six Expert1073 trajectories restored exactly. Final paired floor replay reaches goal2.4s versus preserved-before zero travel15s. All nine final bot fixtures and exact feature editor import pass; commit39fec74 freezes the controller. Final same-code Local/Shadow/Enabled study is rerun after both fixes before release. Three authorizedGPT-6.1 agents reused; noAstra/6Sol/Jevcredits/push. Exact evaluation results and hardware limits belong in the delivered report. Preserve source-freeze data for each test block.

# Current bot follow-up — October 5, 2026

Current release **0.4.3 / apple-legends-lan-4**, Godot4.7.2 standard. User requested more bot testing and alternatives to Laya/local models. Three authorizedGPT-6.1 agents performed implementation, seeded actual six-bot KOTH comparison and independent review. No Astra/6Sol, paid inference, model download or runtime integration. Bot changes: two verified ground hill entries after the common protected spawn exit; transit engagement with positive waypoint intent, bounded commitments and progress recovery; persistent reachable reload cover; transit teammate spacing and safe obstacle steering. Existing player movement, network fixes and HP/damage preserved. Expert versus human ability is unmeasured.

Evidence and release live in current chat outputs: Bot Playtest Results.md, Local Bot Intelligence Options.md, updated Play Together.md and versioned0.4.3 ZIP. Both players replace apps because the release gate changed; LAN packet schema is unchanged. The normal Godot project must be synchronized and imported before normal Run validation, as specified below. Source remains expanded checkout feature/lan-lobby-team-bots, local commits only, no push.

The first proposed transit maneuver regressed into prolonged fights outside hill. Reject it: final steering projects lateral maneuvers perpendicular to the waypoint goal, suppresses tactical drift near gateways, keeps anchors urgent and measures actual progress. Stationary-only stuck counters miss moving orbits; live fixture records per-life hill reach and waypoint dwell too. See outputs report for final metrics/limits and docs/local-bot-intelligence-options.md for proposed host-only asynchronous Laya/shadow comparison and longer-term learned movement policy.

---

# Current handoff — October 5, 2026, partner playtest fixes

The user now reports real 1v1 and same-team 3v3 with girlfriend: joining view lags/jitters, especially after respawn; wants stronger bots, louder shots, wheel-down jump/keybindings and movement/mode analysis. This is new implementation authorization, superseding the saved-only request in historical notes below.

Current release: **0.4.2 / apple-legends-lan-3**, Godot4.7.2. Both players must replace0.4.1 apps. Latest deliverables: `/Users/samjo/Documents/Codex/2026-10-05/ok-for-my-apple-legends-i/outputs` — versioned ZIP/app, Play Together.md, Playtest Changes and Verification.md, Movement, Bots, and Modes.md, launch command and native UI/gameplay images.

Three GPT-6.1 agents implemented network, bot and input work with independent cross-review. No Astra or6Sol used. Work remains local; no GitHub push authorized for this pass. Source stays in the expanded checkout on feature/lan-lobby-team-bots. Preserve the normal `/Users/samjo/Apple Legends` project and import requirement below.

Fix mechanisms: local reconciliation against acknowledged sent position rather than stale host position; life generation and match epoch gates for old movement/shots/reload/world; monotonic world timestamps; timestamped100ms remote presentation buffer cleared on respawn. Host uses bounded collision-checked rise plus slide for remote pose validation, addressing local step-up vs host single-sweep mismatch. Human movement remains locally simulated with bounded host checks, not fully server-simulated/lag-compensated public multiplayer.

Host bot slider: Simple/Normal/Expert, defaultNormal. Sprint traversal/retreat/reload, persistent varied strafe/engagement, pressure/anchor/support roles and occasional capsule/landing-checked combat jumps. Health/damage unchanged across profiles; Expert is not proven competitive with a decent human; upper-tier navigation remains future work. Gunfire now louder and spatial settings equal on host/replicated actors.

Esc bindings: two saved keyboard/mouse slots per gameplay action; Jump defaultsSpace + wheelDown. Space variable height preserved; wheel full-height pulse; rapid press/release intent latched and lifecycle resets clear it. Existing movement physics unchanged. Native scripted two-hop ideal air-strafe speed7→12.320→15.550; tap/partial/full jump apex1.284/3.824/6.208 game units, wheel matches full. These are scripted observations, not subjective play or human benchmarks.

Design recommendations in docs/movement-bots-modes.md: keep variableSpace and consistent wheel; next small original KZ course, then duel/round arena, then three-zoneControl, with BR a separate long-term milestone. Jev/Laya optional future host tactical planner/shadow experiment with local fallback; no model service, credentials, costs or new modes implemented.

Verification detail is in delivered Playtest Changes and Verification.md. Relevant automated/native checks cover delays, respawn/lobby lifecycle, collisions, bots, input and UI. Native six-actor fixed-camera30s M3Pro mean119.8FPS/minimum one-second sample118; not an Air or worst-frame benchmark. Repeat real two-Mac Wi-Fi session to confirm subjective jitter, mix and difficulty. Do not label the partner’s exact hardware experience resolved without that playtest.

---

# Apple Legends — resume handoff, October 5, 2026

The user reports: “I tested with my gf and it works.” Real two-Mac play over their home Wi-Fi is now user-confirmed. Exact team composition, session length, Air specifications/performance and subjective bot difficulty were not reported. Do not treat these as measured or fully tested. User requests saving context to continue in another chat; no new implementation, automation, deployment or push is authorized by this save request.

## Current build and project

- Game version: 0.4.1. LAN version gate: apple-legends-lan-2. Godot: 4.7.2.
- User's normal Godot project: /Users/samjo/Apple Legends/project.godot. F5 launches scenes/main/lan_main.tscn, the newest lobby.
- Working feature checkout: /Users/samjo/Documents/Codex/2026-10-03/for-the-apple-legends-i-wanna/work/apple-legends-expanded; branch feature/lan-lobby-team-bots. Original checkout is fast-forwarded to the same source. Local commits only; no GitHub push requested.
- Shareable ZIP in Downloads: /Users/samjo/Downloads/Apple Legends v0.4.1 2026-10-04.zip.
- Deliverable directory: /Users/samjo/Documents/Codex/2026-10-03/for-2/outputs. Contains Apple Legends.zip, Apple Legends.app, Play Apple Legends.command, Play Together.md, Lobby Screen.png, Godot Project Lobby.png, and asset notes.
- Both Macs use matching builds. Girlfriend runs the exported app without Godot/development tools. User can run in Godot.

## Accepted direction and implemented behavior

Native private LAN first, maximum3 players per team. Flexible human/bot counts and empty seats: 1v1,2v2,3v3 or asymmetric rosters; two humans can choose the same team versus two bots. Host/create and join by host LAN address, choose teams, ready, host start, add/remove bots, optional fill-empty-slots switch on start. No auto-discovery, public matchmaking, web build, auto-update or5v5 implemented. Eventual goal is TF2-inspired chaos and perhaps5v5, but retain3v3 cap for now.

User explicitly chose the supplied campus lobby reference, rather than the original plain UI. Accepted style: white porcelain/EVE-inspired robot, bright white garden campus with trees/blue sky, translucent Cyan/Amber team cards, correct live counts and host/ready tags, map card and cyan Start Match button. Background and central portrait are generated raster assets; controls are real Godot UI. Portrait recolors team accents. Combat MiniBot/map are unchanged by the lobby art pass. Prompts and assets recorded in docs/lobby-reference-assets.md.

Host owns bots, hits/damage, health, respawns and KOTH clocks. Human movement is local with host collision/rate checks; snapshots20Hz. ENet UDP27777. Version gate rejects mismatched builds. Friendly bodies block bullets without taking damage. Existing KOTH capture/contest/overtime/audio and accepted movement/rifle/sensitivity tuning retained. Bots select visible enemies, react/aim imperfectly, strafe, reload, use reachable cover, retreat at low health and spread hill positions using ground routes. Upper-tier routing and TF2 parity not claimed.

Esc settings release local input while LAN match continues. Host developer tools restart, freeze/resume or disable/enable bots, return to lobby, and roster edits (return whole party to lobby). F1 freezes all host bots. No free-form command console is implemented.

## Important import fix

Normal project once displayed correct controls with black background and no robot: source images existed, but ignored .godot/imported caches had not been generated in original checkout. Repaired and native-rendered original project successfully. After EVERY future source sync to /Users/samjo/Apple Legends, run:

/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path '/Users/samjo/Apple Legends' --import

Then validate original project's normal Run, not just feature checkout. Do not transfer .godot via Git. Current lobby fixture checks actual imported backdrop/portrait/toggle textures. User should stop an old run and press F5 again to see refreshed imports.

## Joining and updates

Both Macs on same Wi-Fi. Host creates party; partner enters host Wi-Fi IP and joins; choose teams/bots; both ready; host starts. User's verified Wi-Fi interface is en0. On October4 it had10.0.0.163; this is historical and can change. Check current address with ipconfig getifaddr en0. Lobby may list virtual interface addresses too; use Wi-Fi address. Allow requested local network access. Ad-hoc unsigned-by-developer/not-notarized app may require macOS Open Anyway once.

Version convention is practical major.minor.patch during prototype: 0 means initial development,4 labels currentLAN/3v3 milestone,1 is the lobby refinement revision. It is not41% completion and not strict API SemVer. Proposed future: small fixes0.4.2, next feature milestone0.5.0, firststable1.0.0. Date is YYYY-MM-DD. For future releases bump game/export and LAN build gate appropriately, export a new versioned dated ZIP, and replace both app copies. No automatic updater.

## Evidence and remaining feedback

Automated two-process LAN2v2/3v3, version/full-room gates, shots/friendly immunity/respawn/restart/lobby/disconnect/reconnect passed. Bot combat1v1/2v2/3v3, cover/reload/retreat/routes; disabled lifecycle; lobby/ready/fill; settings/rifle/movement/KOTH checked. Walking fixtures need native mouse capture, not headless. Dense hill engraving remains exact for bullet queries on layer2, with cheap capsule apron on layer1; tall geometry preserved. Six-character fixed-camera30-second native M3Pro test averaged119.1FPS/minsample117; not an Air benchmark. Original project native lobby texture check passed after import repair. Now user-confirmed actual two-device Wi-Fi success supersedes earlier “unverified” notes. Resume by getting concrete gameplay feedback or following the next request; do not invent a new task.
