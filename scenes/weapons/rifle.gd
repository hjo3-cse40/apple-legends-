class_name PracticeRifle
extends Node3D

signal ammo_changed(current: int, capacity: int)
signal hit_confirmed()
signal fired()

@export_category("Firing")
@export_range(1, 60, 1) var magazine_size: int = 12
@export_range(0.05, 1.0, 0.01) var seconds_between_shots: float = 0.18
@export_range(1.0, 200.0, 1.0) var damage: float = 34.0
@export_range(1.0, 500.0, 1.0) var maximum_range: float = 120.0
@export_range(0.1, 5.0, 0.05) var reload_duration: float = 1.15

@export_category("Aim and feedback")
@export_range(40.0, 100.0, 1.0) var ads_field_of_view: float = 67.0
@export_range(1.0, 30.0, 0.5) var ads_speed: float = 12.0
@export_range(0.0, 0.15, 0.005) var recoil_distance: float = 0.045
@export_range(0.0, 12.0, 0.25) var recoil_degrees: float = 3.0
@export_range(1.0, 40.0, 0.5) var recoil_recovery: float = 18.0
@export_range(0.0, 8.0, 0.1) var camera_fov_kick: float = 1.8
@export_range(1.0, 40.0, 0.5) var camera_kick_recovery: float = 14.0
@export_range(0.01, 0.2, 0.005) var muzzle_flash_duration: float = 0.045
@export var enable_fire_sound: bool = true
@export var hip_position: Vector3 = Vector3(0.24, -0.22, -0.48)
@export var ads_position: Vector3 = Vector3(0.0, -0.17, -0.43)

@export_category("Reload animation")
@export_range(0.0, 0.5, 0.01) var reload_drop_distance: float = 0.18
@export_range(0.0, 90.0, 1.0) var reload_roll_degrees: float = 38.0
@export_range(0.0, 45.0, 1.0) var reload_pitch_degrees: float = 14.0

@export_category("Bullet impacts")
@export_range(0.005, 0.1, 0.005) var impact_radius: float = 0.025
@export_range(0.05, 2.0, 0.05) var impact_lifetime: float = 0.3
@export var impact_color: Color = Color(1.0, 0.46, 0.08, 1.0)

@onready var model_root: Node3D = %ModelRoot
@onready var muzzle_flash: Node3D = %MuzzleFlash
@onready var shot_audio: AudioStreamPlayer = %ShotAudio

var ammo_in_magazine: int = 12
var is_reloading: bool = false

var _camera: Camera3D
var _player_body: CollisionObject3D
var _hip_field_of_view: float = 80.0
var _cooldown_remaining: float = 0.0
var _reload_remaining: float = 0.0
var _flash_remaining: float = 0.0
var _recoil_amount: float = 0.0
var _camera_kick_amount: float = 0.0
var _impact_spawn_count: int = 0
var _fire_queued: bool = false
var _reload_queued: bool = false
var _aim_requested: bool = false
var _fire_suppressed_until_release: bool = false


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_player_body = _find_player_body()
	if is_instance_valid(_camera):
		_hip_field_of_view = _camera.fov
	configure_viewmodel(model_root)
	ammo_in_magazine = magazine_size
	model_root.position = hip_position
	muzzle_flash.visible = false
	if enable_fire_sound:
		shot_audio.stream = _make_fire_sound()
	ammo_changed.emit(ammo_in_magazine, magazine_size)


func configure_viewmodel(node: Node) -> void:
	# Render camera-held geometry inside the player's clearance while preserving
	# its screen size, lighting and internal depth. Copy materials so enemy/world
	# assets that share the rifle resource retain ordinary world-space depth.
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.material_override is BaseMaterial3D:
			instance.material_override = _viewmodel_material(instance.material_override as BaseMaterial3D)
		elif instance.mesh != null:
			if instance.mesh.get_surface_count() == 1:
				var material := instance.get_active_material(0) as BaseMaterial3D
				if material != null:
					instance.material_override = _viewmodel_material(material)
			else:
				var local_mesh := instance.mesh.duplicate() as Mesh
				for index in local_mesh.get_surface_count():
					var material := instance.get_active_material(index) as BaseMaterial3D
					if material != null:
						local_mesh.surface_set_material(index, _viewmodel_material(material))
				instance.mesh = local_mesh
	for child in node.get_children():
		configure_viewmodel(child)


