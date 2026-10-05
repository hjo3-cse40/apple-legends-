class_name DuelBot
extends CharacterBody3D

## Local tactical opponent. A configured roster enables team combat; the original
## single-target API remains available to calibration and older duel fixtures.

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

@export_category("Tactics")
@export_range(1, 30, 1) var magazine_size: int = 8
@export_range(0.2, 5.0, 0.1) var reload_duration: float = 1.8
@export_range(0.0, 1.0, 0.05) var retreat_health_fraction: float = 0.30
@export var teammate_spacing: float = 2.4

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

## Difficulty is applied by the host. Calibration fixtures retain their exports.
var difficulty: int = 1
var sprinting: bool = false
var tactical_role: String = "anchor"
var _jump_remaining: float = 3.0
var _stance_remaining: float = 0.0
var _combat_bias: float = 0.0
var _sprint_speed: float = 10.0
var _jump_interval: float = 5.0
var _jump_impulse: float = 8.0
var current_health: float = 100.0
var is_alive: bool = true
var combatants: Array[Node3D] = []
var behavior_state: String = "advance"
var ammo_in_magazine: int = 8
var reloading: bool = false
var _reload_remaining: float = 0.0
var _decision_remaining: float = 0.0
var _role_index: int = 0
var _owner_team: int = -1
var _contested: bool = false
var _retreat_remaining: float = 0.0
var _retreat_cooldown: float = 0.0
var _cover_remaining: float = 0.0
var _cover_position := Vector3.ZERO
var _has_cover: bool = false
var _steering_remaining: float = 0.0
var _step_probe_remaining: float = 0.0
var _steering_direction := Vector3.ZERO

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
	ammo_in_magazine = magazine_size
	_visuals.visible = true
	_muzzle_flash.visible = false
	_collision_shape.disabled = false
	health_changed.emit(current_health, maximum_health)


func _physics_process(delta: float) -> void:
	if not is_alive or not bool(get_meta(&"combat_enabled", true)):
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	_muzzle_flash_remaining = maxf(0.0, _muzzle_flash_remaining - delta)
	_muzzle_flash.visible = _muzzle_flash_remaining > 0.0
	if _damage_flash_remaining <= 0.0:
		_body_mesh.material_override = _normal_material

	_update_tactics(delta)
	_refresh_target()
	_update_movement(delta)
	_update_combat(delta)


func apply_damage(amount: float, _source_position: Variant = null) -> bool:
	if not is_alive or not bool(get_meta(&"combat_enabled", true)) or not is_finite(amount) or amount <= 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		_die()
	else:
		_show_damage_flash()
		if not combatants.is_empty() and current_health / maximum_health <= retreat_health_fraction and _retreat_cooldown <= 0.0:
			_retreat_remaining = 1.6
			_retreat_cooldown = 5.0
	return true


func respawn_at(spawn_transform: Transform3D) -> void:
	_spawn_transform = spawn_transform
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	current_health = maximum_health
	is_alive = true
	_fire_cooldown = 0.0
	ammo_in_magazine = magazine_size
	reloading = false
	_reload_remaining = 0.0
	_retreat_remaining = 0.0
	_retreat_cooldown = 0.0
	_cover_remaining = 0.0
	_has_cover = false
	_steering_remaining = 0.0
	_step_probe_remaining = 0.0
	_jump_remaining = _random.randf_range(2.0, 4.0)
	_stance_remaining = 0.0
	sprinting = false
	_steering_direction = Vector3.ZERO
	_decision_remaining = 0.0
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


func configure_combatants(actors: Array[Node3D], slot_index: int = 0) -> void:
	combatants = actors.duplicate()
	_role_index = clampi(slot_index, 0, 2)
	tactical_role = ["pressure", "anchor", "support"][_role_index]
	_target = null
	_decision_remaining = 0.0
	if objective_enabled:
		_build_objective_route()


func set_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, 2)
	# Expert reacts quickly but still uses perception, reloads, range falloff and
	# imperfect aim. Damage and health stay identical at every difficulty.
	reaction_delay = [1.0, 0.45, 0.20][difficulty]
	aim_duration = [0.55, 0.24, 0.10][difficulty]
	fire_interval = [0.85, 0.38, 0.24][difficulty]
	hit_chance = [0.32, 0.65, 0.86][difficulty]
	objective_speed = [4.5, 7.0, 7.0][difficulty]
	movement_speed = [4.5, 6.0, 7.0][difficulty]
	_sprint_speed = [4.5, 10.0, 10.0][difficulty]
	_jump_interval = [1000.0, 5.0, 2.8][difficulty]
	_stance_remaining = 0.0
	_jump_remaining = _random.randf_range(2.0, 4.0)


