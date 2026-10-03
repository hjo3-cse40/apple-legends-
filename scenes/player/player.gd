class_name FirstPersonPlayer
extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal damaged(amount: float)
signal damaged_from(source_position: Vector3)
signal died
signal respawned

@export_category("Movement")
@export_range(1.0, 20.0, 0.1) var walk_speed: float = 7.0
@export_range(1.0, 25.0, 0.1) var sprint_speed: float = 10.0
@export_range(1.0, 100.0, 0.5) var ground_acceleration: float = 32.0
@export_range(1.0, 100.0, 0.5) var ground_deceleration: float = 40.0
@export_range(0.1, 30.0, 0.1) var air_acceleration: float = 8.0
@export_range(0.1, 10.0, 0.1) var air_wish_speed_cap: float = 2.5
@export_range(1.0, 50.0, 0.1) var gravity: float = 13.2
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 11.0

@export_category("Sprint and jump control")
@export_range(0.1, 0.5, 0.01) var sprint_tap_duration: float = 0.22
@export_range(0.1, 1.0, 0.01) var jump_hold_duration: float = 0.35
@export_range(0.1, 1.0, 0.05) var jump_hold_gravity_scale: float = 0.55
@export_range(0.1, 1.0, 0.05) var jump_release_velocity_scale: float = 0.5

@export_category("Look")
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity: float = 0.0018
@export_range(-89.0, -1.0, 1.0) var minimum_pitch_degrees: float = -89.0
@export_range(1.0, 89.0, 1.0) var maximum_pitch_degrees: float = 89.0
@export_range(50.0, 110.0, 1.0) var field_of_view: float = 80.0

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera
@onready var weapon: PracticeRifle = %PracticeRifle
@onready var health: Node = %HealthComponent
@onready var collision_shape: CollisionShape3D = %CollisionShape3D

var current_health: float:
	get:
		return float(health.get(&"current_health")) if is_instance_valid(health) else 0.0

var maximum_health: float:
	get:
		return float(health.get(&"maximum_health")) if is_instance_valid(health) else 100.0

var is_alive: bool:
	get:
		return is_instance_valid(health) and not bool(health.get(&"is_dead"))

var use_cs_mouse_scale: bool = false

var _movement_input: Vector2 = Vector2.ZERO
var _jump_requested: bool = false
var _jump_held: bool = false
var _jump_hold_remaining: float = 0.0
var _jump_hold_active: bool = false
var _ledge_jump_available: bool = false
var sprint_toggled: bool = false
var _sprint_held: bool = false
var _sprint_press_time: float = 0.0

var is_sprinting: bool:
	get:
		return sprint_toggled or _sprint_held