func _viewmodel_material(source: BaseMaterial3D) -> BaseMaterial3D:
	if source.use_z_clip_scale and is_equal_approx(source.z_clip_scale, 0.1):
		return source
	var material := source.duplicate() as BaseMaterial3D
	material.use_z_clip_scale = true
	material.z_clip_scale = 0.1
	return material


func _input(event: InputEvent) -> void:
	# Captured mouse combat must survive decorative HUD controls consuming clicks.
	# Visible-cursor recapture stays with the player and never fires a shot.
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_combat_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_combat_input(event)


func _handle_combat_input(event: InputEvent) -> void:
	if event.is_action_released(&"fire"):
		_fire_suppressed_until_release = false

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.is_action_released(&"aim"):
			_aim_requested = false
		return

	if event.is_action_pressed(&"fire") and not event.is_echo():
		if not _fire_suppressed_until_release:
			request_fire()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reload"):
		request_reload()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"aim"):
		set_aiming(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"aim"):
		set_aiming(false)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_update_reload(delta)
	_update_feedback(delta)

	if _reload_queued:
		_reload_queued = false
		_begin_reload()
	if _fire_queued:
		_fire_queued = false
		_try_fire()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_pending_input()


func request_fire() -> void:
	_fire_queued = true


func request_reload() -> void:
	_reload_queued = true


func set_aiming(aiming: bool) -> void:
	_aim_requested = aiming


func set_hip_field_of_view(value: float) -> void:
	_hip_field_of_view = value


func suppress_fire_until_release() -> void:
	_fire_suppressed_until_release = true
	_fire_queued = false


func cancel_pending_input() -> void:
	_fire_queued = false
	_reload_queued = false
	_aim_requested = false
	_fire_suppressed_until_release = false
	Input.action_release(&"fire")
	Input.action_release(&"aim")
	Input.action_release(&"reload")


func reset_for_respawn() -> void:
	cancel_pending_input()
	is_reloading = false
	_reload_remaining = 0.0
	_cooldown_remaining = 0.0
	_flash_remaining = 0.0
	_recoil_amount = 0.0
	_camera_kick_amount = 0.0
	ammo_in_magazine = magazine_size
	muzzle_flash.visible = false
	model_root.position = hip_position
	model_root.rotation = Vector3.ZERO
	ammo_changed.emit(ammo_in_magazine, magazine_size)


func _try_fire() -> void:
	if not _player_can_fire() or is_reloading or _cooldown_remaining > 0.0 or ammo_in_magazine <= 0:
		return

	ammo_in_magazine -= 1
	_cooldown_remaining = seconds_between_shots
	_recoil_amount = 1.0
	_camera_kick_amount = 1.0
	_flash_remaining = muzzle_flash_duration
	muzzle_flash.visible = true
	muzzle_flash.rotation.z = sin(float(ammo_in_magazine) * 2.31) * 0.8
	var flash_size := 0.9 + absf(sin(float(ammo_in_magazine) * 1.73)) * 0.35
	muzzle_flash.scale = Vector3(flash_size, flash_size, flash_size)
	if enable_fire_sound and shot_audio.stream != null:
		shot_audio.play()
	ammo_changed.emit(ammo_in_magazine, magazine_size)
	fired.emit()
	_perform_hitscan()


