class_name FirstPersonPlayer
extends CharacterBody3D

@export_category("Movement")
@export_range(1.0, 20.0, 0.1) var walk_speed: float = 7.0
@export_range(1.0, 25.0, 0.1) var sprint_speed: float = 10.0
@export_range(1.0, 100.0, 0.5) var ground_acceleration: float = 32.0
@export_range(1.0, 100.0, 0.5) var ground_deceleration: float = 40.0
@export_range(0.1, 30.0, 0.1) var air_acceleration: float = 5.0
@export_range(1.0, 50.0, 0.1) var gravity: float = 24.0
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 8.5

@export_category("Look")
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity: float = 0.0018
@export_range(-89.0, -1.0, 1.0) var minimum_pitch_degrees: float = -89.0
@export_range(1.0, 89.0, 1.0) var maximum_pitch_degrees: float = 89.0
@export_range(50.0, 110.0, 1.0) var field_of_view: float = 80.0

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera
@onready var weapon: PracticeRifle = %PracticeRifle

var _movement_input: Vector2 = Vector2.ZERO
var _jump_requested: bool = false


func _ready() -> void:
	camera.fov = field_of_view
	weapon.set_hip_field_of_view(field_of_view)
	Input.use_accumulated_input = false
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_release_mouse()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				weapon.suppress_fire_until_release()
				_capture_mouse()
				get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		_apply_look_delta(mouse_motion.screen_relative)


func _physics_process(delta: float) -> void:
	_sample_movement_input()
	_simulate_movement(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_mouse()


func _sample_movement_input() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_movement_input = Vector2.ZERO
		_jump_requested = false
		return

	_movement_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_jump_requested = Input.is_action_just_pressed(&"jump")


func _simulate_movement(delta: float) -> void:
	var wish_direction := _world_direction_from_input(_movement_input)
	var target_speed := sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed
	var target_velocity := wish_direction * target_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if is_on_floor():
		var rate := ground_acceleration if not wish_direction.is_zero_approx() else ground_deceleration
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)
		if _jump_requested:
			velocity.y = jump_velocity
		else:
			velocity.y = -0.5
	else:
		if not wish_direction.is_zero_approx():
			horizontal_velocity = horizontal_velocity.move_toward(target_velocity, air_acceleration * delta)
		velocity.y -= gravity * delta

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	move_and_slide()


func _world_direction_from_input(input_vector: Vector2) -> Vector3:
	var direction := transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	direction.y = 0.0
	return direction.normalized()


func _apply_look_delta(screen_delta: Vector2) -> void:
	rotate_y(-screen_delta.x * mouse_sensitivity)
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x - screen_delta.y * mouse_sensitivity,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	Input.action_release(&"sprint")
	if is_instance_valid(weapon):
		weapon.cancel_pending_input()
	_movement_input = Vector2.ZERO
	_jump_requested = false
