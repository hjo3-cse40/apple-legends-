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
		# Decorations/signs/plants do not obstruct lanes or shots. Solid architecture,
		# paving, benches, objective, docks, ramps, roofs and skyline match the export.
		if not "Planting" in mesh.name and not "Signage" in mesh.name:
			mesh.create_trimesh_collision()
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
