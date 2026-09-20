class_name DuelBot
extends CharacterBody3D

## A deliberately small, offline opponent for the first duel slice.
## It discovers a node in the "player" group unless a target is assigned directly.

signal health_changed(current: float, maximum: float)
signal died
signal respawned
signal shot_fired(target: Node3D)
signal damage_dealt(amount: float)

@export_category("Health")
@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0

@export_category("Combat")
@export_range(1.0, 500.0, 1.0) var damage_per_shot: float = 15.0
@export_range(0.05, 5.0, 0.01) var fire_interval: float = 0.7
@export_range(1.0, 200.0, 1.0) var attack_range: float = 24.0
@export_range(1.0, 300.0, 1.0) var detection_range: float = 40.0
@export_range(0.1, 3.0, 0.1) var eye_height: float = 1.45
@export_flags_3d_physics var line_of_sight_collision_mask: int = 1

@export_category("Movement")
@export var movement_enabled: bool = false
@export_range(0.1, 20.0, 0.1) var movement_speed: float = 4.5
@export_range(1.0, 50.0, 0.5) var movement_acceleration: float = 16.0
@export_range(1.0, 50.0, 0.5) var movement_deceleration: float = 20.0
@export_range(1.0, 30.0, 0.5) var preferred_distance: float = 12.0
@export_range(0.0, 10.0, 0.1) var distance_tolerance: float = 1.5
@export_range(0.0, 1.0, 0.05) var strafe_weight: float = 0.55
@export_range(0.2, 10.0, 0.1) var strafe_switch_interval: float = 1.4
@export_range(1.0, 50.0, 0.1) var gravity: float = 24.0

var current_health: float = 100.0
var is_alive: bool = true

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visuals: Node3D = $Visuals
@onready var _body_mesh: MeshInstance3D = $Visuals/Body

var _target: Node3D
var _fire_cooldown: float = 0.0
var _strafe_timer: float = 0.0
var _strafe_direction: float = 1.0
var _damage_flash_remaining: float = 0.0
var _spawn_transform: Transform3D
var _normal_material: Material


func _ready() -> void:
	maximum_health = maxf(1.0, maximum_health)
	current_health = maximum_health
	is_alive = true
	_spawn_transform = global_transform
	_normal_material = _body_mesh.material_override
	_visuals.visible = true
	_collision_shape.disabled = false
	health_changed.emit(current_health, maximum_health)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	if _damage_flash_remaining <= 0.0:
		_body_mesh.material_override = _normal_material

	_refresh_target()
	_update_movement(delta)
	_try_fire()


func apply_damage(amount: float) -> bool:
	if not is_alive or not is_finite(amount) or amount <= 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		_die()
	else:
		_show_damage_flash()
	return true


func respawn_at(spawn_transform: Transform3D) -> void:
	_spawn_transform = spawn_transform
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	current_health = maximum_health
	is_alive = true
	_fire_cooldown = 0.0
	_damage_flash_remaining = 0.0
	_visuals.visible = true
	_body_mesh.material_override = _normal_material
	_collision_shape.set_deferred(&"disabled", false)
	health_changed.emit(current_health, maximum_health)
	respawned.emit()


func set_target(target: Node3D) -> void:
	_target = target


func _refresh_target() -> void:
	if is_instance_valid(_target) and _target.is_inside_tree():
		return
	_target = get_tree().get_first_node_in_group(&"player") as Node3D


func _update_movement(delta: float) -> void:
	var desired_velocity := Vector3.ZERO
	if _has_valid_target():
		var flat_to_target := _target.global_position - global_position
		flat_to_target.y = 0.0
		var distance := flat_to_target.length()
		if distance > 0.001:
			var forward := flat_to_target / distance
			look_at(global_position + forward, Vector3.UP, true)
			if movement_enabled:
				_strafe_timer -= delta
				if _strafe_timer <= 0.0:
					_strafe_direction *= -1.0
					_strafe_timer = strafe_switch_interval
				var distance_direction := Vector3.ZERO
				if distance > preferred_distance + distance_tolerance:
					distance_direction = forward
				elif distance < preferred_distance - distance_tolerance:
					distance_direction = -forward
				var strafe := forward.cross(Vector3.UP) * _strafe_direction * strafe_weight
				var desired_direction := (distance_direction + strafe).normalized()
				desired_velocity = desired_direction * movement_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var rate := movement_acceleration if not desired_velocity.is_zero_approx() else movement_deceleration
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _try_fire() -> void:
	if _fire_cooldown > 0.0 or not _has_valid_target():
		return
	if global_position.distance_to(_target.global_position) > attack_range:
		return
	if not _has_line_of_sight():
		return

	_fire_cooldown = fire_interval
	shot_fired.emit(_target)
	if not _target.has_method(&"apply_damage"):
		return
	var accepted: Variant = _target.call(&"apply_damage", damage_per_shot)
	if accepted is bool and accepted:
		damage_dealt.emit(damage_per_shot)


func _has_valid_target() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree() and _target.has_method(&"apply_damage") and global_position.distance_to(_target.global_position) <= detection_range


func _has_line_of_sight() -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var ray_origin := global_position + Vector3.UP * eye_height
	var ray_end := _target.global_position + Vector3.UP * eye_height
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, line_of_sight_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get(&"collider") == _target


func _show_damage_flash() -> void:
	_damage_flash_remaining = 0.08
	var flash_material := StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.88, 0.35)
	flash_material.emission_enabled = true
	flash_material.emission = flash_material.albedo_color
	flash_material.emission_energy_multiplier = 1.5
	_body_mesh.material_override = flash_material


func _die() -> void:
	is_alive = false
	velocity = Vector3.ZERO
	_visuals.visible = false
	_collision_shape.set_deferred(&"disabled", true)
	died.emit()