func _perform_hitscan() -> void:
	if not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return

	var ray_origin := _camera.global_position
	var ray_end := ray_origin - _camera.global_transform.basis.z * maximum_range
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if is_instance_valid(_player_body):
		query.exclude = [_player_body.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_spawn_impact(hit.get("position", ray_end) as Vector3)
	var collider := hit.get("collider") as Node
	if collider == null or not collider.is_in_group(&"damageable") or not collider.has_method(&"apply_damage"):
		return
	var accepted: Variant = collider.call(&"apply_damage", damage)
	if accepted is bool and accepted:
		hit_confirmed.emit()


func _begin_reload() -> void:
	if is_reloading or ammo_in_magazine >= magazine_size:
		return
	is_reloading = true
	_reload_remaining = reload_duration


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return
	_reload_remaining -= delta
	if _reload_remaining > 0.0:
		return
	is_reloading = false
	ammo_in_magazine = magazine_size
	ammo_changed.emit(ammo_in_magazine, magazine_size)


func _update_feedback(delta: float) -> void:
	_recoil_amount = move_toward(_recoil_amount, 0.0, recoil_recovery * delta)
	_camera_kick_amount = move_toward(_camera_kick_amount, 0.0, camera_kick_recovery * delta)
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	muzzle_flash.visible = _flash_remaining > 0.0

	var ads_weight := 1.0 if _aim_requested and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else 0.0
	var blend := 1.0 - exp(-ads_speed * delta)
	var base_position := ads_position if ads_weight > 0.5 else hip_position
	var reload_arc := 0.0
	if is_reloading and reload_duration > 0.0:
		var reload_progress := 1.0 - clampf(_reload_remaining / reload_duration, 0.0, 1.0)
		reload_arc = sin(reload_progress * PI)
	var target_position := base_position + Vector3.BACK * recoil_distance * _recoil_amount
	target_position += Vector3(0.04, -reload_drop_distance, 0.05) * reload_arc
	model_root.position = model_root.position.lerp(target_position, blend)
	var target_pitch := deg_to_rad(recoil_degrees) * _recoil_amount + deg_to_rad(reload_pitch_degrees) * reload_arc
	model_root.rotation.x = lerpf(model_root.rotation.x, target_pitch, blend)
	model_root.rotation.z = lerpf(model_root.rotation.z, deg_to_rad(reload_roll_degrees) * reload_arc, blend)
	if is_instance_valid(_camera):
		var base_fov := ads_field_of_view if ads_weight > 0.5 else _hip_field_of_view
		_camera.fov = lerpf(_camera.fov, base_fov + camera_fov_kick * _camera_kick_amount, blend)


func _spawn_impact(hit_position: Vector3) -> void:
	var impact := MeshInstance3D.new()
	impact.name = "BulletImpact"
	impact.add_to_group(&"bullet_impact")
	var impact_mesh := SphereMesh.new()
	impact_mesh.radius = impact_radius
	impact_mesh.height = impact_radius * 2.0
	impact_mesh.radial_segments = 8
	impact_mesh.rings = 4
	var impact_material := StandardMaterial3D.new()
	impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact_material.albedo_color = impact_color
	impact_material.emission_enabled = true
	impact_material.emission = impact_color
	impact_material.emission_energy_multiplier = 3.0
	impact_mesh.material = impact_material
	impact.mesh = impact_mesh
	impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var world_root := _find_world_root()
	world_root.add_child(impact)
	impact.global_position = hit_position
	_impact_spawn_count += 1
	get_tree().create_timer(impact_lifetime).timeout.connect(impact.queue_free)


func _find_world_root() -> Node3D:
	var world_root: Node3D = self
	var ancestor := get_parent()
	while ancestor is Node3D:
		world_root = ancestor as Node3D
		ancestor = ancestor.get_parent()
	return world_root


func _find_player_body() -> CollisionObject3D:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CollisionObject3D and ancestor.is_in_group(&"player"):
			return ancestor as CollisionObject3D
		ancestor = ancestor.get_parent()
	return null


func _player_can_fire() -> bool:
	if not is_instance_valid(_player_body):
		return true
	var alive_value: Variant = _player_body.get(&"is_alive")
	return not (alive_value is bool) or bool(alive_value)


func _make_fire_sound() -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	const SAMPLE_COUNT := 1764
	var samples := PackedByteArray()
	samples.resize(SAMPLE_COUNT * 2)
	for index in SAMPLE_COUNT:
		var time := float(index) / SAMPLE_RATE
		var envelope := exp(-time * 42.0)
		var crack := sin(TAU * 150.0 * time) + 0.45 * sin(TAU * 910.0 * time)
		var noise := sin(float(index * 73 % 127) * 1.71)
		var sample := clampf((crack * 0.55 + noise * 0.3) * envelope, -1.0, 1.0)
		samples.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	return stream
