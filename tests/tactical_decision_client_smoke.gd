extends SceneTree
class FakeManager:
	extends Node
	var epoch := 5
	var life := 2
	var available := true
	var applied := 0
	var cleared := 0
	var valid_action := true
	func tactical_requests_available() -> bool: return available
	func tactical_bot_ids() -> Array: return ["bot_a"]
	func clear_tactical_policies() -> void: cleared += 1
	func clear_tactical_policy_for(_id: String) -> void: cleared += 1
	func build_tactical_context(_id: String) -> Dictionary:
		return {"match_epoch": epoch, "life_id": life, "team": 1, "request": {"observation": {"health": 40}, "candidates": [{"id": "advance", "description": "Reach objective"}, {"id": "cover", "description": "Reload safely"}], "local_candidate": "advance", "_bindings": {"cover": Vector3(10, 0, 0)}, "_guard": {"life": life}}}
	func tactical_context_current(wire: Dictionary) -> bool: return available and int(wire.match_epoch) == epoch and int(wire.life_id) == life
	func validate_tactical_response(_id: String, _candidate: String, _request: Dictionary) -> bool: return valid_action
	func apply_tactical_response(_id: String, _candidate: String, _request: Dictionary) -> bool:
		if not valid_action: return false
		applied += 1
		return true
var failures: Array[String] = []
var owner_manager: FakeManager
var client: TacticalDecisionClient
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func pending() -> Dictionary:
	client._queue_bot("bot_a", Time.get_ticks_msec())
	var request: Dictionary = client._queued["bot_a"].duplicate(true)
	client._queued.clear()
	return request
func reply(request: Dictionary) -> Dictionary:
	var response: Dictionary = request.wire.duplicate(true)
	response.selected_candidate = "cover"
	response.latency_ms = 12.0
	response.model_version = "fault-fixture-only"
	response.confidence = 0.7
	return response
func response_status_check(request: Dictionary) -> void:
	client._record("applied", request)
	check(client.status.contains("1 policies, 0 local"), "Enabled status distinguishes actual nonlocal policy from local delegation")
func run() -> void:
	owner_manager = FakeManager.new()
	root.add_child(owner_manager)
	client = TacticalDecisionClient.new()
	root.add_child(client)
	client.configure(owner_manager)
	client.set_process(false)
	client.set_mode(TacticalDecisionClient.Mode.SHADOW)
	var request := pending()
	check(not request.wire.has("_guard") and not request.wire.has("_bindings") and request.request.has("_bindings"), "Only public observation/candidates reach HTTP; local bindings retained")
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(client.metrics.completed == 1 and client.metrics.applied == 0 and client.metrics.comparisons == 1 and client.metrics.agreements == 0, "Shadow records model choice without action")
	client.set_mode(TacticalDecisionClient.Mode.ENABLED)
	request = pending()
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(owner_manager.applied == 1 and client.metrics.applied == 1, "Enabled applies a current valid action")
	client.worker_ready = true
	request = pending()
	response_status_check(request)
	request = pending()
	client._accept_response(null, request, Time.get_ticks_msec())
	check(client.metrics.rejected == 1 and owner_manager.applied == 1, "Malformed JSON rejected")
	request = pending()
	var response := reply(request)
	response.selected_candidate = "teleport"
	client._accept_response(response, request, Time.get_ticks_msec())
	check(client.metrics.rejected == 2 and owner_manager.applied == 1, "Unknown candidate rejected")
	request = pending()
	response = reply(request)
	response.request_id = int(response.request_id) - 1
	client._accept_response(response, request, Time.get_ticks_msec())
	check(client.metrics.stale == 1 and owner_manager.applied == 1, "Out-of-order identity rejected")
	request = pending()
	owner_manager.life += 1
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(client.metrics.stale == 2, "Previous life rejected")
	request = pending()
	client._accept_response(reply(request), request, int(request.deadline_msec) + 1)
	check(client.metrics.stale == 3, "Real monotonic expiry rejected without simulation dependence")
	request = pending()
	owner_manager.valid_action = false
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(client.metrics.rejected == 4 and owner_manager.applied == 1, "Action becoming unsafe rejected by bot revalidation")
	owner_manager.valid_action = true
	request = pending()
	client.set_mode(TacticalDecisionClient.Mode.LOCAL)
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(client.metrics.stale == 4 and owner_manager.applied == 1 and client._queued.is_empty(), "Mode switch clears queue and rejects late response")
	client.set_mode(TacticalDecisionClient.Mode.ENABLED)
	request = pending()
	client._active = request
	client._request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	check(client.metrics.offline == 1 and not client.worker_ready and client._active.is_empty(), "Offline worker clears actions and uses local fallback")
	request = pending()
	owner_manager.available = false
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(client.metrics.stale == 5, "Lobby/freeze/unavailable match rejects late result")
	owner_manager.available = true
	request = pending()
	client._active = request
	client.invalidate_bot("bot_a")
	check(client._active.is_empty() and client._queued.is_empty(), "Death/respawn cancels active bot request")
	for index in 10: client._queue_bot("bot_a", Time.get_ticks_msec())
	check(client._queued.size() == 1, "Latest-only per-bot queue remains bounded")
	# A timeout uses local fallback while retaining an otherwise healthy worker.
	client.worker_ready = true
	request = pending()
	client._active = request
	client._request_completed(HTTPRequest.RESULT_SUCCESS, 408, [], PackedByteArray())
	check(client.metrics.timeouts == 1 and client.worker_ready, "Service deadline response clears policy without labeling service offline")
	# Shadow must validate unsafe candidates without applying them.
	client.set_mode(TacticalDecisionClient.Mode.SHADOW)
	owner_manager.valid_action = false
	request = pending()
	var rejected_before := int(client.metrics.rejected)
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(client.metrics.rejected == rejected_before + 1 and owner_manager.applied == 1, "Shadow also revalidates candidate safety")
	owner_manager.valid_action = true
	client.set_mode(TacticalDecisionClient.Mode.ENABLED)
	client.enabled_teams.assign([2])
	request = pending()
	client._accept_response(reply(request), request, Time.get_ticks_msec())
	check(owner_manager.applied == 1, "Mixed-team enabled filter keeps excluded team in shadow")
	check(client.metrics.latency_ms.size() == client.metrics.completed, "Latency samples include every successful HTTP response, including rejected or stale decisions")
	for event in client.decision_events:
		check(event.has("latency_ms"), "Fault decision events retain end-to-end latency for full-run traces")
	client.queue_free()
	owner_manager.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("TACTICAL_CLIENT_PASS: wire privacy, shadow/enabled, malformed/invalid/out-of-order, old life, realtime expiry, bot revalidation, mode/lobby/reset, worker offline, latest-only queue, team filter")
	quit(0 if failures.is_empty() else 1)
