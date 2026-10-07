# Apple Legends — combat and health fixes, October 7, 2026

Release: **0.4.7 / build 11 / apple-legends-lan-8**. Scope: AL-01, AL-02 and AL-03. Three GPT-6.1 Sol agents handled combat, health presentation and independent review; integration and delivery stayed in this chat.

## What changed

The coworker report was: bot hits seemed fine, but shots at another human registered about half the time. Host/join role, exact aim points, running versions and network timing were not supplied. Three controlled problems were found rather than assuming a single cause:

- Human movement capsules covered less of the visible helmet than bot capsules. LAN actors now share a combat-only helmet sphere. Movement clearance and ordinary 22-damage rifle hits remain; this does not add a headshot multiplier.
- Joining players aimed at interpolated remote poses while the host tested current poses. Shots now carry the actual displayed pose timestamp and life generation. The host validates historical capsule/helmet geometry without moving live actors. Cover and nearer teammates block hits. Old-life/invalid targets can block but cannot receive damage; an unrelated respawn does not cancel an otherwise valid hit.
- The strict server packet-arrival gap discarded valid semi-auto shots under small jitter. A bounded server schedule absorbs up to 50ms of arrival variation while preserving the average rate, ammo/reload authority and immediate duplicate rejection.

Your health is now one HP number and a short bar, with a red low-health state. Enemy indicators use compact 64×5 bars, without names or numeric HP, and LAN shows at most two. They require line of sight and a maximum range of 24 game units, then either proximity within 8 units or aim within a 6° cone. A 0.65-second focus grace reduces flicker but never overrides cover, range or life state. Teammates retain small cyan names within 36 units. Overlapping cues are suppressed rather than stacked away from their actor. Offline enemy cues use the same policy.

Distances are game coordinates, not physical metres in the miniature art. Movement, bot tactics, rifle damage/cadence, map assets and saved input bindings were preserved.

## Verification

| Check | Result |
|---|---|
| Frozen baseline cadence probe | 6/12 valid shots accepted with alternating 200/240ms arrivals; final code accepts 12/12 and rejects instant duplicates |
| Helmet physics sweep | At height 1.80, human coverage improves from 0/97 to 61/97 sampled rays; human/bot upper-head coverage agrees within tangent precision |
| Controlled rendered-pose fixtures | Current-pose control 0/9 versus compensated 9/9 across 6/12/20 game units/s and 100/200/300ms views |
| Real two-process ENet, actual rifle | Same-code current-ray control 0/6 versus corrected 6/6: three moving-human and three moving-bot shots, at 12 units/s with 80/100/120ms added world-snapshot delay |
| Host shooting human helmet | Actual rifle applies 22 damage; joining player receives 78 HP |
| Lifecycle, cover and validity | Walls, nearest teammates, death, respawn generations, malformed/future/old timestamps, unrelated respawn and original narrow movement clearance pass |
| Existing LAN suites | 1v1 and 3v3 pass; final repeated 3v3 verifies damage/hit feedback, friendly immunity, movement reconciliation, low steps, respawn/restart, lobby, disconnect/reconnect |
| Session and version gates | Final paired transport/session and incompatible-build rejection pass |
| Health policy and visuals | Remote humans and bots verified in actual garden; headless assertions and native 1280×720 / 1920×1080 screenshots pass for focused crowds, off-axis/far enemies and cover |
| Existing combat regressions | Rifle hit/miss/cooldown/reload, five-hit TTK, ADS, damage direction and objective audio assertions pass |
| Saved wheel binding | Native full match uses the existing button-4 slot; one pulse produces one launch, menus queue none, and jumping works after settings close |
| Native integration | Six actors run for 30 seconds in the actual garden, with the final HUD inspected; this is a smoke test, not a performance benchmark |
| Exported app | Universal arm64/x86_64 bundle, version/build metadata and ad-hoc signature verify; packaged native lobby rendering shows 0.4.7 / build 11 without gameplay errors |

The current-ray ENet control bypasses compensation in the same updated code to isolate timing. It is not a claim that the entire original build was re-run in that comparison. Frozen baseline cadence and geometry probes separately preserve the original code/geometry evidence. One repeat exposed an overly strict fixture displacement threshold; it was replaced with the combat radius plus clearance while retaining the exact hit/damage expectations. Final paired tests all pass.

Saved bindings SHA-256 remained `ba46373a6a7844360de27044b6f5b4b437eb3d4a8e075f3e3165af1efff843f3`. The user's confirmed physical downward wheel maps to OS Wheel Up on this mouse; that preference was retained. Some headless fixtures emit the previously observed macOS certificate or teardown resource warnings. Final native combat, full-wheel, integration and packaged startup runs have no gameplay script errors.

## Use this release

Stop an old editor run, then press F5 in the registered `/Users/samjo/Apple Legends` project after synchronization/import. For coworkers, share **Apple Legends v0.4.7 2026-10-07.zip**, extract it and replace the older app. Every participant must use this build; the protocol gate intentionally rejects older versions. The app includes Godot; coworkers do not need the editor, Python or Laya.

## Limits and next playtest

These are automated localhost/engine tests and inspected renders, not another physical coworker Wi-Fi session. They establish concrete fixes for three reproduced mechanisms, not proof of the exact original coworker failure. Compensation is bounded to 350ms of target history; severe outages, the existing two-unit shooter-origin tolerance and larger cadence variation can still deny shots. This prototype retains locally simulated movement and host damage authority.

The Mac locked during the run. Packaged startup was verified through engine-produced frames; an interactive packaged LAN match and GitHub board/checkpoint edits could not be performed while locked. Implementation checkpoints are saved locally in the source/docs. AL-01 through AL-03 are ready for the next real playtest; #16 remains Done on GitHub.

Next human check: use identical builds, shoot stationary and strafing human targets from both host and joining sides, then check that aimed/nearby health cues are readable and disappear with distance/cover. Record which role, build and circumstance still fails if anything remains.

## Reproduce focused checks

Run Godot 4.7.2 against this project. Fixtures are `tests/combat_history_smoke.gd`, `tests/combat_hit_validation_smoke.gd`, `tests/team_health_readability_smoke.gd` and `tests/full_match_wheel_regression.gd`. Native health capture accepts `-- --capture-size=1920x1080`. The paired runner accepts `python3 tests/run_lan_tests.py lan_hit_registration_two_process.gd`, with `--current-ray-control` for the isolated control, and the existing LAN/session/version fixtures. Do not run two socket suites on port 27777 simultaneously.
