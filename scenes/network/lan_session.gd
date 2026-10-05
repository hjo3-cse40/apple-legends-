extends Node
## One private LAN room. The host alone changes roster and decides match state.
signal roster_changed
signal status_changed(message: String)
signal match_started(players: Array)
signal lobby_returned
signal peer_pose_received(peer_id: int, pose: Dictionary)
signal world_snapshot_received(snapshot: Dictionary)
signal shot_requested(peer_id: int, origin: Vector3, direction: Vector3)
signal shot_result_received(hit: bool)

const PORT := 27777
const VERSION := "apple-legends-lan-3"
const BUILD_VERSION := VERSION
const TEAM_LIMIT := 3
var roster: Array = []
var connected := false
var in_match := false
var status := "Create a private room or join your partner."
var _name := "Player"
var _next_bot := 1
var _poses: Dictionary = {}
var _shot_times: Dictionary = {}
var _pending: Dictionary = {}
var _magazines: Dictionary = {}
var _match_epoch := 0
var _local_generation := 0
var _pose_sequence := 0
var _pose_history: Dictionary = {}
var _last_acknowledged := -1

func set_local_generation(generation: int) -> void:
	_local_generation = generation
	_pose_history.clear()
	_last_acknowledged = -1

# Compare the server result to the position of that exact sent sample, not the
# player's newer live position. Carry a correction into outstanding samples so
# delayed acknowledgements cannot apply the same correction twice.
func reconcile_pose(sequence: int, position: Vector3) -> Vector3:
	if sequence <= _last_acknowledged or not _pose_history.has(sequence):
		return Vector3.ZERO
	var correction: Vector3 = position - _pose_history[sequence]
	if correction.length() <= 0.03:
		correction = Vector3.ZERO
	_last_acknowledged = sequence
	for key in _pose_history.keys():
		if int(key) <= sequence:
			_pose_history.erase(key)
		else:
			_pose_history[key] += correction
	return correction

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func is_host() -> bool:
	return connected and multiplayer.is_server()

func local_peer_id() -> int:
	return multiplayer.get_unique_id() if connected else 0

func host_lobby(player_name: String = "Player") -> Error:
	leave_lobby()
	_name = _clean_name(player_name)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(PORT, 5)
	if result != OK:
		_set_status("Could not host: port %s is unavailable." % PORT)
		return result
	multiplayer.multiplayer_peer = peer
	connected = true
	roster = [_human(1, _name, 1)]
	_set_status("Room open • LAN port %s" % PORT)
	roster_changed.emit()
	return OK

func join_lobby(address: String, player_name: String = "Player") -> Error:
	leave_lobby()
	_name = _clean_name(player_name)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), PORT)
	if result != OK:
		_set_status("Could not connect. Check the host address.")
		return result
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to %s…" % address)
	return OK

func leave_lobby() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	in_match = false
	roster.clear()
	_poses.clear()
	_pending.clear()
	_shot_times.clear()
	_magazines.clear()
	_next_bot = 1
	set_local_generation(0)
	roster_changed.emit()

func choose_team(team: int) -> void:
	if is_host():
		_change_team(1, team)
	elif connected:
		_request_team.rpc_id(1, team)

func set_ready(value: bool) -> void:
	if is_host():
		_change_ready(1, value)
	elif connected:
		_request_ready.rpc_id(1, value)

func add_bot(team: int) -> void:
	if not is_host() or in_match or team not in [1, 2] or team_count(team) >= TEAM_LIMIT:
		return
	roster.append({"id": "bot_%s" % _next_bot, "peer_id": 0, "name": "Robot %s" % _next_bot, "team": team, "bot": true, "ready": true})
	_next_bot += 1
	_publish_roster()

func remove_bot(bot_id: String) -> void:
	if not is_host() or in_match:
		return
	for index in range(roster.size() - 1, -1, -1):
		if roster[index].id == bot_id and roster[index].bot:
			roster.remove_at(index)
	_publish_roster()

func fill_bots() -> void:
	if not is_host() or in_match:
		return
	for team in [1, 2]:
		while team_count(team) < TEAM_LIMIT:
			add_bot(team)

func team_count(team: int) -> int:
	var count := 0
	for entry in roster:
		if entry.team == team:
			count += 1
	return count

func start_match() -> void:
	if not is_host() or in_match:
		return
	if team_count(1) == 0 or team_count(2) == 0:
		_set_status("Add at least one player or robot to each team.")
		return
	for entry in roster:
		if not entry.bot and not entry.ready:
			_set_status("Both players need to be ready.")
			return
	_poses.clear()
	_shot_times.clear()
	_magazines.clear()
	_begin_match.rpc(roster, _match_epoch + 1)

func return_to_lobby() -> void:
	if is_host():
		_end_match.rpc()

