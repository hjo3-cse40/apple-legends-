class_name TacticalDecisionClient
extends Node
## One asynchronous host-only loopback request; physics always has a local fallback.
signal decision_logged(event: Dictionary)
enum Mode { LOCAL, SHADOW, ENABLED }
const ENDPOINT := "http://127.0.0.1:27878"
const REQUEST_TTL_MSEC := 800
const INTERVAL_MSEC := 2000
const MAX_QUEUE := 6
const MAX_EVENTS := 256
var mode := Mode.LOCAL
var enabled_teams: Array[int] = []
var worker_ready := false
var status := "Local tactics"
var manager: Node
var metrics: Dictionary = {}
var decision_events: Array[Dictionary] = []
var _http: HTTPRequest
var _active: Dictionary = {}
var _queued: Dictionary = {}
var _next_due: Dictionary = {}
var _health_due := 0
var _request_serial := 0
var _mode_generation := 0
var _last_choices: Dictionary = {}
var _was_available := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.body_size_limit = 65536
	add_child(_http)
	_http.request_completed.connect(_request_completed)
	reset_metrics()

func configure(owner_manager: Node) -> void:
	manager = owner_manager

func reset_metrics() -> void:
	metrics = {"requested": 0, "completed": 0, "applied": 0, "rejected": 0, "stale": 0, "timeouts": 0, "offline": 0, "action_switches": 0, "agreements": 0, "comparisons": 0, "latency_ms": [], "latency_total_ms": 0.0, "latency_max_ms": 0.0, "applied_actions": {}, "local_delegations": 0, "policy_applied": 0}
	decision_events.clear()
	_last_choices.clear()

func set_mode(value: int) -> void:
	mode = clampi(value, Mode.LOCAL, Mode.ENABLED)
	invalidate_all()
	worker_ready = false
	_health_due = 0
	status = "Local tactics" if mode == Mode.LOCAL else "Checking local Laya worker…"

func invalidate_all() -> void:
	_mode_generation += 1
	if is_instance_valid(_http): _http.cancel_request()
	_active.clear()
	_queued.clear()
	_next_due.clear()
	_last_choices.clear()
	_was_available = false
	if is_instance_valid(manager): manager.call("clear_tactical_policies")

func invalidate_bot(bot_id: String) -> void:
	_queued.erase(bot_id)
	_next_due.erase(bot_id)
	if is_instance_valid(manager): manager.call("clear_tactical_policy_for", bot_id)
	_last_choices.erase(bot_id)
	if str(_active.get("bot_id", "")) == bot_id:
		_http.cancel_request()
		_active.clear()

func _process(_delta: float) -> void:
	if mode == Mode.LOCAL or not is_instance_valid(manager): return
	var available := bool(manager.call("tactical_requests_available"))
	if not available:
		if _was_available or not _active.is_empty() or not _queued.is_empty(): invalidate_all()
		status = "Local fallback: match inactive, frozen or bots disabled"
		return
	_was_available = true
	var now := Time.get_ticks_msec()
	if not _active.is_empty():
		if now > int(_active.deadline_msec):
			_http.cancel_request()
			if _active.kind == "decision":
				metrics.timeouts += 1
				metrics.stale += 1
				_record("timeout", _active)
				manager.call("clear_tactical_policy_for", str(_active.bot_id))
			else:
				worker_ready = false
				status = "Local fallback: worker health timed out"
			_active.clear()
		return
	if not worker_ready:
		if now >= _health_due:
			_health_due = now + 2000
			_active = {"kind": "health", "deadline_msec": now + REQUEST_TTL_MSEC, "mode_generation": _mode_generation}
			_http.timeout = float(REQUEST_TTL_MSEC) / 1000.0
			var error := _http.request(ENDPOINT + "/health")
			if error != OK: _fail_transport("health request failed")
		return
	var ids: Array = manager.call("tactical_bot_ids")
	for index in ids.size():
		var bot_id := str(ids[index])
		if not _next_due.has(bot_id): _next_due[bot_id] = now + index * (INTERVAL_MSEC / maxi(1, ids.size()))
		if now >= int(_next_due[bot_id]):
			_next_due[bot_id] = now + INTERVAL_MSEC
			_queue_bot(bot_id, now)
	_pump(now)

