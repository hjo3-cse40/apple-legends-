class_name TeamMatchManager
extends KothManager
## LAN round coordinator: host simulates AI, health, respawns and objective rules.
const BOT_SCENE := preload("res://scenes/bots/duel_bot.tscn")
const ROBOT_SCENE := preload("res://art/calibration/MiniBot.glb")
const RemoteActor = preload("res://scenes/network/remote_actor.gd")
@onready var session: Node = get_node("/root/LanSession")
var actors: Dictionary = {}
var entries: Dictionary = {}
var respawn_remaining: Dictionary = {}
var spawn_generations: Dictionary = {}
var shot_serials: Dictionary = {}
var local_id := ""
var bots_frozen := false
var bots_enabled := true
var _network_elapsed := 0.0
var _configured := false
var _last_owner := 0
var _round_generation := 0

func _ready() -> void:
	# Deliberately bypass duel-only wiring; all roster members use one lifecycle.
	respawn_delay = 3.0
	rules.capture_duration = capture_seconds
	rules.round_duration = hold_seconds
	rules.unlock_duration = unlock_seconds
	objective_audio = ObjectiveAudio.new()
	objective_audio.name = "ObjectiveAudio"
	add_child(objective_audio)
	rules.point_captured.connect(objective_audio.point_captured)
	rules.reset_match()
	objective_audio.reset_round(rules.get_snapshot())
	session.peer_pose_received.connect(_receive_pose)
	session.world_snapshot_received.connect(_receive_world)
	session.shot_requested.connect(_receive_shot)

func configure_objective(position: Vector3, radius: float) -> void:
	point_position = position
	point_radius = radius
	_koth_hud = get_parent().get_node("KothHUD")
	objective_audio.cue_requested.connect((_koth_hud as KothHUD).show_announcement)
	_build_roster()
	_configured = true
	_publish_state()

func _build_roster() -> void:
	var original_used := false
	var slots := {1: 0, 2: 0}
	for entry in session.roster:
		var id: String = entry.id
		var actor: Node3D
		entries[id] = entry.duplicate(true)
		entries[id]["slot"] = slots[int(entry.team)]
		slots[int(entry.team)] += 1
		if not entry.bot and int(entry.peer_id) == session.local_peer_id():
			actor = player
			local_id = id
		elif entry.bot and session.is_host():
			if not original_used:
				actor = bot
				original_used = true
			else:
				actor = BOT_SCENE.instantiate()
				actor.name = id
				get_parent().add_child(actor)
				_style_bot(actor, int(entry.team))
		else:
			actor = RemoteActor.new()
			actor.name = id
			get_parent().add_child(actor)
		actor.set("team_id", int(entry.team))
		if actor is RemoteActor:
			actor.set_team(int(entry.team))
			actor.interpolate = not session.is_host()
		actor.set_meta("koth_team", int(entry.team))
		actor.set_meta("display_name", str(entry.name))
		actors[id] = actor
		spawn_generations[id] = 0
		shot_serials[id] = 0
		actor.call("respawn_at", _roster_spawn(id))
		if session.is_host():
			actor.connect("died", _actor_died.bind(id))
			if actor == player:
				player.damaged_from.connect(func(source: Vector3): player.set_meta("last_damage_source", source))
			if not entry.bot:
				session.reset_peer_pose(int(entry.peer_id), actor.global_position)
	if not original_used:
		bot.hide()
		bot.set_physics_process(false)
		bot.get_node("CollisionShape3D").set_deferred("disabled", true)
		bot.get_node("CharacterAudio").set_process(false)
	for id in actors:
		var actor: Node3D = actors[id]
		if actor is DuelBot:
			actor.movement_enabled = true
			_set_bot_accent(actor, int(actor.team_id))
			actor.configure_objective(point_position, get_parent())
			actor.configure_combatants(_actor_array(), int(entries[id].slot))
			actor.shot_fired.connect(_bot_shot.bind(id))
	(_koth_hud as KothHUD).local_team = player.team_id
	player.weapon.shot_dispatcher = session.request_shot
	player.weapon.reload_dispatcher = session.request_reload
	session.shot_result_received.connect(_shot_result)
	var labels := preload("res://scenes/match/team_health_hud.gd").new()
	labels.player = player
	labels.actors = _actor_array()
	add_child(labels)

