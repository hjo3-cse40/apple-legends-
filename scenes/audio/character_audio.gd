extends Node3D
## Presentation only: observe movement and combat without changing their simulation.

@export var stride_length: float = 1.55
@export var footstep_volume_db: float = -4.0
@export var local_player: bool = false

const STEP = preload("res://art/audio/robot_step.wav")
const SHOT = preload("res://art/audio/bot_shot.wav")
const HIT = preload("res://art/audio/shield_hit.wav")

var footsteps: AudioStreamPlayer3D
var gunfire: AudioStreamPlayer3D
var hit_feedback: AudioStreamPlayer
var _body: CharacterBody3D
var _last_position: Vector3
var _distance: float = 0.0
var _alternate: bool = false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	# Run after the parent's move_and_slide so contact/displacement are current.
	process_physics_priority = 10
	footsteps = _spatial_sound("Footsteps", STEP, footstep_volume_db, 7.0, 35.0)
	footsteps.position.y = 0.12
	gunfire = _spatial_sound("Gunfire", SHOT, -2.0, 12.0, 65.0)
	gunfire.position.y = 1.05
	gunfire.max_polyphony = 3
	if local_player:
		footsteps.panning_strength = 0.0
		hit_feedback = AudioStreamPlayer.new()
		hit_feedback.name = "HitFeedback"
		hit_feedback.stream = HIT
		hit_feedback.volume_db = -12.0
		add_child(hit_feedback)
		_body.connect(&"damaged", _on_damaged)
	if _body.has_signal(&"shot_fired"):
		_body.connect(&"shot_fired", _on_shot)
	_body.connect(&"died", _reset)
	_body.connect(&"respawned", _reset)
	_last_position = _body.global_position


func _spatial_sound(node_name: String, stream: AudioStream, volume: float, size: float, reach: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.name = node_name
	sound.stream = stream
	sound.volume_db = volume
	sound.unit_size = size
	sound.max_distance = reach
	sound.attenuation_filter_cutoff_hz = 10000.0
	add_child(sound)
	return sound


func _physics_process(_delta: float) -> void:
	var displacement := _body.global_position - _last_position
	_last_position = _body.global_position
	if not _body.is_physics_processing() or not bool(_body.get(&"is_alive")):
		_reset()
		return
	var travel := Vector2(displacement.x, displacement.z).length()
	if not _body.is_on_floor() or travel < 0.001 or travel > 3.0:
		_distance = 0.0
		return
	_distance += travel
	if _distance >= stride_length:
		_distance = fmod(_distance, stride_length)
		_alternate = not _alternate
		footsteps.pitch_scale = 1.04 if _alternate else 0.96
		footsteps.play()


func _on_shot(_target: Node3D) -> void:
	if _body.is_physics_processing() and bool(_body.get(&"is_alive")):
		gunfire.play()


func _on_damaged(_amount: float) -> void:
	hit_feedback.play()


func _reset() -> void:
	_distance = 0.0
	_last_position = _body.global_position
	footsteps.stop()
	gunfire.stop()
	# Let the final local damage cue ring briefly through elimination.
