class_name DuelManager
extends Node

signal score_changed(player_score: int, bot_score: int, target_score: int)
signal match_finished(player_won: bool)

@export_range(1, 20, 1) var target_score: int = 5
@export_range(0.1, 10.0, 0.1) var respawn_delay: float = 0.8

@onready var player: FirstPersonPlayer = %Player
@onready var bot: Node3D = %DuelBot
@onready var hud: DebugHUD = %DebugHUD
@onready var player_respawn_timer: Timer = %PlayerRespawnTimer
@onready var bot_respawn_timer: Timer = %BotRespawnTimer

var player_score: int = 0
var bot_score: int = 0
var match_over: bool = false
var _player_spawns: Array[Marker3D] = []
var _bot_spawns: Array[Marker3D] = []


func _ready() -> void:
	_player_spawns = _collect_spawns(&"player_spawn")
	_bot_spawns = _collect_spawns(&"bot_spawn")
	player_respawn_timer.wait_time = respawn_delay
	bot_respawn_timer.wait_time = respawn_delay
	player.died.connect(_on_player_died)
	bot.connect(&"died", _on_bot_died)
	player_respawn_timer.timeout.connect(_respawn_player)
	bot_respawn_timer.timeout.connect(_respawn_bot)
	bot.call(&"set_target", player)
	call_deferred(&"_publish_state")


func _unhandled_input(event: InputEvent) -> void:
	if match_over and event.is_action_pressed(&"ui_accept"):
		restart_match()
		get_viewport().set_input_as_handled()


func restart_match() -> void:
	player_respawn_timer.stop()
	bot_respawn_timer.stop()
	player_score = 0
	bot_score = 0
	match_over = false
	_respawn_player()
	_respawn_bot()
	hud.hide_transient_message()
	_publish_state()


func _on_player_died() -> void:
	if match_over:
		return
	bot_score += 1
	if bot_score >= target_score:
		_finish_match(false)
	else:
		player_respawn_timer.start()
	_publish_state()
	if not match_over:
		hud.show_respawn_message(respawn_delay)


func _on_bot_died() -> void:
	if match_over:
		return
	player_score += 1
	if player_score >= target_score:
		_finish_match(true)
	else:
		bot_respawn_timer.start()
	_publish_state()


func _finish_match(player_won: bool) -> void:
	match_over = true
	player_respawn_timer.stop()
	bot_respawn_timer.stop()
	match_finished.emit(player_won)


func _respawn_player() -> void:
	if match_over:
		return
	player.respawn_at(_spawn_transform(_player_spawns, player_score + bot_score))
	hud.hide_transient_message()


func _respawn_bot() -> void:
	if match_over:
		return
	bot.call(&"respawn_at", _spawn_transform(_bot_spawns, player_score + bot_score))
	bot.call(&"set_target", player)


func _publish_state() -> void:
	score_changed.emit(player_score, bot_score, target_score)
	if is_instance_valid(hud):
		hud.set_duel_state(player_score, bot_score, target_score, match_over)


func _collect_spawns(group_name: StringName) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Marker3D:
			result.append(node as Marker3D)
	return result


func _spawn_transform(spawns: Array[Marker3D], index: int) -> Transform3D:
	if spawns.is_empty():
		return Transform3D.IDENTITY
	return spawns[index % spawns.size()].global_transform