func _queue_bot(bot_id: String, now: int) -> void:
	var context: Dictionary = manager.call("build_tactical_context", bot_id)
	if context.is_empty(): return
	var request: Dictionary = context.get("request", {})
	var candidates: Array = request.get("candidates", [])
	if candidates.is_empty() or candidates.size() > 6: return
	var wire_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if not candidate is Dictionary or not candidate.get("id") is String or not candidate.get("description") is String: return
		wire_candidates.append({"id": candidate.id, "description": candidate.description})
	_request_serial += 1
	var envelope := {"schema_version": 1, "request_id": _request_serial, "match_epoch": context.match_epoch, "bot_id": bot_id, "life_id": context.life_id, "snapshot_tick": Engine.get_physics_frames(), "snapshot_timestamp_msec": now, "observation": request.get("observation", {}), "candidates": wire_candidates, "local_candidate": request.get("local_candidate", "")}
	if _queued.size() >= MAX_QUEUE and not _queued.has(bot_id): return
	_queued[bot_id] = {"kind": "decision", "wire": envelope, "request": request, "bot_id": bot_id, "created_msec": now, "deadline_msec": now + REQUEST_TTL_MSEC, "mode_generation": _mode_generation, "team": context.get("team", 0)}

func _pump(now: int) -> void:
	if not _active.is_empty() or _queued.is_empty(): return
	var oldest := ""
	var oldest_time := 9223372036854775807
	for bot_id in _queued.keys():
		var queued: Dictionary = _queued[bot_id]
		if now > int(queued.deadline_msec):
			metrics.stale += 1
			_record("queue expired", queued)
			_queued.erase(bot_id)
		elif int(queued.created_msec) < oldest_time:
			oldest = str(bot_id)
			oldest_time = int(queued.created_msec)
	if oldest.is_empty(): return
	_active = _queued[oldest]
	_queued.erase(oldest)
	_http.timeout = maxf(0.05, float(int(_active.deadline_msec) - now) / 1000.0)
	_active.wire["expires_after_ms"] = maxi(1, int(_active.deadline_msec) - now)
	metrics.requested += 1
	var error := _http.request(ENDPOINT + "/decision", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(_active.wire))
	if error != OK: _fail_transport("decision request failed")

func _request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _active.is_empty(): return
	var pending := _active.duplicate(true)
	_active.clear()
	if pending.kind == "decision" and (result == HTTPRequest.RESULT_TIMEOUT or response_code == 408):
		metrics.timeouts += 1
		metrics.stale += 1
		_record("worker deadline exceeded", pending)
		manager.call("clear_tactical_policy_for", str(pending.bot_id))
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail_transport("worker offline or HTTP error", pending)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if pending.kind == "health":
		worker_ready = parsed is Dictionary and parsed.get("ready") == true
		status = "Laya ready: " + str(parsed.get("device", "local")) if worker_ready else "Local fallback: worker not ready"
		if worker_ready: _next_due.clear()
		return
	_accept_response(parsed, pending, Time.get_ticks_msec())