func set_tactical_context(owner_team: int, contested: bool) -> void:
	_owner_team = owner_team
	_contested = contested


func _update_tactics(delta: float) -> void:
	_decision_remaining -= delta
	_jump_remaining = maxf(0.0, _jump_remaining - delta)
	_stance_remaining -= delta
	if _stance_remaining <= 0.0:
		_stance_remaining = _random.randf_range(0.65, 1.6)
		# Bounded, persistent choices create readable feints rather than noise.
		_combat_bias = _random.randf_range(-0.45, 0.55)
		if _random.randf() < 0.65:
			_strafe_direction *= -1.0
	_retreat_remaining = maxf(0.0, _retreat_remaining - delta)
	_retreat_cooldown = maxf(0.0, _retreat_cooldown - delta)
	_cover_remaining = maxf(0.0, _cover_remaining - delta)
	_steering_remaining = maxf(0.0, _steering_remaining - delta)
	_step_probe_remaining = maxf(0.0, _step_probe_remaining - delta)
	if reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			reloading = false
			ammo_in_magazine = magazine_size
	elif not combatants.is_empty() and ammo_in_magazine <= 0:
		reloading = true
		_reload_remaining = reload_duration
		_aim_time = 0.0
	behavior_state = "advance"
	if objective_enabled and global_position.distance_to(_objective_position) < 6.0:
		behavior_state = "contest" if _contested else ("defend" if _owner_team == team_id else "capture")
	if _retreat_remaining > 0.0:
		behavior_state = "retreat"
	elif reloading:
		behavior_state = "reload"