func send_local_pose(position: Vector3, yaw: float, pitch: float, alive: bool = true) -> void:
	if not connected or not in_match:
		return
	_pose_sequence += 1
	_pose_history[_pose_sequence] = position
	# A short outage must not grow history indefinitely.
	if _pose_history.size() > 128:
		_pose_history.erase(_pose_history.keys()[0])
	var pose := {"position": position, "yaw": yaw, "pitch": pitch, "alive": alive, "sequence": _pose_sequence, "generation": _local_generation, "epoch": _match_epoch}
	if is_host():
		peer_pose_received.emit(1, pose)
	else:
		_submit_pose.rpc_id(1, pose)

func broadcast_world(snapshot: Dictionary) -> void:
	if is_host() and in_match:
		# Actor dictionaries repeat many keys; compress before unreliable transport
		# so six actors remain below the LAN MTU rather than fragmenting packets.
		snapshot["epoch"] = _match_epoch
		_receive_world.rpc(var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE))

func request_shot(origin: Vector3, direction: Vector3) -> void:
	if not connected or not in_match:
		return
	if is_host():
		if _accept_shot(1):
			shot_requested.emit(1, origin, direction.normalized())
	else:
		_submit_shot.rpc_id(1, origin, direction, _local_generation, _match_epoch)

func reset_peer_pose(peer_id: int, position: Vector3, generation: int = 0) -> void:
	_poses[peer_id] = {"position": position, "time": Time.get_ticks_msec(), "generation": generation, "sequence": -1}
	_shot_times.erase(peer_id)
	_magazines[peer_id] = {"ammo": 12, "reload_end": 0}

func _on_connected() -> void:
	_hello.rpc_id(1, VERSION, _name)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_pending[id] = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if not is_host():
		return
	for id in _pending.keys():
		if Time.get_ticks_msec() - int(_pending[id]) > 5000:
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
			_pending.erase(id)

func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	_pending.erase(id)
	_poses.erase(id)
	for index in range(roster.size() - 1, -1, -1):
		if roster[index].peer_id == id:
			roster.remove_at(index)
	if in_match:
		_end_match.rpc()
	_publish_roster()
	_set_status("Player disconnected. Room remains open.")

func _on_connection_failed() -> void:
	leave_lobby()
	_set_status("Connection failed. Check Wi-Fi, host address and local network permission.")

func _on_server_disconnected() -> void:
	leave_lobby()
	_set_status("Host disconnected.")
	lobby_returned.emit()