func _accept_response(parsed: Variant, pending: Dictionary, now: int) -> void:
	metrics.completed += 1
	# Include rejected/stale successful responses in latency samples as well.
	var latency := maxf(0.0, float(now - int(pending.created_msec)))
	metrics.latency_total_ms += latency
	metrics.latency_max_ms = maxf(metrics.latency_max_ms, latency)
	metrics.latency_ms.append(latency)
	if metrics.latency_ms.size() > 2048: metrics.latency_ms.pop_front()
	if not is_instance_valid(manager) or mode == Mode.LOCAL or int(pending.mode_generation) != _mode_generation or now > int(pending.deadline_msec) or not bool(manager.call("tactical_context_current", pending.wire)):
		metrics.stale += 1
		_record("stale lifecycle or deadline", pending)
		return
	if not parsed is Dictionary:
		_reject("malformed JSON", pending)
		return
	for key in ["request_id", "match_epoch", "bot_id", "life_id"]:
		if not parsed.has(key) or parsed[key] != pending.wire[key]:
			metrics.stale += 1
			_reject("response identity mismatch", pending)
			return
	var model_version: Variant = parsed.get("model_version", parsed.get("model_id", ""))
	var model_latency: Variant = parsed.get("latency_ms")
	if not model_version is String or model_version.is_empty() or not (model_latency is float or model_latency is int) or not is_finite(float(model_latency)) or float(model_latency) < 0.0:
		_reject("invalid model metadata", pending)
		return
	var selected: Variant = parsed.get("selected_candidate")
	if not selected is String:
		_reject("missing candidate", pending)
		return
	var known := false
	for candidate in pending.wire.candidates:
		if candidate.id == selected: known = true
	if not known:
		_reject("unknown candidate", pending)
		return
	var bot_id := str(pending.bot_id)
	if not bool(manager.call("validate_tactical_response", bot_id, selected, pending.request)):
		_reject("candidate no longer valid", pending)
		return
	metrics.comparisons += 1
	if selected == pending.wire.local_candidate: metrics.agreements += 1
	if _last_choices.has(bot_id) and _last_choices[bot_id] != selected: metrics.action_switches += 1
	_last_choices[bot_id] = selected
	var may_apply := mode == Mode.ENABLED and (enabled_teams.is_empty() or int(pending.team) in enabled_teams)
	if may_apply:
		if bool(manager.call("apply_tactical_response", bot_id, selected, pending.request)):
			metrics.applied += 1
			if selected == "continue_local": metrics.local_delegations += 1
			else: metrics.policy_applied += 1
			if not metrics.applied_actions.has(bot_id): metrics.applied_actions[bot_id] = {}
			metrics.applied_actions[bot_id][selected] = int(metrics.applied_actions[bot_id].get(selected, 0)) + 1
		else:
			_reject("candidate no longer valid", pending)
			return
	_record("applied" if may_apply else "shadow", pending, {"selected_candidate": selected, "local_candidate": pending.wire.local_candidate, "latency_ms": latency, "model_version": parsed.get("model_version", parsed.get("model_id", "")), "confidence": parsed.get("confidence", null)})
	status = "Laya %s: %d decisions, %d applied, %d stale" % ["enabled" if mode == Mode.ENABLED else "shadow", metrics.completed, metrics.applied, metrics.stale]

func _reject(reason: String, pending: Dictionary) -> void:
	metrics.rejected += 1
	_record(reason, pending)
	manager.call("clear_tactical_policy_for", str(pending.bot_id))

func _fail_transport(reason: String, pending: Dictionary = {}) -> void:
	if pending.is_empty(): pending = _active.duplicate(true)
	if pending.get("kind", "") == "decision":
		metrics.offline += 1
		_record(reason, pending)
	_active.clear()
	_queued.clear()
	worker_ready = false
	status = "Local fallback: " + reason
	if is_instance_valid(manager): manager.call("clear_tactical_policies")

func _record(outcome: String, pending: Dictionary, extra: Dictionary = {}) -> void:
	var event := {"outcome": outcome, "mode": mode, "recorded_msec": Time.get_ticks_msec()}
	if pending.has("wire"):
		for key in ["request_id", "match_epoch", "bot_id", "life_id", "local_candidate"]: event[key] = pending.wire[key]
	if pending.has("created_msec"): event["latency_ms"] = maxf(0.0, float(Time.get_ticks_msec() - int(pending.created_msec)))
	if pending.has("request"): event["observation"] = pending.request.get("observation", {}).duplicate(true)
	for key in extra: event[key] = extra[key]
	decision_logged.emit(event.duplicate(true))
	decision_events.append(event)
	if decision_events.size() > MAX_EVENTS: decision_events.pop_front()

func get_metrics() -> Dictionary:
	var result := metrics.duplicate(true)
	result["mode"] = mode
	result["worker_ready"] = worker_ready
	result["status"] = status
	result["queued"] = _queued.size()
	result["inflight"] = not _active.is_empty()
	result["decision_events"] = decision_events.duplicate(true)
	return result

func _exit_tree() -> void:
	if is_instance_valid(_http): _http.cancel_request()
	_queued.clear()
	_active.clear()