func _style_bot(actor: Node3D, team: int) -> void:
	for part in ["Body", "Visor", "Rifle"]:
		actor.get_node("Visuals/" + part).hide()
	var model := ROBOT_SCENE.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.06
	actor.get_node("Visuals").add_child(model)
	var tint := Color("64e4ee") if team == 1 else Color("ffae4f")
	for part in ["Eye", "Eye_001", "ChestIndicator", "BotWeaponPower"]:
		var mesh := model.find_child(part, true, false) as MeshInstance3D
		if mesh:
			var material := StandardMaterial3D.new()
			material.albedo_color = tint
			material.emission_enabled = true
			material.emission = tint
			mesh.material_override = material

func _actor_array() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor in actors.values():
		result.append(actor)
	return result

func _roster_spawn(id: String) -> Transform3D:
	var entry: Dictionary = entries[id]
	var prefix := "CYAN" if int(entry.team) == 1 else "AMBER"
	var source := get_parent().arena.find_child("%s_SPAWN_%d*" % [prefix, int(entry.slot) + 1], true, false) as Node3D
	var result := Transform3D(Basis(Vector3.UP, PI if int(entry.team) == 2 else 0.0), source.global_position + Vector3.UP * 0.12)
	return result

func _physics_process(delta: float) -> void:
	if not _configured:
		return
	_network_elapsed += delta
	if _network_elapsed >= 0.05:
		_network_elapsed = 0.0
		session.send_local_pose(player.global_position, player.rotation.y, player.camera_pivot.rotation.x, player.is_alive)
		if session.is_host():
			session.broadcast_world(_world_snapshot())
	if not session.is_host() or match_over:
		return
	for id in respawn_remaining.keys():
		respawn_remaining[id] -= delta
		if id == local_id:
			hud.show_respawn_message(maxf(0.0, respawn_remaining[id]))
		if respawn_remaining[id] <= 0.0:
			_respawn_actor(id)
	for id in actors:
		var actor: Node3D = actors[id]
		if actor.global_position.y < -20.0 and bool(actor.get("is_alive")):
			_respawn_actor(id)
		if actor is DuelBot:
			actor.set_tactical_context(rules.owner_team, rules.contested)
	_update_occupancy()
	rules.advance(delta, cyan_count, amber_count)
	objective_audio.observe(rules.get_snapshot(), delta)
	if rules.match_over:
		match_over = true
		_stop_round()
	_publish_state()

func _update_occupancy() -> void:
	cyan_count = 0
	amber_count = 0
	for id in actors:
		var actor: CharacterBody3D = actors[id]
		if not bool(actor.get("is_alive")) or (bool(entries[id].bot) and not bots_enabled):
			continue
		var offset := actor.global_position - point_position
		# Remote poses are collision-swept on the host. Floor proximity excludes jumps.
		if absf(offset.y) > point_height_tolerance or Vector2(offset.x, offset.z).length_squared() > point_radius * point_radius:
			continue
		if not actor.is_on_floor() and not bool(actor.get_meta("network_grounded", false)):
			continue
		if int(entries[id].team) == 1:
			cyan_count += 1
		else:
			amber_count += 1

func _actor_died(id: String) -> void:
	if not match_over:
		respawn_remaining[id] = respawn_delay

func _respawn_actor(id: String) -> void:
	respawn_remaining.erase(id)
	var actor: Node3D = actors[id]
	actor.call("respawn_at", _roster_spawn(id))
	spawn_generations[id] = int(spawn_generations[id]) + 1
	var entry: Dictionary = entries[id]
	if entry.bot:
		actor.set_meta("combat_enabled", bots_enabled)
		actor.visible = bots_enabled
		actor.get_node("CollisionShape3D").set_deferred("disabled", not bots_enabled)
		actor.set_physics_process(bots_enabled and not bots_frozen and not match_over)
	if not entry.bot:
		session.reset_peer_pose(int(entry.peer_id), actor.global_position)
	if id == local_id:
		hud.hide_transient_message()