@rpc("any_peer", "call_remote", "reliable")
func _hello(version: String, player_name: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != VERSION:
		_rejected.rpc_id(id, "Different game version. AirDrop the host's latest build.")
		return
	if in_match:
		_rejected.rpc_id(id, "The round has already started. Join when the host returns to the lobby.")
		return
	if _entry(id) != null:
		return
	_pending.erase(id)
	var human_counts := {1: 0, 2: 0}
	for entry in roster:
		if not entry.bot:
			human_counts[int(entry.team)] += 1
	var preferred := 1 if int(human_counts[1]) <= int(human_counts[2]) else 2
	var team := 0
	for candidate in [preferred, 3 - preferred]:
		if team_count(candidate) < TEAM_LIMIT:
			team = candidate
			break
	# Prefer an empty seat; only replace robots when all six seats are filled.
	for candidate in ([preferred, 3 - preferred] if team == 0 else []):
		for index in range(roster.size() - 1, -1, -1):
			if roster[index].bot and int(roster[index].team) == candidate:
				roster.remove_at(index)
				team = candidate
				break
		if team != 0:
			break
	if team == 0:
		_rejected.rpc_id(id, "Room is full: six human players are already connected.")
		return
	roster.append(_human(id, _clean_name(player_name), team))
	_publish_roster()

@rpc("authority", "call_remote", "reliable")
func _rejected(message: String) -> void:
	leave_lobby()
	_set_status(message)

@rpc("authority", "call_local", "reliable")
func _receive_roster(players: Array) -> void:
	connected = true
	roster = players.duplicate(true)
	roster_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func _request_team(team: int) -> void:
	if is_host():
		_change_team(multiplayer.get_remote_sender_id(), team)

@rpc("any_peer", "call_remote", "reliable")
func _request_ready(value: bool) -> void:
	if is_host():
		_change_ready(multiplayer.get_remote_sender_id(), value)

func _change_team(id: int, team: int) -> void:
	if in_match or team not in [1, 2]:
		return
	var entry: Variant = _entry(id)
	if entry == null or entry.team == team or team_count(team) >= TEAM_LIMIT:
		return
	entry.team = team
	entry.ready = false
	_publish_roster()

func _change_ready(id: int, value: bool) -> void:
	if in_match:
		return
	var entry: Variant = _entry(id)
	if entry != null:
		entry.ready = value
		_publish_roster()

@rpc("authority", "call_local", "reliable")
func _begin_match(players: Array, epoch: int) -> void:
	_match_epoch = epoch
	roster = players.duplicate(true)
	in_match = true
	set_local_generation(0)
	match_started.emit(roster)

@rpc("authority", "call_local", "reliable")
func _end_match() -> void:
	in_match = false
	for entry in roster:
		if not entry.bot:
			entry.ready = false
	lobby_returned.emit()
	roster_changed.emit()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_pose(pose: Dictionary) -> void:
	if not is_host() or not in_match:
		return
	var id := multiplayer.get_remote_sender_id()
	if _entry(id) == null or not pose.get("position") is Vector3 or int(pose.get("epoch", -1)) != _match_epoch:
		return
	if not pose.get("sequence") is int or not pose.get("generation") is int:
		return
	var position: Vector3 = pose.position
	var yaw := float(pose.get("yaw", 0.0))
	var pitch := float(pose.get("pitch", 0.0))
	if not position.is_finite() or not is_finite(yaw) or not is_finite(pitch) or absf(position.x) > 100.0 or absf(position.z) > 130.0 or position.y < -20.0 or position.y > 60.0:
		return
	var now := Time.get_ticks_msec()
	if _poses.has(id):
		var previous: Dictionary = _poses[id]
		if int(pose.get("generation", -1)) != int(previous.get("generation", 0)) or int(pose.get("sequence", -1)) <= int(previous.get("sequence", -1)):
			return
		var elapsed := clampf(float(now - int(previous.time)) / 1000.0, 0.0, 1.0)
		if position.distance_to(previous.position) > 32.0 * elapsed + 1.5:
			return
	_poses[id] = {"position": position, "time": now, "yaw": yaw, "pitch": pitch, "generation": int(pose.generation), "sequence": int(pose.sequence)}
	peer_pose_received.emit(id, {"position": position, "yaw": yaw, "pitch": clampf(pitch, -1.56, 1.56), "alive": bool(pose.get("alive", true)), "sequence": int(pose.sequence), "generation": int(pose.generation)})

@rpc("any_peer", "call_remote", "reliable")
func _submit_shot(origin: Vector3, direction: Vector3, generation: int = -1, epoch: int = -1) -> void:
	if not is_host() or not in_match or epoch != _match_epoch:
		return
	var id := multiplayer.get_remote_sender_id()
	if _entry(id) == null or not _poses.has(id) or not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.5:
		return
	if generation != int(_poses[id].get("generation", 0)):
		return
	if origin.distance_to(_poses[id].position + Vector3.UP * 1.62) > 2.0:
		return
	if _accept_shot(id):
		shot_requested.emit(id, origin, direction.normalized())

func _accept_shot(id: int) -> bool:
	var now := Time.get_ticks_msec()
	var mag: Dictionary = _magazines.get(id, {"ammo": 12, "reload_end": 0})
	if int(mag.reload_end) > 0:
		if now < int(mag.reload_end):
			return false
		mag.ammo = 12
		mag.reload_end = 0
	if now - int(_shot_times.get(id, -1000)) < 205 or int(mag.ammo) <= 0:
		return false
	mag.ammo -= 1
	_magazines[id] = mag
	_shot_times[id] = now
	return true

func request_reload() -> void:
	if not connected or not in_match:
		return
	if is_host():
		_begin_peer_reload(1)
	else:
		_submit_reload.rpc_id(1, _local_generation, _match_epoch)

@rpc("any_peer", "call_remote", "reliable")
func _submit_reload(generation: int, epoch: int) -> void:
	if is_host() and in_match and epoch == _match_epoch and generation == int(_poses.get(multiplayer.get_remote_sender_id(), {}).get("generation", -1)):
		_begin_peer_reload(multiplayer.get_remote_sender_id())

func _begin_peer_reload(id: int) -> void:
	if _entry(id) == null:
		return
	var mag: Dictionary = _magazines.get(id, {"ammo": 12, "reload_end": 0})
	if int(mag.ammo) < 12 and int(mag.reload_end) == 0:
		mag.reload_end = Time.get_ticks_msec() + 1150
		_magazines[id] = mag

func send_shot_result(peer_id: int, hit: bool) -> void:
	if not is_host():
		return
	if peer_id == 1:
		shot_result_received.emit(hit)
	else:
		_receive_shot_result.rpc_id(peer_id, hit)

@rpc("authority", "call_remote", "reliable")
func _receive_shot_result(hit: bool) -> void:
	shot_result_received.emit(hit)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_world(payload: PackedByteArray) -> void:
	if not in_match or payload.size() > 65536:
		return
	var decoded := payload.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
	if decoded.is_empty():
		return
	var snapshot: Variant = bytes_to_var(decoded)
	if snapshot is Dictionary and int(snapshot.get("epoch", -1)) == _match_epoch:
		world_snapshot_received.emit(snapshot)

func _publish_roster() -> void:
	_receive_roster.rpc(roster)

func _entry(id: int) -> Variant:
	for entry in roster:
		if not entry.bot and entry.peer_id == id:
			return entry
	return null

func _human(id: int, player_name: String, team: int) -> Dictionary:
	return {"id": "peer_%s" % id, "peer_id": id, "name": player_name, "team": team, "bot": false, "ready": false}

func _clean_name(value: String) -> String:
	var cleaned := value.strip_edges().left(24)
	return cleaned if not cleaned.is_empty() else "Player"

func _set_status(message: String) -> void:
	status = message
	status_changed.emit(message)
