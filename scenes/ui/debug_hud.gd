class_name DebugHUD
extends CanvasLayer

@onready var readout: Label = %Readout
@onready var ammo_readout: Label = %AmmoReadout
@onready var hit_marker: Label = %HitMarker

var _player: CharacterBody3D
var _weapon: Node
var _hit_time_left: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_weapon = get_tree().get_first_node_in_group(&"player_weapon")
	if is_instance_valid(_weapon):
		_weapon.connect(&"hit_confirmed", _on_hit_confirmed)


func _process(delta: float) -> void:
	_hit_time_left = maxf(0.0, _hit_time_left - delta)
	hit_marker.visible = _hit_time_left > 0.0
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
		return

	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
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
