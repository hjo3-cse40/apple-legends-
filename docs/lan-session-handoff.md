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
