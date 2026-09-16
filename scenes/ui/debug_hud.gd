class_name DebugHUD
extends CanvasLayer

@onready var readout: Label = %Readout

var _player: CharacterBody3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D


func _process(_delta: float) -> void:
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
