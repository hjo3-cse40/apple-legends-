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
	_solid(Vector3(0, -0.085, 0) * UNITS_PER_METER, Vector3(32, 0.20, 44) * UNITS_PER_METER)
	_setup_lighting()
	_setup_robot()
	_setup_rifle()
	_setup_hud()
	$DebugHUD/ScoreReadout.hide()
	var objective_hud := KothHUD.new()
	objective_hud.name = "KothHUD"
	add_child(objective_hud)
	_setup_objective_visuals()
	_place_spawn($PlayerSpawnA, "CYAN_SPAWN_1", false)
	_place_spawn($PlayerSpawnB, "CYAN_SPAWN_3", false)
	_place_spawn($BotSpawnA, "AMBER_SPAWN_1", true)
	_place_spawn($BotSpawnB, "AMBER_SPAWN_3", true)
	$Player.respawn_at($PlayerSpawnA.global_transform)
	$DuelBot.respawn_at($BotSpawnA.global_transform)
	var settings := preload("res://scenes/ui/settings/settings_menu.gd").new()
	settings.name = "SettingsMenu"
	add_child(settings)
	$DuelManager.configure_objective(Vector3(0, 0.09, 0) * UNITS_PER_METER, 1.8 * UNITS_PER_METER)
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
			var shape := _objective_collision(mesh) if "Objective" in mesh.name else mesh.mesh.create_trimesh_shape()
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
		status.text = "APPLE LEGENDS / GARDEN CIRCUIT\n" + ("KOTH — BOT FROZEN" if opponent_paused else "KOTH — YOU ARE CYAN")
		if $DuelManager is TeamMatchManager:
			status.text = "APPLE LEGENDS / GARDEN CIRCUIT\nLAN KOTH — " + ("CYAN" if $Player.team_id == 1 else "AMBER")
		status.add_theme_font_size_override("font_size", 15)
		($DebugHUD/Help as Label).text = "WASD move  •  Shift tap/hold sprint  •  Space jump  •  LMB/V fire  •  F1 freeze bot  •  Esc settings"

func _physics_process(_delta: float) -> void:
	if $DuelManager is TeamMatchManager:
		return
	if $Player.position.y < -20.0:
		$Player.respawn_at($PlayerSpawnA.global_transform)
	if $DuelBot.position.y < -20.0:
		$DuelBot.respawn_at($BotSpawnA.global_transform)

var objective_ring: MeshInstance3D
var objective_material: StandardMaterial3D

func _setup_objective_visuals() -> void:
	# Local enemy accent colors make team identity readable without changing shared art.
	for part in ["Eye", "Eye_001", "ChestIndicator", "BotWeaponPower"]:
		var mesh := robot_visual.find_child(part, true, false) as MeshInstance3D
		if mesh != null:
			mesh.material_override = _material(Color("ffae4f"), 0.3)
	objective_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.73 * UNITS_PER_METER
	ring.outer_radius = 1.8 * UNITS_PER_METER
	ring.rings = 48
	ring.ring_segments = 8
	objective_ring.mesh = ring
	objective_ring.position = Vector3(0, 0.105, 0) * UNITS_PER_METER
	objective_ring.scale.y = 0.2
	objective_material = StandardMaterial3D.new()
	objective_material.albedo_color = Color("e3eef3")
	objective_material.emission_enabled = true
	objective_material.emission = Color("e3eef3")
	objective_material.emission_energy_multiplier = 0.5
	objective_ring.material_override = objective_material
	add_child(objective_ring)

func set_objective_visual(snapshot: Dictionary) -> void:
	var team := int(snapshot["capturing_team"])
	if team == 0:
		team = int(snapshot["owner_team"])
	var color := Color("64e4ee") if team == 1 else Color("ffae4f") if team == 2 else Color("e3eef3")
	if bool(snapshot["contested"]):
		color = Color("ff6b77")
	objective_material.albedo_color = color
	objective_material.emission = color

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_F1 and $DuelManager is TeamMatchManager:
		if event.pressed and not event.echo:
			$DuelManager.set_bots_frozen(not $DuelManager.bots_frozen)
			_update_status()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode == KEY_F1 and $DuelManager.match_over:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _objective_collision(mesh: MeshInstance3D) -> ConcavePolygonShape3D:
	# The joined artwork has dense beveled rings and engraving under capsule feet.
	# Keep equipment/columns, and use one smooth low-poly walkable apron beneath it.
	# Layer 2 preserves exact artwork for bullet rays, without capsule contacts.
	var ray_body := StaticBody3D.new()
	ray_body.name = "ObjectiveRayCollision"
	ray_body.collision_layer = 2
	ray_body.collision_mask = 0
	var ray_collider := CollisionShape3D.new()
	var detailed_shape := mesh.mesh.create_trimesh_shape()
	detailed_shape.backface_collision = true
	ray_collider.shape = detailed_shape
	ray_body.add_child(ray_collider)
	mesh.add_child(ray_body)
	var faces := mesh.mesh.get_faces()
	var kept := PackedVector3Array()
	for index in range(0, faces.size(), 3):
		var floor_detail := true
		for vertex in range(3):
			var point := faces[index + vertex]
			if point.y >= 0.1 or Vector2(point.x, point.z).length() > 2.51:
				floor_detail = false
				break
		if not floor_detail:
			kept.append(faces[index])
			kept.append(faces[index + 1])
			kept.append(faces[index + 2])
	var apron := ConvexPolygonShape3D.new()
	var vertices := PackedVector3Array()
	for index in range(64):
		var angle := TAU * float(index) / 64.0
		vertices.append(Vector3(cos(angle) * 2.5, 0.015, sin(angle) * 2.5))
		vertices.append(Vector3(cos(angle) * 1.76, 0.085, sin(angle) * 1.76))
	apron.points = vertices
	var body := StaticBody3D.new()
	body.name = "HillApronCollision"
	var collision := CollisionShape3D.new()
	collision.shape = apron
	body.add_child(collision)
	mesh.add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(kept)
	return shape
