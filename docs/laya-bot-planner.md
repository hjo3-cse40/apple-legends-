# Local Laya bot planner

Laya is an optional host-side tactical selector. The game keeps movement, aiming, shooting, reload emergencies, collision checks, visibility and respawning local. The normal controller remains the default. No account, paid inference or Internet connection is needed once the checkpoint is cached.

## Installed environment

On this development Mac, Python and dependencies are isolated in `~/laya/.venv`. The English checkpoint is `convaiinnovations/laya`, pinned to revision `7b928d828b7b0e022f929d9bd2e44165aa270148`, with `laya[serve]==0.3.28`. The multilingual checkpoint is unnecessary for these English game-state fields and candidate descriptions. `~/laya/requirements.lock` records the installed environment; `~/laya/model-manifest.json` records the checkpoint/backend. Dependencies and weights are not included in the ordinary game export.

Start `tools/ai/laya_bot_worker.py` with the environment's Python before choosing a model mode. The worker binds only `127.0.0.1:27878`, loads one persistent checkpoint, and warms it before reporting ready. Apple GPU is selected with `--device mps`; `--device cpu --cpu-threads 2` is available for comparison. Stop its terminal with Control-C. No background login service is installed.

After the first download, the delivered launcher sets `HF_HUB_OFFLINE=1` before Python starts, so startup uses the pinned cached checkpoint. For a manual launch use `HF_HUB_OFFLINE=1 ~/laya/.venv/bin/python ~/laya/bot_worker.py --device mps`. Model weights live in the normal Hugging Face cache under `~/.cache/huggingface`, independently of the home-directory Python environment.

## Game controls

Host: Esc → Developer → Bot intelligence.

- **Local:** no inference requests; ordinary bots.
- **Shadow:** send perceived observations and log the recommendation; no model decision changes gameplay.
- **Enabled:** apply a fresh, valid recommendation as a bounded tactical commitment.

Joining players see the host's mode/status and do not run a model. Simple bots retain their walking-only profile. A missing worker, malformed response, old life/match, expired deadline, lost visibility or newly blocked goal falls back to local tactics. Freezing/disabling bots, respawning, restarting or returning to the lobby invalidates pending plans.

## Input and output contract

Requests contain `schema_version`, `request_id`, `match_epoch`, `bot_id`, `life_id`, snapshot timing, `observation`, `candidates`, and the local fallback candidate. The observation includes health fraction, magazine state, role/current behavior, visible enemies' relative positions/distances, visible ally count, public objective ownership/contest/clocks/urgency, current route entry, waypoint distance, and recent goal progress. Hidden enemy positions and private executable goal bindings never enter the worker payload.

The game supplies one to six candidates, each with an ID and an English description. Depending on current feasibility, these cover keeping local behavior, committing to the objective, a verified reload cover position, a safe brief retreat, a sustained left/right combat posture, or the alternate authored hill entry at its gateway. The model selects one joint candidate; it cannot invent coordinates, choose an absent action, or independently combine incompatible goals and routes.

The worker serializes observation keys canonically, sorts candidate IDs and scores forward and reversed candidate slots using the same checkpoint. It averages probabilities by candidate ID and chooses the highest mean (canonical ID breaks exact ties). This `canonical_reverse_mean_v1` wrapper removes caller-order dependence; it is not training or a guarantee of better tactics. Both raw pass choices/scores are logged. Two passes increase inference cost, which is measured separately.

Responses echo request/match/bot/life identity and provide `selected_candidate`, model/checkpoint/backend metadata, latency and informational confidence. Confidence is not calibrated for this game and does not prove decision quality. The game revalidates the selected candidate before applying it.

Each bot requests at most once every two seconds, staggered through one asynchronous game HTTP request. Snapshot freshness is 800 ms measured in wall time. Ordinary tactics run while inference is pending. Most commitments last two seconds; emergency local behavior and safety checks can override them. A chosen alternate entry persists in that life rather than restarting the entire route on every inference.

## Evaluation

`tests/bot_tactical_policy_smoke.gd` verifies actual displacement, cover/reload, gateway routing, hill defense movement and stale-life/visibility/geometry guards. `tests/tactical_decision_client_smoke.gd` exercises transport and lifecycle faults. `tests/tactical_decision_live_smoke.gd` uses the real local model.

`tests/run_bot_policy_eval.py` compares Local, Shadow and Enabled with the same gameplay code and seeded real-time matches. The worker and production sources are fingerprinted for the block. `tests/bot_policy_scenarios.py` separates development and held-out tactical cases and reports local/random reference performance, candidate-order sensitivity and scenario pass criteria. Native frame timing is measured separately from headless gameplay; model CPU/memory logs supplement game observations. Match evidence, numerical results and limitations are delivered in the Laya evaluation report.

Keep inference and rendering on the same host in the native performance check. Accelerated simulation is unsuitable for the wall-time freshness contract. Report successful policy applications separately from `continue_local` delegation, and do not equate safer candidate filtering or local-controller changes with model intelligence.
