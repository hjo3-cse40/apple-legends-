class_name DuelBot
extends CharacterBody3D

## A deliberately small, offline opponent for the first duel slice.
## It discovers a node in the "player" group unless a target is assigned directly.

signal health_changed(current: float, maximum: float)
signal died
signal respawned
signal shot_fired(target: Node3D)
signal damage_dealt(amount: float)

@export_category("Objective")
@export var team_id: int = 2
@export var objective_enabled: bool = false
@export var objective_step_height: float = 0.35
@export var objective_speed: float = 7.0

@export_category("Health")
@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0

@export_category("Combat")
@export_range(1.0, 500.0, 1.0) var damage_per_shot: float = 10.0
@export_range(0.05, 5.0, 0.01) var fire_interval: float = 1.1
@export_range(1.0, 200.0, 1.0) var attack_range: float = 24.0
@export_range(1.0, 300.0, 1.0) var detection_range: float = 40.0
@export_range(0.1, 3.0, 0.1) var eye_height: float = 1.45
@export_range(0.0, 3.0, 0.05) var reaction_delay: float = 0.75
@export_range(0.0, 2.0, 0.05) var aim_duration: float = 0.45
@export_range(0.0, 1.0, 0.05) var hit_chance: float = 0.55
@export_range(0.01, 0.25, 0.01) var muzzle_flash_duration: float = 0.06
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
@onready var _muzzle_flash: Node3D = $Visuals/MuzzleFlash

var _objective_position := Vector3.ZERO
var _objective_route: Array[Vector3] = []
var _objective_index: int = 0
var _objective_stuck_time: float = 0.0
var _objective_previous := Vector3.ZERO
var _objective_detour: float = 0.0

var _target: Node3D
var _fire_cooldown: float = 0.0
var _strafe_timer: float = 0.0
var _strafe_direction: float = 1.0
var _damage_flash_remaining: float = 0.0
var _muzzle_flash_remaining: float = 0.0
var _visible_target_time: float = 0.0
var _aim_time: float = 0.0
var _spawn_transform: Transform3D
var _normal_material: Material
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	maximum_health = maxf(1.0, maximum_health)
	current_health = maximum_health
	is_alive = true
	_spawn_transform = global_transform
	_normal_material = _body_mesh.material_override
	_random.randomize()
	_visuals.visible = true
	_muzzle_flash.visible = false
	_collision_shape.disabled = false
	health_changed.emit(current_health, maximum_health)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	_muzzle_flash_remaining = maxf(0.0, _muzzle_flash_remaining - delta)
	_muzzle_flash.visible = _muzzle_flash_remaining > 0.0
	if _damage_flash_remaining <= 0.0:
		_body_mesh.material_override = _normal_material

	_refresh_target()
	_update_movement(delta)
	_update_combat(delta)


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
	_muzzle_flash_remaining = 0.0
	_visible_target_time = 0.0
	_aim_time = 0.0
	_visuals.visible = true
	_muzzle_flash.visible = false
	_body_mesh.material_override = _normal_material
	_collision_shape.set_deferred(&"disabled", false)
	health_changed.emit(current_health, maximum_health)
	if objective_enabled:
		_build_objective_route()
	respawned.emit()


func set_target(target: Node3D) -> void:
	_target = target


func _refresh_target() -> void:
	if is_instance_valid(_target) and _target.is_inside_tree():
		return
	_target = get_tree().get_first_node_in_group(&"player") as Node3D


func _update_movement(delta: float) -> void:
	var desired_velocity := Vector3.ZERO
	if objective_enabled and movement_enabled:
		desired_velocity = _objective_velocity(delta)
	elif _has_valid_target():
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

	if objective_enabled and not movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var rate := movement_acceleration if not desired_velocity.is_zero_approx() else movement_deceleration
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	if objective_enabled and movement_enabled and is_on_floor():
		_try_objective_step(horizontal_velocity * delta)
	move_and_slide()


func _update_combat(delta: float) -> void:
	if not _has_valid_target() or global_position.distance_to(_target.global_position) > attack_range or not _has_line_of_sight():
		_visible_target_time = 0.0
		_aim_time = 0.0
		return

	_visible_target_time += delta
	if _visible_target_time < reaction_delay or _fire_cooldown > 0.0:
		return
	_aim_time += delta
	if _aim_time < aim_duration:
		return

	_fire_cooldown = fire_interval
	_aim_time = 0.0
	_muzzle_flash_remaining = muzzle_flash_duration
	_muzzle_flash.visible = true
	shot_fired.emit(_target)
	if _random.randf() > hit_chance:
		return
	if not _target.has_method(&"apply_damage"):
		return
	var accepted: Variant = _target.call(&"apply_damage", damage_per_shot, global_position)
	if accepted is bool and accepted:
		damage_dealt.emit(damage_per_shot)