func _refresh_target() -> void:
	if combatants.is_empty():
		if is_instance_valid(_target) and _target.is_inside_tree():
			return
		_target = get_tree().get_first_node_in_group(&"player") as Node3D
		return
	if _decision_remaining > 0.0 and _has_valid_target():
		return
	_decision_remaining = 0.18
	var selected: Node3D = null
	var best_score := INF
	for candidate in combatants:
		if not _is_enemy(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > detection_range or not _can_see(candidate):
			continue
		# Visible enemies threatening the hill get a modest priority. Hysteresis
		# avoids flickering between equally close opponents every decision tick.
		var score := distance
		if objective_enabled and candidate.global_position.distance_to(_objective_position) < 6.0:
			score -= 4.0
		if candidate == _target:
			score -= 3.0
		if score < best_score:
			selected = candidate
			best_score = score
	if selected != _target:
		_visible_target_time = 0.0
		_aim_time = 0.0
	_target = selected


func _is_enemy(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate) or candidate == self or not candidate.is_inside_tree():
		return false
	if not bool(candidate.get_meta(&"combat_enabled", true)):
		return false
	if not candidate.has_method(&"apply_damage") or candidate.get(&"is_alive") == false:
		return false
	return candidate.get(&"team_id") != team_id


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

	if movement_enabled and not combatants.is_empty() and difficulty > 0:
		desired_velocity = _tactical_velocity(desired_velocity, delta)
	sprinting = false
	if movement_enabled and difficulty > 0 and not combatants.is_empty() and not desired_velocity.is_zero_approx():
		var traveling := objective_enabled and global_position.distance_to(_objective_position) > 7.0
		var engaging := _has_valid_target() and global_position.distance_to(_target.global_position) <= attack_range
		sprinting = (traveling and not engaging) or _retreat_remaining > 0.0 or reloading
		if sprinting:
			desired_velocity = desired_velocity.normalized() * _sprint_speed
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
		if _should_tactical_jump(horizontal_velocity):
			velocity.y = _jump_impulse
			_jump_remaining = _jump_interval * _random.randf_range(0.8, 1.4)
	else:
		velocity.y -= gravity * delta
	# Probe a step only after real wall contact; sweeping every grounded tick
	# redundantly retests detailed floor geometry, especially on the hill.
	if objective_enabled and movement_enabled and is_on_floor() and _step_probe_remaining <= 0.0 and _has_wall_contact():
		_step_probe_remaining = 0.1
		_try_objective_step(horizontal_velocity * delta)
	move_and_slide()


func _update_combat(delta: float) -> void:
	if reloading or not _has_valid_target() or global_position.distance_to(_target.global_position) > attack_range or not _has_line_of_sight():
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
	var accuracy := hit_chance
	if not combatants.is_empty():
		ammo_in_magazine -= 1
		var range_fraction := clampf(global_position.distance_to(_target.global_position) / attack_range, 0.0, 1.0)
		accuracy *= lerpf(1.0, 0.6, range_fraction)
	if _random.randf() > accuracy:
		return
	if not _target.has_method(&"apply_damage"):
		return
	var accepted: Variant = _target.call(&"apply_damage", damage_per_shot, global_position)
	if accepted is bool and accepted:
		damage_dealt.emit(damage_per_shot)


func _has_valid_target() -> bool:
	if not is_instance_valid(_target) or not _target.is_inside_tree() or not _target.has_method(&"apply_damage"):
		return false
	if not bool(_target.get_meta(&"combat_enabled", true)):
		return false
	if not combatants.is_empty() and not _is_enemy(_target):
		return false
	var target_alive: Variant = _target.get(&"is_alive")
	if target_alive is bool and not bool(target_alive):
		return false
	return global_position.distance_to(_target.global_position) <= detection_range


func _has_line_of_sight() -> bool:
	return _can_see(_target)


func _can_see(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var ray_origin := global_position + Vector3.UP * eye_height
	var target_eye: Variant = candidate.get(&"eye_height")
	var height := float(target_eye) if target_eye is float or target_eye is int else eye_height
	var ray_end := candidate.global_position + Vector3.UP * height
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, line_of_sight_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get(&"collider") == candidate


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
	var hold_offset := Vector3.ZERO
	if not combatants.is_empty():
		hold_offset = Vector3(float(_role_index - 1) * 2.1, 0.0, float(_role_index % 2) * 1.3)
	_objective_route.append(_objective_position + hold_offset)


func _objective_velocity(delta: float) -> Vector3:
	if _objective_route.is_empty():
		_build_objective_route()
	var destination := _objective_route[_objective_index]
	var flat := destination - global_position
	flat.y = 0.0
	var waypoint_radius := 0.25 if not combatants.is_empty() else 0.65
	while flat.length() < waypoint_radius and _objective_index < _objective_route.size() - 1:
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


func _tactical_velocity(base_velocity: Vector3, delta: float) -> Vector3:
	var desired := base_velocity
	var to_hill := _objective_position - global_position
	to_hill.y = 0.0
	var holding := objective_enabled and to_hill.length() < 4.8
	if _has_valid_target() and _has_line_of_sight():
		var toward := _target.global_position - global_position
		toward.y = 0.0
		if toward.length_squared() > 0.01:
			var forward := toward.normalized()
			look_at(global_position + forward, Vector3.UP, true)
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = strafe_switch_interval * _random.randf_range(0.7, 1.3)
				_strafe_direction *= -1.0
			if (_retreat_remaining > 0.0 or reloading) and (holding or not objective_enabled):
				desired = (-forward + forward.cross(Vector3.UP) * _strafe_direction * 0.8).normalized() * movement_speed
			elif holding:
				var role_strafe := 0.35 if tactical_role == "anchor" else 0.75
				desired += forward.cross(Vector3.UP) * _strafe_direction * movement_speed * role_strafe
				# Pressure closes when needed; support keeps space. The anchor stays
				# on objective, while both teammates vary their engagement distance.
				var wanted_range := preferred_distance + (3.0 if tactical_role == "support" else -2.0)
				if tactical_role != "anchor" and absf(toward.length() - wanted_range) > distance_tolerance:
					desired += forward * signf(toward.length() - wanted_range) * movement_speed * 0.3
				desired += forward * _combat_bias * movement_speed * 0.25
	# Briefly break sight behind nearby real geometry to reload or recover aim.
	# Check complete capsule access before choosing cover, so a ray occluder
	# alone cannot send the bot through a planter or under an inaccessible ledge.
	if (_retreat_remaining > 0.0 or reloading) and _has_valid_target() and (holding or not objective_enabled):
		if _cover_remaining <= 0.0:
			_find_nearby_cover()
		if _has_cover:
			var to_cover := _cover_position - global_position
			to_cover.y = 0.0
			desired = to_cover.normalized() * movement_speed if to_cover.length() > 0.5 else Vector3.ZERO
	# Teammates separate gently instead of stacking their capsules at one waypoint.
	var separation := Vector3.ZERO
	for ally in combatants:
		if not is_instance_valid(ally) or ally == self or ally.get(&"team_id") != team_id or ally.get(&"is_alive") == false or not bool(ally.get_meta(&"combat_enabled", true)):
			continue
		var away := global_position - ally.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < teammate_spacing and distance > 0.01:
			separation += away / distance * (1.0 - distance / teammate_spacing)
	if holding or not objective_enabled:
		desired += separation.limit_length(1.0) * movement_speed
	# Keep defending strafes inside the capture ring. Retreat remains brief and
	# may leave it, creating a real opportunity for an enemy to capture.
	if holding and _retreat_remaining <= 0.0 and to_hill.length() > 3.5:
		desired = desired.slide(-to_hill.normalized()) + to_hill.normalized() * movement_speed * 0.5
	# Local capsule probes steer around scenery; the authored route still provides
	# reliable macro navigation and stuck recovery, rather than wall-penetration.
	if not desired.is_zero_approx() and (holding or not objective_enabled) and _has_wall_contact():
		if _steering_remaining <= 0.0:
			_steering_remaining = 0.15
			_steering_direction = Vector3.ZERO
			var motion := desired.normalized() * 0.9
			if test_move(global_transform, motion):
				var left := motion.rotated(Vector3.UP, 0.85)
				var right := motion.rotated(Vector3.UP, -0.85)
				if not test_move(global_transform, left):
					_steering_direction = left.normalized()
				elif not test_move(global_transform, right):
					_steering_direction = right.normalized()
		if not _steering_direction.is_zero_approx():
			desired = _steering_direction * desired.length()
	else:
		_steering_direction = Vector3.ZERO

	return desired.limit_length(objective_speed if objective_enabled else movement_speed)


func _find_nearby_cover() -> void:
	_cover_remaining = 0.5
	_has_cover = false
	var away := global_position - _target.global_position
	away.y = 0.0
	if away.is_zero_approx():
		return
	for angle in [-0.9, 0.9, -1.5, 1.5, 0.0]:
		var offset := away.normalized().rotated(Vector3.UP, angle) * 3.5
		if test_move(global_transform, offset):
			continue
		var candidate := global_position + offset
		var support_query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 0.35, candidate - Vector3.UP * 0.8, collision_mask)
		support_query.exclude = [get_rid()]
		var support := get_world_3d().direct_space_state.intersect_ray(support_query)
		if support.is_empty() or not support.collider is StaticBody3D or support.normal.dot(Vector3.UP) < cos(floor_max_angle):
			continue
		var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * eye_height, _target.global_position + Vector3.UP * eye_height, line_of_sight_collision_mask)
		ray.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is StaticBody3D:
			_cover_position = candidate
			_has_cover = true
			return


