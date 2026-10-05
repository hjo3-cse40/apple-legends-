# Apple Legends 0.4.2 — playtest changes and verification

October 5, 2026. Implementation used three GPT-6.1 agents with an independent cross-review; no Astra or GPT-6 Sol escalation was needed. Source changes are local, without a GitHub push.

## Joining-player jitter diagnosis

The old joining client compared its current position against an older host snapshot and snapped back when separation exceeded 1.5 game units. Fast legitimate movement plus round-trip delay could repeatedly exceed that threshold. The fix compares the host position against the exact sent sample identified by its acknowledgement, preserving motion performed since that sample and retaining local velocity.

Movement packets lacked a life generation, so buffered packets from before death could overwrite the host’s respawn position. Movement, shots and reloads now carry generation protection; a match epoch separates traffic from different lobby matches. World snapshot timestamps reject old delivery. Remote presentation uses a timestamped 100 ms buffer rather than chasing uneven packet arrivals; respawn clears it.

Independent review also reproduced a collision mismatch: the local capsule can step and slide, while the host used a single collision stop. A legal 0.30-unit step produced 3.9943 game units of disagreement. Host validation now checks a bounded rise before across-motion and slides along blocked surfaces, allowing legal client steps while retaining collision checks on each segment. The isolated step mismatch dropped to 0.00918 game units; final authored-map and obstacle checks are recorded below.

## Gameplay changes

- Host bot scale: Simple / Normal / Expert. Stronger profiles sprint in transit, retreat and reload, vary approach/strafe timing, use pressure/anchor/support behavior, and occasionally jump after full-capsule path and landing checks. Normal is default. Health and damage are equal across profiles; Expert is not a verified human skill rating.
- Gunfire: consistent world audio on host and joining client, louder shots with distance falloff, and local rifle raised 3 dB. Replicated shots previously used -12 dB/unit size 5 versus host bots -2 dB/unit size 12; both now share +1 dB/unit size 20. The source shot peak at this gain is approximately 0.808 before spatial attenuation; this is a single-cue check, not a complete simultaneous mix loudness measurement.
- Esc keyboard/mouse settings: two saved slots per action, conflicts/reserved controls checked, reset to defaults. Jump defaults to Space plus wheel-down. Space remains variable height; a wheel notch uses full height. Quick press/release events survive between physics ticks; menus/death/respawn clear pending input.
- Existing acceleration, gravity, air strafing and speeds are preserved. No new mode or model service is added.

## Verification recorded

- Actual two-process ENet gameplay in 1v1, 2v2 and 3v3: client shooting, friendly immunity, health/hit feedback, death/respawn, restart and lobby/disconnect behavior.
- Scripted network delay: moving joining client at 20 units/s with 100–140 ms uneven/reordered snapshot processing, zero measured rewind in the scenario; previous-life pose rejection. Actual delayed step traversal stayed below 0.05 game units across the final 1v1/2v2/3v3 runs. Buffered previous-match world/pose/shot and stale life/match reload requests were rejected. A separate 100-sample acknowledgement test covers 30 units/s and irregular 20 Hz remote snapshots.
- Grounded movement: native actual 60 Hz local controller against 20 Hz host capsule validation, low steps, above-limit walking obstacle, low ceiling, diagonal wall slide, six authored spawn pads and eight ramps; worst sampled divergence 0.031905 game units (about 0.99 cm at world scale), below the fixture’s 0.08-unit tolerance. Direct tall-wall and low-ceiling targets remained blocked. Host checks validate collision/rate bounds, not a full re-simulation of client inputs.
- Bot physics: actual sprint acceleration and jump launch, ceiling/unsupported-landing rejection, lifecycle reset and host-only slider. Six-second perception/weapon scenario yielded 4 / 8 / 12 shots across difficulty levels. Six bots traversed both spawn docks and held the capture radius at each difficulty; team and cover regressions passed.
- Native input and movement: actual key/wheel events, saved bindings, input clearing, two grounded hops; native Garden collision/movement/jump/ramps/F1/Esc/CS sensitivity and persistence regressions passed.
- Native UI: bindings and developer panels inspected at the 720p logical layout; developer panel also checked at 1080p.
- Audio: host/replicated gain and attenuation parity, actual shot playback, local rifle gain and existing character sound lifecycle; rifle combat regression passed.
- Packaged Universal2 release: ad-hoc signature verified; real UI created a party, filled six slots, readied, started the match, opened the new bindings panel, changed Expert difficulty and returned to lobby. Bundle version is 0.4.2; architecture check confirms ARM64 and x86_64.
- Native six-character fixed-camera scene, 30 seconds on Apple M3 Pro: mean 119.8 FPS, minimum one-second sample 118 FPS. This is not a MacBook Air result or worst-frame percentile measurement.

Headless Godot in this sandbox can emit existing macOS certificate/log-access and fixture shutdown resource messages; those messages are separate from assertion/parse failures. Relevant tests require a PASS marker as well as successful exit. Native checks reported no gameplay script errors.

## Remaining real-world confirmation

The specific home Wi-Fi/MacBook Air experience cannot be reproduced on this one host. Repeat your 1v1 and same-team 3v3 on both updated apps, especially moving/bhopping right after respawn. Automated scenarios establish the corrected mechanisms, not a promise of perfect Wi-Fi or subjective bot balance. KOTH strategy, Expert fairness and louder mix preference need your playtest.

See **Movement, Bots, and Modes.md** for measured jump/bhop results, the local bot/model architecture plan and KZ → duel → Control → battle royale recommendations.
