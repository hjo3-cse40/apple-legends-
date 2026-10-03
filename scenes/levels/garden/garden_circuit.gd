extends "res://scenes/levels/calibration/calibration_bay.gd"
## Reuse accepted robot, weapon and inspection presentation in the full arena.
const MAP := preload("res://art/maps/garden_circuit/GardenCircuit.glb")
const UNITS_PER_METER := 1.0 / 0.31
var arena: Node3D

func _ready() -> void:
	for node_name in ["Ground", "LeftCanyon", "RightCanyon", "FarCanyon", "NearCanyon", "BarrierLeft", "BarrierRight", "LowCeilingBeam", "Targets"]:
		get_node(node_name).queue_free()
	arena = MAP.instantiate() as Node3D
	arena.name = "GardenMap"
	arena.scale = Vector3.ONE * UNITS_PER_METER
	add_child(arena)
	_add_collision(arena)
	# One uninterrupted collider avoids dipping into decorative paving seams.
	_solid(Vector3(0, -0.085, 0) * UNITS_PER_METER, Vector3(18, 0.20, 24) * UNITS_PER_METER)
	_setup_lighting()
	_setup_robot()
	_setup_rifle()
	_setup_hud()
	_place_spawn($PlayerSpawnA, "CYAN_SPAWN_1", false)
	_place_spawn($PlayerSpawnB, "CYAN_SPAWN_3", false)
	_place_spawn($BotSpawnA, "AMBER_SPAWN_1", true)
	_place_spawn($BotSpawnB, "AMBER_SPAWN_3", true)
	$Player.respawn_at($PlayerSpawnA.global_transform)
	$DuelBot.respawn_at($BotSpawnA.global_transform)
	var settings := preload("res://scenes/ui/settings/settings_menu.gd").new()
	settings.name = "SettingsMenu"
	add_child(settings)
	# Safety reset for exploratory jumps beyond the campus.
	_update_status()

func _add_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		# Keep thin exported surfaces intact instead of letting distance LOD collapse
		# paving/cover onto neighbouring surfaces or remove them entirely.
		mesh.lod_bias = 100000.0
		var extras: Dictionary = mesh.get_meta("extras", {})
		var collision_only := bool(extras.get("collision_only", false))
		if collision_only:
			mesh.hide()
		if collision_only or (not "Planting" in mesh.name and not "Signage" in mesh.name and not "Ground" in mesh.name):
			var shape := mesh.mesh.create_trimesh_shape()
			shape.backface_collision = true
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			mesh.add_child(body)
	for child in node.get_children():
		if not child is StaticBody3D:
			_add_collision(child)

func _place_spawn(marker: Marker3D, prefix: String, amber: bool) -> void:
	var source := arena.find_child(prefix + "*", true, false) as Node3D
	assert(source != null, "Missing Garden Circuit spawn: " + prefix)
	marker.global_position = source.global_position + Vector3.UP * 0.12
	marker.rotation.y = PI if amber else 0.0

func _update_status() -> void:
	super._update_status()
	if is_instance_valid(status):
		status.text = status.text.replace("A1 CALIBRATION", "GARDEN CIRCUIT")
		($DebugHUD/Help as Label).text = "WASD move  •  Shift tap/hold sprint  •  Space jump  •  LMB/V fire  •  F1 freeze bot  •  Esc settings"

func _physics_process(_delta: float) -> void:
	if $Player.position.y < -20.0:
		$Player.respawn_at($PlayerSpawnA.global_transform)
	if $DuelBot.position.y < -20.0:
		$DuelBot.respawn_at($BotSpawnA.global_transform)