func _has_wall_contact() -> bool:
	for index in get_slide_collision_count():
		if get_slide_collision(index).get_normal().dot(up_direction) < cos(floor_max_angle):
			return true
	return false


func _should_tactical_jump(horizontal: Vector3) -> bool:
	if difficulty == 0 or not movement_enabled or combatants.is_empty() or _jump_remaining > 0.0 or horizontal.length() < 2.0 or not _has_valid_target():
		return false
	# Probe only at the jump decision cadence. Use capsule sweeps along the
	# ballistic arc and static support beneath the expected landing. Never jump
	# blindly into ceilings, tall obstacles, teammates, or off an unsupported edge.
	_jump_remaining = 0.5
	return _jump_path_is_safe(horizontal)


func _jump_path_is_safe(horizontal: Vector3) -> bool:
	var flight_time := 2.0 * _jump_impulse / gravity
	var previous := global_transform
	previous.origin.y += 0.04
	for segment in range(1, 9):
		var time := flight_time * float(segment) / 8.0
		var sample := global_transform
		sample.origin += horizontal * time
		sample.origin.y += maxf(0.04, _jump_impulse * time - 0.5 * gravity * time * time)
		if test_move(previous, sample.origin - previous.origin):
			return false
		previous = sample
	var landing := previous.origin
	var support_query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 0.3, landing - Vector3.UP * 0.5, collision_mask)
	support_query.exclude = [get_rid()]
	var support := get_world_3d().direct_space_state.intersect_ray(support_query)
	return not support.is_empty() and support.collider is StaticBody3D and support.normal.dot(Vector3.UP) >= cos(floor_max_angle)
