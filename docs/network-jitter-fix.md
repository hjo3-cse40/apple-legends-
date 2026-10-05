# Joining-client motion repair — October 5, 2026

Three concrete implementation problems matched the reported joining-player jitter:

1. The joining client compared its live position with a host snapshot reflecting an older sent pose. At more than 1.5 metres apart, it teleported backwards. Ordinary round-trip delay plus fast air movement could therefore trigger a correction despite perfectly valid motion.
2. Host remote humans used one `move_and_collide` sweep, while the local controller steps up and slides. An isolated 0.30 m legal step reproduced 3.9943 m of divergence: the client crossed, while the host got stuck on the capsule/step corner.
3. Movement packets had no life generation. Buffered pre-respawn movement could overwrite the host's fresh spawn. Different ENet channels also need an explicit match epoch across lobby/start transitions.

Repair: numbered sent poses with bounded history, acknowledgements carrying collision-swept host positions, and correction relative to the acknowledged sample. Newer outstanding history includes any actual correction; duplicate or tiny physics-margin corrections are ignored. Local velocity, acceleration, jump height, air-strafing and sprint tuning remain unchanged. The host now sweeps a bounded low-rise vertical segment and slides collision remainders, matching legitimate step traversal while checking every segment against walls/ceilings. Pose/shot/reload packets require the current match epoch; poses/shots/reloads also require the current life generation. Whole world snapshots reject older timestamps and epochs. Remote client presentation interpolates timestamped samples through a 100 ms buffer, clears on respawn and holds across an outage rather than extrapolating through walls.

Protocol is `apple-legends-lan-3`: replace both exported app copies. This remains local human movement validated by host collision/rate checks, not fully server-simulated input prediction, lag compensation or an Internet-ready anti-cheat system.

Verification:

- `python3 tests/run_lan_tests.py lan_match_two_process.gd 1v1` (also default2v2 and3v3): actual ENet, joining-client20 m/s movement with artificial100–140 ms uneven/reordered snapshot processing; maximum rewind0.000000 m. Grounded local-controller/reference traversal across a0.30 m step under the same delay; maximum divergence below0.10 m (observed3v3:0.048509 m). Shots/hit markers, health, death/respawn/restart, difficulty replication, return/start epoch, buffered old snapshot/pose/shot, stale reload, disconnect/reconnect and versioned sessions are checked.
- `tests/network_motion_smoke.gd`:100 delayed30 m/s acknowledgements, duplicate/history reset, real static-wall capsule sweep and correction, irregular20 Hz remote samples (presentation error0.000000 m), nearby respawn buffer flush.
- Real transport session, version and full-room tests pass. Companion `network_capsule_routes_smoke.gd` records independent actual player/remote capsule trajectories through legal steps, all six spawn pads/eight map ramps and wall/ceiling safety.

Automated local delay injection demonstrates the repaired code paths; it does not measure the girlfriend's Air performance, home Wi-Fi packet loss, subjective feel or prove that every remaining interruption is networking. Repeat the two-Mac playtest with matching updated apps.
