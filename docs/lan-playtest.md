# Apple Legends LAN playtest — 0.4.3

This build supports one private party on the same local network, with one to three participants on each team. Participants can be humans or optional bots. The game opens in the lobby; the existing offline Garden scene remains available separately for regression checks.

## Play together

1. Give both Macs the same `Apple Legends.zip`, unzip it and open `Apple Legends.app`. No Godot installation is needed. Use the ZIP for AirDrop so the application bundle stays intact.
2. On the host Mac, enter your name and choose **Create party**. Share the IPv4 address displayed under the connection controls.
3. On the other Mac, enter a name and that host address, then choose **Join party**. Both Macs must be on the same ordinary home Wi-Fi/LAN; guest-network client isolation can prevent joining. If macOS asks, allow this game to access the local network.
4. Use **Join team** on Cyan or Amber. Each team has three slots. Empty slots are optional. Only the host adds/removes bots or uses the **Fill empty slots with bots** switch before starting.
5. For two humans versus two bots, both humans join the same team and the host adds two bots to the opposite team. For 1v1, place one human on each team and add no bots. For full 3v3, fill all six slots with any allowed mixture.
6. Each human chooses **Ready**, then the host chooses **Launch match**.

A room with bot-filled slots admits a joining human by replacing a bot when possible. A started match cannot be joined mid-round. A joining build must match the host's version.

## Controls and developer tools

WASD move; Shift tap/hold sprint; Space or wheel-down jump; LMB or V fire; RMB aim; R reload. Existing CS sensitivity and saved two-slot keyboard/mouse bindings remain under Esc settings. Space retains variable jump height; wheel jumps use the full authored height. Esc releases local input in a LAN game and leaves the match running for everyone else.

**Esc → Developer tools** exposes restart, freeze/resume all bots, disable/enable bots, and return to lobby. Add/remove team bots from this panel returns the whole party to the lobby while keeping human connections; ready up again after roster edits. F1 also freezes/resumes all host bots. Client controls cannot alter the shared match. A client can leave their own party. When a client disconnects, the host returns to the lobby; when the host leaves, the client gets a clear disconnected state. Host migration is not implemented.

Bot freeze preserves bodies/objective presence for inspection. Bot disable removes their combat, collision and objective presence; re-enabling restores their state. KOTH capture, ownership clocks, contest/overtime, respawns and announcement cues use the host's match state.

## Implementation and limits

ENet UDP port 27777 handles the private LAN connection. Lobby mutations use reliable host RPCs. Poses and compressed full-world snapshots use separate ordered unreliable channels at 20 Hz. Snapshot compression avoids the observed MTU warning at larger rosters. The host checks team caps, build version, finite/bounded movement poses, movement rate, shot origin, magazine, cadence and reload time; the host resolves hits through actual map collision and owns health, bots, respawns and KOTH clocks. Friendly bodies block shots without taking damage.

Human movement runs locally for responsiveness. The host sweeps remote movement against collision, and the client corrects substantial disagreement from host snapshots. This is an initial private-LAN prototype, not complete server-side movement simulation, lag compensation or an internet matchmaking service. Fast aim changes are accepted as shot intent rather than incorrectly constrained by an older movement packet. Bots and other humans interpolate on clients, with team accents, replicated firing flashes/audio, health labels and directional damage cues.

Bots select visible living enemies, avoid friendly/disabled targets, retain targets briefly, react/aim with a delay, strafe with variable timing, reload magazines, briefly retreat at low health, test reachable cover and spread their hill holding positions. Long-distance navigation uses verified authored ground lanes. Upper-tier navigation, advanced coordinated tactics, difficulty menus and TF2-level intelligence are not claimed. Subjective difficulty/fun and performance on the girlfriend's Air require the first real two-device playtest.

## Export

Install Godot 4.7.2 official macOS export template using Godot's template manager. Export preset **macOS LAN Playtest** creates a Universal 2 application with runtime scenes/assets and ad-hoc signing, without source tests/docs/scratch files. ASTC import is enabled for Apple Silicon exports. The private app is not notarized: macOS may require **System Settings → Privacy & Security → Open Anyway** on first launch. Do not disable system security globally.

For future distributions, increment `BUILD_VERSION`/`VERSION` in `scenes/network/lan_session.gd` and the export version, then give all players the same ZIP. There is no automatic updater in this build.

