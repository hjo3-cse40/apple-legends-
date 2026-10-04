class_name KothManager
extends DuelManager
## Offline objective coordinator. Duel health/respawn plumbing remains reusable.

const Rules = preload("res://scenes/koth/koth_rules.gd")
const PARTICIPANT_GROUP := &"koth_participant"

@export var capture_seconds := 12.0
@export var hold_seconds := 180.0
@export var unlock_seconds := 15.0
@export var point_height_tolerance := 0.45

var rules: KothRules = Rules.new()
var objective_audio: ObjectiveAudio
var cyan_count := 0
var amber_count := 0
var point_position := Vector3.ZERO
var point_radius := 3.0
var _objective_configured := false
var _koth_hud: Node
var _respawn_sequence := 0
var _saved_process_states: Dictionary = {}

func _ready() -> void:
	respawn_delay = 3.0
	super._ready()
	rules.capture_duration = capture_seconds
	rules.round_duration = hold_seconds
	rules.unlock_duration = unlock_seconds
	objective_audio = ObjectiveAudio.new()
	objective_audio.name = "ObjectiveAudio"
	add_child(objective_audio)
	rules.point_captured.connect(objective_audio.point_captured)
	rules.match_finished.connect(_on_objective_finished)
	rules.reset_match()
	objective_audio.reset_round(rules.get_snapshot())
	_register_participant(player, Rules.CYAN)
	_register_participant(bot, Rules.AMBER)

func configure_objective(position: Vector3, radius: float) -> void:
	point_position = position
	point_radius = maxf(radius, 0.1)
	_objective_configured = true
	_koth_hud = get_parent().get_node_or_null("KothHUD")
	if _koth_hud is KothHUD:
		objective_audio.cue_requested.connect((_koth_hud as KothHUD).show_announcement)
	if bot.has_method(&"configure_objective"):
		bot.call(&"configure_objective", point_position, get_parent())
	_publish_state()

func _register_participant(participant: Node, team: int) -> void:
	participant.set_meta(&"koth_team", team)
	participant.add_to_group(PARTICIPANT_GROUP)

func _physics_process(delta: float) -> void:
	if not _objective_configured or match_over:
		return
	if not player.is_alive and not player_respawn_timer.is_stopped():
		hud.show_respawn_message(player_respawn_timer.time_left)
	_update_occupancy()
	rules.advance(delta, cyan_count, amber_count)
	objective_audio.observe(rules.get_snapshot(), delta)
	_publish_state()

func _update_occupancy() -> void:
	cyan_count = 0
	amber_count = 0
	for participant in get_tree().get_nodes_in_group(PARTICIPANT_GROUP):
		if not participant is CharacterBody3D:
			continue
		var body := participant as CharacterBody3D
		if not bool(body.get("is_alive")) or not body.is_on_floor():
			continue
		var offset := body.global_position - point_position
		if absf(offset.y) > point_height_tolerance or Vector2(offset.x, offset.z).length_squared() > point_radius * point_radius:
			continue
		var team := int(body.get_meta(&"koth_team", Rules.NEUTRAL))
		if team == Rules.CYAN:
			cyan_count += 1
		elif team == Rules.AMBER:
			amber_count += 1

func _on_player_died() -> void:
	if match_over:
		return
	_respawn_sequence += 1
	player_respawn_timer.start()
	hud.show_respawn_message(respawn_delay)
	_publish_state()

func _on_bot_died() -> void:
	if match_over:
		return
	_respawn_sequence += 1
	bot_respawn_timer.start()
	_publish_state()

func _respawn_player() -> void:
	if match_over:
		return
	player.respawn_at(_spawn_transform(_player_spawns, _respawn_sequence))
	hud.hide_transient_message()

func _respawn_bot() -> void:
	if match_over:
		return
	bot.call(&"respawn_at", _spawn_transform(_bot_spawns, _respawn_sequence))
	bot.call(&"set_target", player)

func _publish_state() -> void:
	if get_parent().has_method(&"set_objective_visual"):
		get_parent().call(&"set_objective_visual", rules.get_snapshot())
	if is_instance_valid(_koth_hud) and _koth_hud.has_method(&"set_koth_state"):
		_koth_hud.call(&"set_koth_state", rules.get_snapshot(), cyan_count, amber_count)

func _on_objective_finished(team: int) -> void:
	_finish_match(team == Rules.CYAN)

func _finish_match(player_won: bool) -> void:
	if match_over:
		return
	super._finish_match(player_won)
	hud.hide_transient_message()
	player.velocity = Vector3.ZERO
	bot.set("velocity", Vector3.ZERO)
	var bot_flash := bot.get_node_or_null("Visuals/MuzzleFlash") as Node3D
	if bot_flash != null:
		bot_flash.hide()
	player.weapon.cancel_pending_input()
	for actor in [player, bot, player.weapon]:
		_saved_process_states[actor.get_instance_id()] = {
			"physics": actor.is_physics_processing(), "process": actor.is_processing(),
			"input": actor.is_processing_input(), "unhandled": actor.is_processing_unhandled_input(),
		}
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.set_process_input(false)
		actor.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_publish_state()

func restart_match() -> void:
	player_respawn_timer.stop()
	bot_respawn_timer.stop()
	for actor in [player, bot, player.weapon]:
		var saved: Dictionary = _saved_process_states.get(actor.get_instance_id(), {})
		if saved.is_empty():
			continue
		actor.set_physics_process(bool(saved.physics))
		actor.set_process(bool(saved.process))
		actor.set_process_input(bool(saved.input))
		actor.set_process_unhandled_input(bool(saved.unhandled))
	_saved_process_states.clear()
	if _koth_hud is KothHUD:
		(_koth_hud as KothHUD).clear_announcement()
	# The arena's F1 preference remains authoritative across round restarts.
	var arena := get_parent()
	if "opponent_paused" in arena:
		bot.set_physics_process(not bool(arena.get("opponent_paused")))
	match_over = false
	player_score = 0
	bot_score = 0
	_respawn_sequence = 0
	cyan_count = 0
	amber_count = 0
	rules.reset_match()
	objective_audio.reset_round(rules.get_snapshot())
	_respawn_player()
	_respawn_bot()
	hud.hide_transient_message()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_publish_state()