func _receive_pose(peer_id: int, pose: Dictionary) -> void:
	if not _configured or not session.is_host() or match_over:
		return
	var id := "peer_%d" % peer_id
	if not actors.has(id) or id == local_id:
		return
	var actor: CharacterBody3D = actors[id]
	if not bool(actor.get("is_alive")):
		return
	# Sweep rather than directly trust a pose that could move through cover.
	var motion: Vector3 = pose.position - actor.global_position
	var previous_position := actor.global_position
	actor.move_and_collide(motion)
	actor.rotation.y = float(pose.yaw)
	var ground_query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.08, actor.global_position - Vector3.UP * 0.16)
	ground_query.exclude = [actor.get_rid()]
	var ground := actor.get_world_3d().direct_space_state.intersect_ray(ground_query)
	actor.set_meta("network_grounded", not ground.is_empty() and ground.collider is StaticBody3D and ground.normal.y > 0.7 and actor.global_position.y <= previous_position.y + 0.02)
	actor.set_meta("pitch", float(pose.pitch))

func _receive_shot(peer_id: int, origin: Vector3, direction: Vector3) -> void:
	if not _configured or not session.is_host() or match_over:
		return
	var id := "peer_%d" % peer_id
	if not actors.has(id):
		return
	var shooter: CollisionObject3D = actors[id]
	if origin.distance_to(shooter.global_position + Vector3.UP * 1.62) > 2.0:
		return
	if not bool(shooter.get("is_alive")):
		return
	shot_serials[id] = int(shot_serials[id]) + 1
	if shooter is RemoteActor:
		shooter.show_shot()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * player.weapon.maximum_range)
	query.exclude = [shooter.get_rid()]
	var hit: Dictionary = get_parent().get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target: Node = hit.collider
	if target.has_method("apply_damage") and target.get("team_id") != shooter.get("team_id"):
		if bool(target.call("apply_damage", player.weapon.damage, shooter.global_position)):
			session.send_shot_result(peer_id, true)

func _world_snapshot() -> Dictionary:
	var states: Dictionary = {}
	for id in actors:
		var actor: Node3D = actors[id]
		states[id] = {"position": actor.global_position, "yaw": actor.rotation.y + (PI if actor is DuelBot else 0.0), "shot_serial": int(shot_serials[id]), "damage_source": actor.get_meta("last_damage_source", Vector3.ZERO), "health": float(actor.get("current_health")), "generation": int(spawn_generations[id]), "enabled": not bool(entries[id].bot) or bots_enabled, "grounded": actor.is_on_floor() or bool(actor.get_meta("network_grounded", false)), "respawn": float(respawn_remaining.get(id, 0.0))}
	return {"actors": states, "rules": rules.get_snapshot(), "cyan_count": cyan_count, "amber_count": amber_count, "round": _round_generation, "bots_frozen": bots_frozen}

func _receive_world(snapshot: Dictionary) -> void:
	if not _configured or session.is_host():
		return
	var states: Dictionary = snapshot.get("actors", {})
	for id in actors:
		if not states.has(id):
			continue
		var state: Dictionary = states[id]
		var actor: Node3D = actors[id]
		var generation := int(state.generation)
		if id == local_id:
			if generation != int(spawn_generations[id]):
				player.respawn_at(Transform3D(Basis(Vector3.UP, float(state.yaw)), state.position))
				spawn_generations[id] = generation
			if player.is_alive and player.global_position.distance_to(state.position) > 1.5:
				player.global_position = state.position
			if float(state.health) < player.current_health and state.get("damage_source") is Vector3:
				player.damaged_from.emit(state.damage_source)
			player.apply_network_health(float(state.health))
			if float(state.respawn) > 0.0:
				hud.show_respawn_message(float(state.respawn))
			else:
				hud.hide_transient_message()
		else:
			actor.call("apply_snapshot", state)
			actor.visible = bool(state.get("enabled", true))
	var snapshot_rules: Dictionary = snapshot.rules
	if int(snapshot_rules.owner_team) != _last_owner and int(snapshot_rules.owner_team) != 0:
		objective_audio.point_captured(int(snapshot_rules.owner_team))
	_last_owner = int(snapshot_rules.owner_team)
	objective_audio.observe(snapshot_rules, 0.05)
	get_parent().set_objective_visual(snapshot_rules)
	(_koth_hud as KothHUD).set_koth_state(snapshot_rules, int(snapshot.cyan_count), int(snapshot.amber_count))
	if int(snapshot.get("round", 0)) != _round_generation:
		_round_generation = int(snapshot.round)
		objective_audio.reset_round(snapshot_rules)
		(_koth_hud as KothHUD).clear_announcement()
		for actor in actors.values():
			actor.set_physics_process(true)
		player.weapon.set_physics_process(true)
		var settings := get_parent().get_node_or_null("SettingsMenu")
		if settings == null or not settings.is_open:
			player._capture_mouse()
	match_over = bool(snapshot_rules.match_over)
	if match_over:
		_stop_round()

