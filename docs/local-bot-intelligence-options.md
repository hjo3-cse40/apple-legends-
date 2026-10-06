> October6 update: Laya is now installed independently in `~/laya/.venv`, with a tested optional host-side Apple Legends adapter. See the delivered Laya Setup and Controls.md and Laya Bot Evaluation.md for the current implementation and results. The options below record the earlier research; they are not a claim that Laya remains uninstalled.

# Apple Legends — local bot intelligence options

Research checked October 5, 2026. These are integration options, not installed models or measured Apple Legends model benchmarks. Do not interpret a model’s general benchmark or typing guarantees as FPS skill.

## Recommendation

Improve the bot’s concrete abilities and tactical choices first. Trial Laya as a host-only tactical selector against that baseline; train a small policy later if the goal is learned jumping, aiming and movement. Avoid making a language/decision service drive every physics tick. No Jev credits need to be spent for the local baseline or an offline model experiment.

| Option | Role in this game | Local cost/runtime | Main work and limits | Recommendation |
|---|---|---|---|---|
| Existing GDScript utility/state logic | Capture/defend/engage/retreat/reload; route and role selection | No weights, runtime service, or per-call fee | Need real navigation, perception, commitment and behavior tests; no learning by itself | Best immediate foundation |
| Laya | Choose among a small set of reachable tactical actions | Local weights, no API charges; CPU/MPS/ONNX options | Needs game-specific evaluation/data; integration and contention measurements; typed output does not guarantee a good choice | First decision-model experiment |
| FunctionGemma 270M | Select calls such as flank(route), regroup(ally), retreat(cover) | Small local function-calling model; runtime choice to benchmark | Google positions it for specialization; custom function vocabulary and training needed; Gemma terms apply | Credible alternative if we want an action-call training pipeline |
| Small Qwen3 model via MLX LM | Occasionally plan tactics or generate a short structured plan/personality | Local Apple Silicon inference; model/runtime memory and latency | Text generation, validation, stale plans, and contention; no game-specific skill out of the box | Optional research comparison, not per-frame combat |
| Godot RL Agents + PPO / imitation learning | Learn movement, aiming, obstacle traversal or short combat behavior from numeric observations | Training is separate; trained policy runs locally | Need observations, action space, rewards, environment resets and held-out tests; integration/deployment work | Best longer-term route for learned physical skill |
| LimboAI | Author/inspect behavior trees and state machines in Godot | Native Godot tooling, no model inference | Additional extension/build compatibility to validate with Godot 4.7.2 on Mac; no learned model | Useful authoring/debug tool if our behaviors become harder to maintain |
| Jev hosted | Tactical selector comparison | Paid remote calls, network latency | Backend/credential isolation, cost budget, offline fallback | Use existing credit only for a bounded optional comparison |

## Sources and qualifications

**Laya:** [official repository](https://github.com/NandhaKishorM/laya) describes typed choice/score/yes-no decisions, local Python/ONNX paths and Apple MPS support. It emphasizes specialization with task data; published benchmark improvements from fine-tuning are not a claim that the base understands this arena. Choose one appropriate checkpoint, preload once, and keep inputs compact; do not constantly switch models. We have not measured its latency, accuracy or memory alongside Apple Legends.

**FunctionGemma:** [Google model overview](https://ai.google.dev/gemma/docs/functiongemma) describes a 270M model specialized for function calling, intended for further tuning to application needs. A bot API could expose a small action vocabulary with reachable arguments. Generated calls must still pass local validation. This is a training alternative to a typed-choice head, not an already-trained FPS policy. See [Google’s model card](https://ai.google.dev/gemma/docs/functiongemma/model_card).

**Qwen / MLX:** [Qwen3-0.6B model card](https://huggingface.co/Qwen/Qwen3-0.6B) provides a small open model candidate; [Apple’s MLX LM project](https://github.com/ml-explore/mlx-lm) supports text generation and fine-tuning on Apple Silicon, including quantized workflows. Start with a deliberately tiny planning workload and compare reliability/latency, rather than assuming a larger language model is a better game controller. Use non-thinking mode and a strict output-token cap for occasional tactics. Specific quantized checkpoint compatibility needs verification before choosing a distribution.

**Learned policy:** [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents) connects Godot environments with Python RL frameworks and supports imitation learning. Its README describes experimental ONNX deployment requiring the .NET/Mono path; our game currently uses standard Godot/GDScript. We should prototype in a separate training harness and deliberately choose deployment, rather than silently migrating the game engine. A policy can use small numeric observations and an action vocabulary suited to physics; training cost and sample requirements must be measured.

**Behavior tooling:** [LimboAI](https://github.com/limbonaut/limboai) supplies Godot 4 behavior trees/state machines as a C++ module or GDExtension. It helps make authored decisions debuggable, not automatically intelligent. The project advertises current Godot 4.7 module support and Godot 4.6+ GDExtension compatibility; our exact 4.7.2 Mac export still needs testing. Existing focused GDScript remains sufficient for the current scope.

## How to evaluate a model fairly

1. Record decisions from actual matches: perceived enemies, last-seen positions, health/ammo, roles, point ownership/urgency, and valid reachable routes/cover. Exclude hidden live enemy coordinates from the model’s state.
2. Assemble held-out scenarios: reload under pressure, losing hill, teammate already anchoring, flanking opportunity, enemy breaks sight, blocked path and unsafe jump. Mark acceptable actions rather than only one preferred label when several are sensible.
3. Test option-order permutations, near-tied choices and truncated/obsolete state as well as ordinary examples. Then run the model in shadow mode. Log proposed action, confidence, latency and validity without letting it change gameplay. Compare against the improved local bot and a random valid-action baseline.
4. If it helps, enable a controlled A/B trial with fixed seeds/scenarios. Measure objective contribution, casualties, invalid/stale decisions, stuck time, action-switch frequency and human preference. Run rendered frame-time tests on the host while all bots use inference.
5. Keep execution local and responsive. Laya/model requests happen asynchronously every few seconds or after significant events. Revalidate results against current match/life and reachable choices; timeout falls back to the local bot. Difficulty should limit perception/reactions and execution skill rather than secretly reveal opponents through walls.

## Standard Godot integration

None of the model sources above demonstrates a drop-in GDScript bridge for this project. The least disruptive pilot is a persistent Python worker on the host, listening only on loopback, preloading one model before the round. Godot sends asynchronous compact requests; results never block physics. Queue/batch requests deliberately rather than letting six independent workers compete for the GPU. The host needs packaged runtime/weights; the joining Mac can keep the ordinary game app. This is a proposed architecture, not an implemented service or a measured performance result.

## What I would choose

For immediate enjoyable bots: the local tactical system plus genuinely different safe routes, combat-distance choices and recovery behavior. For the first model trial: **Laya**, because the output shape matches tactical choices and local operation fits private LAN. For bots that actually learn bhops and fighting mechanics: **a small trained policy using Godot RL Agents/imitation learning**, with a separate training/deployment milestone. FunctionGemma is the most interesting small alternative if we decide to train an explicit action-call vocabulary. A small generative model is worth a comparison only after the simpler options demonstrate a need.
