class_name RemoteActor
extends CharacterBody3D
## Host collision/health for a remote human; interpolated presentation on clients.
signal died
signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal respawned

var team_id := 1
var current_health := 100.0
var maximum_health := 100.0
var eye_height := 1.62
var grounded := true
var is_alive: bool:
	get:
		return current_health > 0.0
var interpolate := false
var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _has_snapshot := false
var _shape: CollisionShape3D
var _visual: Node3D
var _flash: MeshInstance3D
var _shot_audio: AudioStreamPlayer3D
var _flash_remaining := 0.0
var _shot_serial := 0

func _ready() -> void:
	add_to_group(&"damageable")
	add_to_group(&"koth_participant")
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	_shape.shape = capsule
	_shape.position.y = 0.9
	add_child(_shape)
	var art := load("res://art/calibration/MiniBot.glb") as PackedScene
	if art != null:
		_visual = art.instantiate() as Node3D
		_visual.scale = Vector3.ONE * 1.06
		_visual.rotation.y = PI
		add_child(_visual)
	_flash = MeshInstance3D.new()
	_flash.name = "RemoteMuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.09
	flash_mesh.height = 0.18
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color("ffbb69")
	flash_material.emission_enabled = true
	flash_material.emission = Color("ffbb69")
	flash_material.emission_energy_multiplier = 3.0
	flash_mesh.material = flash_material
	_flash.mesh = flash_mesh
	_flash.position = Vector3(0.24, 1.23, -0.75)
	_flash.visible = false
	add_child(_flash)
	_shot_audio = AudioStreamPlayer3D.new()
	_shot_audio.stream = load("res://art/audio/bot_shot.wav")
	_shot_audio.volume_db = -12.0
	_shot_audio.unit_size = 5.0
	_shot_audio.max_distance = 100.0
	add_child(_shot_audio)
	floor_snap_length = 0.25
	set_team(team_id)

func _physics_process(delta: float) -> void:
	if interpolate and _has_snapshot:
		global_position = global_position.lerp(_target_position, 1.0 - exp(-18.0 * delta))
		rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-18.0 * delta))

func apply_damage(amount: float, _source: Variant = null) -> bool:
	if not bool(get_meta("combat_enabled", true)) or not is_alive or not is_finite(amount) or amount <= 0.0:
		return false
	if _source is Vector3:
		set_meta("last_damage_source", _source)
	var applied := minf(current_health, amount)
	current_health -= applied
	damaged.emit(applied)
	health_changed.emit(current_health, maximum_health)
	if not is_alive:
		_set_alive_visual(false)
		died.emit()
	return true

func respawn_at(spawn: Transform3D) -> void:
	global_transform = spawn
	_target_position = spawn.origin
	_target_yaw = rotation.y
	velocity = Vector3.ZERO
	current_health = maximum_health
	grounded = true
	_set_alive_visual(true)
	health_changed.emit(current_health, maximum_health)
	respawned.emit()

func apply_snapshot(snapshot: Dictionary) -> void:
	var had_snapshot := _has_snapshot
	_target_position = snapshot.get("position", global_position)
	_target_yaw = float(snapshot.get("yaw", rotation.y))
	grounded = bool(snapshot.get("grounded", true))
	current_health = float(snapshot.get("health", current_health))
	if not _has_snapshot or global_position.distance_to(_target_position) > 8.0 or not interpolate:
		global_position = _target_position
		rotation.y = _target_yaw
	_has_snapshot = true
	var enabled := bool(snapshot.get("enabled", true))
	set_meta("combat_enabled", enabled)
	_set_alive_visual(is_alive and enabled)
	var serial := int(snapshot.get("shot_serial", _shot_serial))
	if had_snapshot and serial > _shot_serial and is_alive and enabled:
		show_shot()
	_shot_serial = serial
	health_changed.emit(current_health, maximum_health)

func set_team(team: int) -> void:
	team_id = team
	set_meta(&"koth_team", team)
	if is_instance_valid(_visual):
		for part in ["Eye", "Eye_001", "ChestIndicator", "BotWeaponPower"]:
			var mesh := _visual.find_child(part, true, false) as MeshInstance3D
			if mesh != null:
				var material := StandardMaterial3D.new()
				material.albedo_color = Color("70dce7") if team == 1 else Color("ffae4f")
				material.emission_enabled = true
				material.emission = material.albedo_color
				mesh.material_override = material

func _set_alive_visual(value: bool) -> void:
	if is_instance_valid(_shape):
		_shape.set_deferred("disabled", not value)
	if is_instance_valid(_visual):
		_visual.visible = value


func show_shot() -> void:
	if not is_alive or not bool(get_meta("combat_enabled", true)):
		return
	_flash_remaining = 0.06
	if is_instance_valid(_flash):
		_flash.show()
	if is_instance_valid(_shot_audio):
		_shot_audio.play()

func _process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if is_instance_valid(_flash):
		_flash.visible = _flash_remaining > 0.0 and is_alive and bool(get_meta("combat_enabled", true))
