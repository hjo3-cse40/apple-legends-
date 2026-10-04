extends Node3D
## Art-only layer over the accepted duel. Simulation distances remain unchanged.

const ROBOT := preload("res://art/calibration/MiniBot.glb")
const RIFLE := preload("res://art/calibration/PulseRifle.glb")
const WALL := preload("res://art/calibration/ShellWall.glb")
const PLANTER := preload("res://art/calibration/GardenPlanter.glb")
const BENCH := preload("res://art/calibration/CampusBench.glb")
const CHARGER := preload("res://art/calibration/ChargeColumn.glb")
const CARGO := preload("res://art/calibration/CargoPod.glb")

@export_range(1.0, 3.0, 0.05) var architecture_height_scale: float = 1.8
@export_range(1.0, 3.0, 0.05) var scenery_prop_scale: float = 1.7

var opponent_paused := false
var reference_fov := false
var last_sprint_state := false
var robot_visual: Node3D
var status: Label
var elapsed := 0.0
var last_bot_health := 100.0
var hit_flash_remaining := 0.0
var hit_shells: Array[MeshInstance3D] = []

func _ready() -> void:
	# Inherited scene keeps the original gameplay nodes and unique-name contracts.
	for node_name in ["LeftCanyon", "RightCanyon", "FarCanyon", "NearCanyon", "BarrierLeft", "BarrierRight", "LowCeilingBeam", "Targets"]:
		get_node(node_name).queue_free()
	var floor_mesh := $Ground/Mesh as MeshInstance3D
	$Ground.position.y = -0.2
	floor_mesh.material_override = _material(Color("cbd3df"), 0.76)
	_build_shell()
	_build_props()
	_setup_lighting()
	_setup_robot()
	_setup_rifle()
	_setup_hud()