## Verification commands

Run from the repository using Godot 4.7.2. Local socket tests require local network access.

- `python3 tests/run_lan_tests.py lan_session_smoke.gd`
- `python3 tests/run_lan_tests.py lan_version_smoke.gd`
- `python3 tests/run_lan_tests.py lan_match_two_process.gd`
- `python3 tests/run_lan_tests.py lan_match_two_process.gd 3v3`
- `Godot --headless --path . --script tests/team_match_smoke.gd`
- `Godot --headless --path . --script tests/bot_team_smoke.gd`
- `Godot --headless --path . --script tests/bot_squad_routes_smoke.gd`
- `Godot --headless --path . --script tests/bot_cover_smoke.gd`
- `Godot --headless --path . --script tests/lan_settings_smoke.gd`
- `Godot --headless --path . --script tests/lobby_ui_smoke.gd`

Run independent offline movement/rifle/KOTH rules checks after changes to their hooks. Native UI rendering and exported-app startup/gameplay checks supplement these fixtures. Recorded test results are documented in the session handoff; two OS processes on one Mac are not proof of two-device Wi-Fi success.

## Final local validation

Actual two-process 2v2 and 3v3 matches passed damage, team immunity, respawn, restart, lobby return and reconnect checks. Native capsule traversal and 392 exact obstacle collision samples passed. Dense decorative hill geometry is retained for ray queries while capsule movement uses a smooth convex apron. A 30-second six-character fixed-camera test on the M3 Pro averaged 119.1 FPS with a minimum sampled FPS of 117; this is not an Air or full-session benchmark. On October5 the user confirmed testing with girlfriend worked over home Wi-Fi. Subjective bot difficulty, detailed session coverage and Air performance remain unreported.

Final release verification: exported Universal 2 app signature passed; native packaged UI successfully created a party, filled all six slots, readied, launched Garden Circuit, opened developer tools and returned the party to the lobby. Release templates do not support external --script fixtures, so the packaged test used the real UI.

The October 4 reference-style lobby uses an illustrated garden backdrop and porcelain robot portrait, with live interactive team cards and counts. Turn on Fill empty slots with bots to fill both teams when starting; leave it off for optional smaller matches. Version 0.4.1 / apple-legends-lan-2 requires both Macs to replace their previous app copies.

## October 5 user playtest

The user reports that testing with girlfriend works. Actual two-device LAN play is confirmed by this report, though it does not specify roster, session length or frame rate. See docs/lan-session-handoff.md for resume context.

## October 5 — partner jitter and bot/input pass

Build 0.4.2 / apple-legends-lan-3 requires replacing both players’ apps. The updated pose packets carry sequence acknowledgements and respawn generation. Local movement reconciliation compares the host result to the exact submitted sample, preserving motion since it was sent. Old-life movement, shots and reloads are rejected, and a match epoch rejects buffered traffic from a previous lobby match. Remote actors render timestamped snapshots through a 100 ms buffer, cleared on respawn. This addresses known stale-state corrections and packet-arrival jitter; it does not prove home Wi-Fi or MacBook Air frame pacing is perfect.

Host developer tools include a three-step bot difficulty scale. Normal and Expert sprint in transit/retreat/reload, vary combat movement and can perform safety-tested combat hops. All profiles retain the same health/damage. Expert is not a measured human-skill rating. World gunfire now uses the same spatial settings on host bots and replicated characters; shots are louder, including the local rifle.

Esc → Keyboard & mouse bindings supports two slots per gameplay action and saves on each device. Default Jump is Space plus wheel-down. Rebinding checks conflicts and reserved controls. Reset restores defaults. Model integrations and new modes are design proposals only; see [movement/bot/mode notes](movement-bots-modes.md).

## 0.4.3 bot tactics follow-up

The host bots now use direct/side ground hill entries, bounded combat maneuvers during transit, persistent verified reload cover and waypoint-progress recovery. Tactical displacement cannot cancel the route intent; anchors prioritize capturing. Health, damage and player movement are unchanged. See local-bot-intelligence-options.md for researched local model paths; no inference runtime is installed. Both players should replace their app with the matching 0.4.3/apple-legends-lan-4 build. This changes the release gate, not the LAN packet schema.