func _stop_round() -> void:
	for actor in actors.values():
		actor.velocity = Vector3.ZERO
		actor.set_physics_process(false)
	player.weapon.cancel_pending_input()
	player.weapon.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func restart_match() -> void:
	if not session.is_host():
		return
	match_over = false
	_round_generation += 1
	respawn_remaining.clear()
	rules.reset_match()
	objective_audio.reset_round(rules.get_snapshot())
	(_koth_hud as KothHUD).clear_announcement()
	for id in actors:
		_respawn_actor(id)
		actors[id].set_physics_process(true)
	player.weapon.set_physics_process(true)
	set_bots_frozen(bots_frozen)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_publish_state()

func _unhandled_input(event: InputEvent) -> void:
	if match_over and event.is_action_pressed("ui_accept"):
		restart_match()
		get_viewport().set_input_as_handled()

func set_bots_frozen(value: bool) -> void:
	if not session.is_host():
		return
	bots_frozen = value
	get_parent().opponent_paused = value
	for actor in actors.values():
		if actor is DuelBot:
			actor.set_physics_process(bots_enabled and not value and not match_over)
			actor.velocity = Vector3.ZERO
			actor.get_node("Visuals/MuzzleFlash").hide()

func dev_action(action: String, team: int = 0) -> void:
	if action == "return_lobby":
		if session.is_host():
			session.return_to_lobby()
		else:
			session.leave_lobby()
			session.lobby_returned.emit()
		return
	if not session.is_host():
		return
	match action:
		"restart": restart_match()
		"freeze": set_bots_frozen(true)
		"unfreeze": set_bots_frozen(false)
		"bots_on", "bots_off":
			bots_enabled = action == "bots_on"
			for id in actors:
				if entries[id].bot:
					actors[id].set_meta("combat_enabled", bots_enabled)
					actors[id].visible = bots_enabled
					actors[id].get_node("CollisionShape3D").set_deferred("disabled", not bots_enabled or not bool(actors[id].get("is_alive")))
			set_bots_frozen(bots_frozen)
		"add_bot", "remove_bot":
			# Roster edits happen in the lobby; returning retains both human connections.
			session.return_to_lobby()
			if action == "add_bot":
				session.add_bot(team)
			else:
				for entry in session.roster:
					if entry.bot and int(entry.team) == team:
						session.remove_bot(str(entry.id))
						break

func _shot_result(hit: bool) -> void:
	if hit:
		player.weapon.hit_confirmed.emit()

func _set_bot_accent(actor: Node3D, team: int) -> void:
	var tint := Color("64e4ee") if team == 1 else Color("ffae4f")
	for part in ["Eye", "Eye_001", "ChestIndicator", "BotWeaponPower"]:
		var mesh := actor.find_child(part, true, false) as MeshInstance3D
		if mesh:
			var material := StandardMaterial3D.new()
			material.albedo_color = tint
			material.emission_enabled = true
			material.emission = tint
			mesh.material_override = material

func _bot_shot(_target: Node3D, id: String) -> void:
	shot_serials[id] = int(shot_serials[id]) + 1