func _material(color: Color, roughness: float = 0.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _asset(scene: PackedScene, at: Vector3, yaw: float = 0.0) -> Node3D:
	var node := scene.instantiate() as Node3D
	add_child(node)
	node.position = at
	node.rotation.y = yaw
	return node

func _scaled_prop(scene: PackedScene, at: Vector3, center: Vector3, size: Vector3) -> void:
	var prop := _asset(scene, at)
	prop.scale = Vector3.ONE * scenery_prop_scale
	_solid(at + center * scenery_prop_scale, size * scenery_prop_scale)

func _shell_panel(at: Vector3, yaw: float) -> void:
	var panel := _asset(WALL, at, yaw)
	panel.scale.y = architecture_height_scale

func _solid(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = at

func _block(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	add_child(node)
	node.position = at
	return node

func _build_shell() -> void:
	# Clear center for the current LOS/strafe bot; all hero props sit to the sides.
	for x in [-14.0, 14.0]:
		for z in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
			_shell_panel(Vector3(x, 0, z), PI / 2.0 if x < 0 else -PI / 2.0)
		_solid(Vector3(x, 2 * architecture_height_scale, 0), Vector3(0.55, 4 * architecture_height_scale, 40))
	for z in [-20.0, 20.0]:
		for x in [-11.0, -5.0, 1.0, 7.0, 11.0]:
			_shell_panel(Vector3(x, 0, z), 0.0 if z < 0 else PI)
		_solid(Vector3(0, 2 * architecture_height_scale, z), Vector3(28, 4 * architecture_height_scale, 0.55))
	for z in range(-18, 19, 6):
		_block(Vector3(0, 0.011, z), Vector3(27.5, 0.012, 0.028), Color("a9b7c8"))
	for x in range(-12, 13, 6):
		_block(Vector3(x, 0.012, 0), Vector3(0.028, 0.012, 39.5), Color("a9b7c8"))
	for x in [-6.5, 6.5]:
		_block(Vector3(x, 0.025, 0), Vector3(0.065, 0.02, 33), Color("38bdf8"))
	# Non-playable skyline supplies scale without extra routes or bot navigation.
	for x in [-20.0, -10.0, 10.0, 22.0]:
		_block(Vector3(x, 10, -30), Vector3(8, 20, 8), Color("e2e8f0"))
		_block(Vector3(x, 20.15, -30), Vector3(8.8, 0.3, 8.8), Color("94a3b8"))
		_block(Vector3(x, 10, -25.95), Vector3(0.2, 10.0, 0.05), Color("38bdf8"))
	_label("A1", Vector3(0, 3.05 * architecture_height_scale, -19.68), 100)
	_label("GARDEN / CALIBRATION", Vector3(0, 2.35 * architecture_height_scale, -19.68), 40)

func _build_props() -> void:
	for at in [Vector3(-9, 0, -5), Vector3(9, 0, 5)]:
		_scaled_prop(PLANTER, at, Vector3(0, 0.73, 0), Vector3(3.2, 1.46, 1.8))
	for at in [Vector3(-9, 0, 4), Vector3(9, 0, -6)]:
		_asset(BENCH, at)
		_solid(at + Vector3(0, 1.15, 0), Vector3(3.8, 0.27, 1.0))
		_solid(at + Vector3(0, 1.62, 0.39), Vector3(3.8, 0.91, 0.24))
	for at in [Vector3(-11, 0, -13), Vector3(11, 0, 13)]:
		_scaled_prop(CHARGER, at, Vector3(0, 1.35, 0), Vector3(0.86, 2.5, 0.66))
	for at in [Vector3(-8, 0, 10), Vector3(8, 0, -12)]:
		_scaled_prop(CARGO, at, Vector3(0, 0.7, 0), Vector3(1.2, 1.4, 1.1))
	# A static, non-damageable chassis for close inspection, outside the duel lane.
	var display := _asset(ROBOT, Vector3(-10, 0, 1), PI / 2)
	display.name = "DisplayRobot"
	_label("CHASSIS / 01", Vector3(-10, 2.2, 1), 28)
	for marker in get_tree().get_nodes_in_group("player_spawn") + get_tree().get_nodes_in_group("bot_spawn"):
		var at: Vector3 = (marker as Node3D).position
		_block(Vector3(at.x, 0.028, at.z), Vector3(1.5, 0.025, 1.5), Color("475569"))
		_block(Vector3(at.x, 0.044, at.z + 0.65), Vector3(1.3, 0.018, 0.04), Color("38bdf8"))

func _label(text: String, at: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = Color("263547")
	label.outline_size = 0
	add_child(label)
	label.position = at

func _setup_lighting() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("468ce2")
	sky_material.sky_horizon_color = Color("c9e3fa")
	sky_material.ground_bottom_color = Color("70849e")
	sky_material.ground_horizon_color = Color("c9e3fa")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bcd6f0")
	environment.ambient_light_energy = 0.65
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.8
	$WorldEnvironment.environment = environment
	$Sun.light_color = Color("fff3df")
	$Sun.light_energy = 1.1

func _setup_robot() -> void:
	var visuals := $DuelBot/Visuals as Node3D
	for name in ["Body", "Visor", "Rifle"]:
		visuals.get_node(name).hide()
	robot_visual = ROBOT.instantiate() as Node3D
	visuals.add_child(robot_visual)
	# Blender -Y exports as +Z, matching the bot's model-front convention.
	robot_visual.rotation.y = 0
	robot_visual.scale = Vector3.ONE * 1.06
	for name in ["Helmet", "ChestShell"]:
		var mesh := robot_visual.find_child(name, true, false) as MeshInstance3D
		if mesh != null:
			hit_shells.append(mesh)
	last_bot_health = $DuelBot.current_health
	$DuelBot.health_changed.connect(_on_bot_health_changed)

func _on_bot_health_changed(health: float, _maximum: float) -> void:
	if health < last_bot_health:
		hit_flash_remaining = 0.12
		for mesh in hit_shells:
			mesh.material_override = _material(Color("ffb36b"), 0.3)
	last_bot_health = health

func _setup_rifle() -> void:
	var model := $Player/CameraPivot/Camera/PracticeRifle/ModelRoot as Node3D
	for child in model.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).hide()
	var rifle := RIFLE.instantiate() as Node3D
	model.add_child(rifle)
	rifle.rotation.y = PI
	rifle.scale = Vector3.ONE * 0.85
	_set_shadows(rifle, false)
	var flash := $Player/CameraPivot/Camera/PracticeRifle/ModelRoot/MuzzleFlash as Node3D
	flash.position = Vector3(0, 0, -0.60)
	for child in flash.get_children():
		if child is MeshInstance3D:
			var material := _material(Color("4cc9ff"))
			material.use_z_clip_scale = true
			material.z_clip_scale = 0.1
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = Color("38bdf8")
			(child as MeshInstance3D).material_override = material
	$Player/CameraPivot/Camera/PracticeRifle.impact_color = Color("38bdf8")
	$Player/CameraPivot/Camera/PracticeRifle.configure_viewmodel(model)

func _set_shadows(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_shadows(child, enabled)

func _setup_hud() -> void:
	var hud := $DebugHUD as DebugHUD
	hud.get_node("ReadoutPanel").hide()
	(hud.get_node("Help") as Label).text = "WASD   •   Shift tap/hold sprint   •   Space hold for height   •   LMB/V fire / RMB aim / R reload   •   F1 inspect / F2 FOV / F3 stats"
	hud.health_readout.add_theme_color_override("font_color", Color("4cc9ff"))
	for label in [hud.health_readout, hud.ammo_readout, hud.score_readout]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.045, 0.065, 0.10, 0.85)
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		label.add_theme_stylebox_override("normal", style)
	hud.score_readout.anchor_left = 0.36
	hud.score_readout.anchor_right = 0.64
	status = Label.new()
	status.position = Vector2(20, 18)
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("d3eafd"))
	status.add_theme_color_override("font_shadow_color", Color("152536"))
	status.add_theme_constant_override("shadow_offset_x", 1)
	status.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(status)
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F1:
			opponent_paused = not opponent_paused
			$DuelBot.set_physics_process(not opponent_paused)
			$DuelBot/Visuals/MuzzleFlash.hide()
			$DuelBot.velocity = Vector3.ZERO
			_update_status()
		KEY_F2:
			reference_fov = not reference_fov
			var fov := 58.7155 if reference_fov else 80.0
			$Player.field_of_view = fov
			$Player/CameraPivot/Camera/PracticeRifle.set_hip_field_of_view(fov)
			# Preserve relative ADS narrowing in both comparison modes.
			$Player/CameraPivot/Camera/PracticeRifle.ads_field_of_view = maxf(40.0, fov - 22.0)
			_update_status()
		KEY_F3:
			var panel := $DebugHUD/ReadoutPanel as Control
			panel.visible = not panel.visible
			panel.position.y = 86
		_:
			return
	get_viewport().set_input_as_handled()

func _update_status() -> void:
	status.text = "APPLE LEGENDS  /  A1 CALIBRATION\n%s  •  %s" % ["INSPECT — opponent paused" if opponent_paused else "OFFLINE DUEL — first to five", "90° horizontal @ 16:9" if reference_fov else "BASELINE 80° vertical"]
	status.text += "  •  " + ("SPRINT" if $Player.is_sprinting else "WALK")

func _process(delta: float) -> void:
	if last_sprint_state != $Player.is_sprinting:
		last_sprint_state = $Player.is_sprinting
		_update_status()
	elapsed += delta
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	if hit_flash_remaining <= 0:
		for mesh in hit_shells:
			mesh.material_override = null
	if is_instance_valid(robot_visual):
		var moving := ($DuelBot as CharacterBody3D).velocity.length() > 0.5
		robot_visual.position.y = absf(sin(elapsed * 14.0)) * 0.025 if moving else 0.0
