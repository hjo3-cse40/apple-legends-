class_name DebugHUD
extends CanvasLayer

@onready var readout: Label = %Readout
@onready var ammo_readout: Label = %AmmoReadout
@onready var hit_marker: Label = %HitMarker
@onready var health_readout: Label = %HealthReadout
@onready var score_readout: Label = %ScoreReadout
@onready var match_message: Label = %MatchMessage
@onready var damage_flash: ColorRect = %DamageFlash

var _player: FirstPersonPlayer
var _weapon: Node
var _hit_time_left: float = 0.0
var _damage_flash_time_left: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
	_weapon = get_tree().get_first_node_in_group(&"player_weapon")
	if is_instance_valid(_weapon):
		_weapon.connect(&"hit_confirmed", _on_hit_confirmed)
	if is_instance_valid(_player):
		_player.damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	_hit_time_left = maxf(0.0, _hit_time_left - delta)
	_damage_flash_time_left = maxf(0.0, _damage_flash_time_left - delta)
	hit_marker.visible = _hit_time_left > 0.0
	damage_flash.visible = _damage_flash_time_left > 0.0
	if is_instance_valid(_weapon):
		var ammo := int(_weapon.get(&"ammo_in_magazine"))
		var capacity := int(_weapon.get(&"magazine_size"))
		var reloading := bool(_weapon.get(&"is_reloading"))
		ammo_readout.text = "RELOADING..." if reloading else "SEMI-AUTO  |  %02d / %02d" % [ammo, capacity]
		if ammo == 0 and not reloading:
			ammo_readout.text += "  |  R to reload"
	else:
		ammo_readout.text = ""
	if not is_instance_valid(_player):
		readout.text = "Waiting for player..."
		health_readout.text = ""
		return

	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	health_readout.text = "HEALTH  %03d / %03d" % [roundi(_player.current_health), roundi(_player.maximum_health)]
	readout.text = "FPS: %d\nVelocity: (%.2f, %.2f, %.2f)\nHorizontal speed: %.2f m/s\nGrounded: %s" % [
		Engine.get_frames_per_second(),
		_player.velocity.x,
		_player.velocity.y,
		_player.velocity.z,
		horizontal_speed,
		"yes" if _player.is_on_floor() else "no"
	]


func _on_hit_confirmed() -> void:
	_hit_time_left = 0.12


func _on_player_damaged(_amount: float) -> void:
	_damage_flash_time_left = 0.07


func set_duel_state(player_score: int, bot_score: int, target_score: int, match_over: bool) -> void:
	score_readout.text = "YOU  %d  —  %d  BOT\nFIRST TO %d" % [player_score, bot_score, target_score]
	match_message.visible = match_over
	if match_over:
		match_message.text = ("VICTORY" if player_score > bot_score else "DEFEAT") + "\nPress Enter or Space to restart"


func show_respawn_message(seconds: float) -> void:
	match_message.visible = true
	match_message.text = "ELIMINATED\nRespawning in %.1f seconds" % seconds


func hide_transient_message() -> void:
	match_message.visible = false