func _has_valid_target() -> bool:
	if not is_instance_valid(_target) or not _target.is_inside_tree() or not _target.has_method(&"apply_damage"):
		return false
	var target_alive: Variant = _target.get(&"is_alive")
	if target_alive is bool and not bool(target_alive):
		return false
	return global_position.distance_to(_target.global_position) <= detection_range


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
	_muzzle_flash.visible = false
	_visible_target_time = 0.0
	_aim_time = 0.0
	_collision_shape.set_deferred(&"disabled", true)
	died.emit()


func configure_objective(point_position: Vector3, _arena: Node3D) -> void:
	_objective_position = point_position
	objective_enabled = true
	_build_objective_route()


func _build_objective_route() -> void:
	_objective_route.clear()
	_objective_index = 0
	_objective_stuck_time = 0.0
	_objective_detour = 0.0
	_strafe_direction = 1.0
	_objective_previous = global_position
	# Authored ground lanes avoid the spawn shield and clear giant bench legs.
	# Mirror the route across the hill for either dock; coordinates are meters.
	var side := -1.0 if global_position.z < _objective_position.z else 1.0
	var lane := -side * 7.15 / 0.31
	if absf(global_position.z - _objective_position.z) > 16.2 / 0.31:
		_objective_route.append(Vector3(lane, 0.0, side * 19.26 / 0.31))
	if absf(global_position.z - _objective_position.z) > 4.5 / 0.31:
		_objective_route.append(Vector3(lane, 0.0, side * 4.5 / 0.31))
		_objective_route.append(Vector3(0.0, 0.0, side * 4.5 / 0.31))
	_objective_route.append(_objective_position)


func _objective_velocity(delta: float) -> Vector3:
	if _objective_route.is_empty():
		_build_objective_route()
	var destination := _objective_route[_objective_index]
	var flat := destination - global_position
	flat.y = 0.0
	while flat.length() < 0.65 and _objective_index < _objective_route.size() - 1:
		_objective_index += 1
		destination = _objective_route[_objective_index]
		flat = destination - global_position
		flat.y = 0.0
	# Hold well inside the capture radius; do not chase enemies off the hill.
	if _objective_index == _objective_route.size() - 1 and flat.length() < 0.8:
		_objective_stuck_time = 0.0
		if _has_valid_target():
			var facing := _target.global_position - global_position
			facing.y = 0.0
			if facing.length_squared() > 0.001:
				look_at(global_position + facing, Vector3.UP, true)
		return Vector3.ZERO
	if global_position.distance_to(_objective_previous) < 0.9 * delta:
		_objective_stuck_time += delta
	else:
		_objective_stuck_time = maxf(0.0, _objective_stuck_time - delta)
	_objective_previous = global_position
	if _objective_stuck_time > 0.8:
		_objective_detour = 0.7
		_objective_stuck_time = 0.0
		_strafe_direction *= -1.0
	var direction := flat.normalized()
	if _objective_detour > 0.0:
		_objective_detour -= delta
		direction = (direction * 0.35 + direction.cross(Vector3.UP) * _strafe_direction).normalized()
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP, true)
	return direction * objective_speed


func _try_objective_step(motion: Vector3) -> void:
	if objective_step_height <= 0.0 or motion.is_zero_approx():
		return
	var start := global_transform
	var blocked := KinematicCollision3D.new()
	if not test_move(start, motion, blocked, safe_margin, false, 4):
		return
	var wall := false
	for index in blocked.get_collision_count():
		if blocked.get_normal(index).dot(up_direction) < cos(floor_max_angle):
			wall = true
	if not wall:
		return
	# Sweep the complete capsule up, across, then down; never bypass a ceiling
	# or taller wall, and require a walkable static landing within the allowance.
	var raised := start
	if test_move(start, up_direction * objective_step_height, null, safe_margin):
		return
	raised.origin += up_direction * objective_step_height
	if test_move(raised, motion, null, safe_margin):
		return
	raised.origin += motion
	var landing := KinematicCollision3D.new()
	if not test_move(raised, -up_direction * (objective_step_height + 0.01), landing, safe_margin):
		return
	if not landing.get_collider() is StaticBody3D or landing.get_normal().dot(up_direction) <= 0.0:
		return
	# Rounded capsule feet can touch a step corner before their center reaches
	# the tread. Validate the tread just inside that contact, not the corner normal.
	var tread := landing.get_position() + motion.normalized() * 0.04
	var query := PhysicsRayQueryParameters3D.create(tread + up_direction * (objective_step_height + 0.01), tread - up_direction * 0.01, collision_mask)
	query.exclude = [get_rid()]
	var top := get_world_3d().direct_space_state.intersect_ray(query)
	if top.is_empty() or not top.collider is StaticBody3D or top.normal.dot(up_direction) < cos(floor_max_angle):
		return
	var rise: float = (top.position - global_position).dot(up_direction)
	if rise > 0.001 and rise <= objective_step_height + 0.001:
		# Horizontal movement is still handled once by move_and_slide.
		global_position += up_direction * rise