func _ready() -> void:
	health.connect(&"health_changed", _on_health_changed)
	health.connect(&"damaged", _on_damaged)
	health.connect(&"died", _on_died)
	camera.fov = field_of_view
	weapon.set_hip_field_of_view(field_of_view)
	Input.use_accumulated_input = false
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_release_mouse()
		get_viewport().set_input_as_handled()
		return

	if not is_alive:
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
	if not is_alive:
		velocity = Vector3.ZERO
		return
	_sample_movement_input(delta)
	_simulate_movement(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_mouse()


func _sample_movement_input(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_reset_movement_intent()
		return

	_movement_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_jump_requested = Input.is_action_just_pressed(&"jump")
	_jump_held = Input.is_action_pressed(&"jump")
	_update_sprint_input(Input.is_action_pressed(&"sprint"), delta)


func _update_sprint_input(pressed: bool, delta: float) -> void:
	if pressed:
		if not _sprint_held:
			_sprint_press_time = 0.0
		_sprint_press_time += delta
	elif _sprint_held:
		# Decide on release: taps toggle; deliberate holds are momentary.
		if _sprint_press_time <= sprint_tap_duration:
			sprint_toggled = not sprint_toggled
		_sprint_press_time = 0.0
	_sprint_held = pressed


func _reset_movement_intent() -> void:
	_movement_input = Vector2.ZERO
	_jump_requested = false
	_jump_held = false
	_jump_hold_active = false
	_jump_hold_remaining = 0.0
	sprint_toggled = false
	_sprint_held = false
	_sprint_press_time = 0.0
	_ledge_jump_available = false


func _simulate_movement(delta: float) -> void:
	var wish_direction := _world_direction_from_input(_movement_input)
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := wish_direction * target_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	var grounded := is_on_floor()
	var launched := _jump_requested and (grounded or (_ledge_jump_available and velocity.y <= 0.0))
	if grounded:
		var rate := ground_acceleration if not wish_direction.is_zero_approx() else ground_deceleration
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)
	else:
		horizontal_velocity = _air_accelerate(horizontal_velocity, wish_direction, target_speed, delta)

	if launched:
		# Walking off leaves one jump available; any launch consumes it until landing.
		velocity.y = jump_velocity
		_jump_hold_remaining = jump_hold_duration
		_jump_hold_active = true
		_ledge_jump_available = false
	elif grounded:
		velocity.y = -0.5
		_jump_hold_active = false
	else:
		var upward_gravity := gravity
		if _jump_hold_active and velocity.y > 0.0:
			if not _jump_held:
				# Ease the release cut toward full height as the lift window runs out.
				var remaining_fraction := clampf(_jump_hold_remaining / jump_hold_duration, 0.0, 1.0)
				velocity.y *= lerpf(1.0, jump_release_velocity_scale, remaining_fraction)
				_jump_hold_active = false
			else:
				# Apply a partial-frame blend at the end of the finite lift window.
				var lift_time := minf(delta, _jump_hold_remaining)
				upward_gravity *= lerpf(1.0, jump_hold_gravity_scale, lift_time / delta)
				_jump_hold_remaining = maxf(0.0, _jump_hold_remaining - delta)
				_jump_hold_active = _jump_hold_remaining > 0.0
		else:
			_jump_hold_active = false
		velocity.y -= upward_gravity * delta

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	move_and_slide()
	if is_on_floor() and not launched:
		_ledge_jump_available = true
	if is_on_ceiling():
		_jump_hold_active = false


func _air_accelerate(horizontal: Vector3, wish_direction: Vector3, wish_speed: float, delta: float) -> Vector3:
	# Source-style projection cap: preserve existing lateral momentum, and add
	# velocity only along the wish direction. Turning the wish direction enables strafing.
	if wish_direction.is_zero_approx():
		return horizontal
	var remaining := minf(wish_speed, air_wish_speed_cap) - horizontal.dot(wish_direction)
	if remaining <= 0.0:
		return horizontal
	var gain := minf(remaining, air_acceleration * wish_speed * delta)
	return horizontal + wish_direction * gain


func _world_direction_from_input(input_vector: Vector2) -> Vector3:
	var direction := transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	direction.y = 0.0
	return direction.normalized()


func mouse_screen_scale() -> float:
	# Godot 4.7.2 macOS scales NSEvent deltas by the maximum attached Retina scale.
	# Undo that factor for CS angular units, independently of viewport stretch.
	if OS.get_name() == "macOS" and DisplayServer.get_name() != "headless":
		var maximum := 1.0
		for index in DisplayServer.get_screen_count():
			maximum = maxf(maximum, DisplayServer.screen_get_scale(index))
		return maximum
	return 1.0


func _apply_look_delta(screen_delta: Vector2) -> void:
	if use_cs_mouse_scale:
		screen_delta /= mouse_screen_scale()
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
	_reset_movement_intent()


func apply_damage(amount: float, source_position: Variant = null) -> bool:
	var accepted := bool(health.call(&"apply_damage", amount))
	if accepted and source_position is Vector3:
		damaged_from.emit(source_position as Vector3)
	return accepted


func respawn_at(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	_reset_movement_intent()
	collision_shape.set_deferred(&"disabled", false)
	health.call(&"reset_to_full")
	if is_instance_valid(weapon):
		weapon.cancel_pending_input()
		if weapon.has_method(&"reset_for_respawn"):
			weapon.call(&"reset_for_respawn")
	respawned.emit()


func _on_health_changed(value: float, maximum: float) -> void:
	health_changed.emit(value, maximum)


func _on_damaged(amount: float) -> void:
	damaged.emit(amount)


func _on_died() -> void:
	velocity = Vector3.ZERO
	_reset_movement_intent()
	collision_shape.set_deferred(&"disabled", true)
	if is_instance_valid(weapon):
		weapon.cancel_pending_input()
	died.emit()
