extends SceneTree
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func capture() -> Image:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func material_check(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var material := node.get_active_material(index) as BaseMaterial3D
			check(material!=null and material.use_z_clip_scale,"Every first-person mesh uses protected viewmodel depth")
	for child in node.get_children():material_check(child)
func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	var player := map.get_node("Player") as FirstPersonPlayer
	map.get_node("DuelBot").set_physics_process(false)
	player.set_physics_process(false)
	player.weapon.set_physics_process(false)
	var u: float=map.UNITS_PER_METER
	player.respawn_at(Transform3D(Basis(Vector3.UP,-PI/2),Vector3(15.5,.04,10)*u))
	for i in 45:
		player._movement_input=Vector2(0,-1)
		player._simulate_movement(1.0/60.0)
		await physics_frame
	check(player.position.x/u<15.7,"Player capsule must stop at the authored wall")
	material_check(player.weapon.model_root)
	check(player.camera.near<.02,"Near plane preserves depth-compressed stock and hands")
	# Protecting the local viewmodel must never change the shared world rifle asset.
	var shared := (load("res://art/calibration/PulseRifle.glb") as PackedScene).instantiate()
	for mesh in shared.find_children("*","MeshInstance3D",true,false):
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as BaseMaterial3D
			check(material == null or not material.use_z_clip_scale,"Shared enemy/world rifle materials must retain world depth")
	shared.free()
	# Native rendering required: the visible gun must occupy the image even at wall contact.
	for aim in [false,true]:
		player.camera.fov=67 if aim else 80
		player.weapon.model_root.position=player.weapon.ads_position if aim else player.weapon.hip_position
		player.weapon.model_root.show()
		var showing := await capture()
		player.weapon.model_root.hide()
		var hidden := await capture()
		var samples := 0
		for y in range(showing.get_height()/3,showing.get_height()-140,3):
			for x in range(showing.get_width()/3,showing.get_width(),3):
				var difference := showing.get_pixel(x,y)-hidden.get_pixel(x,y)
				if absf(difference.r)+absf(difference.g)+absf(difference.b)>.03:samples+=1
		check(samples>4000,"Wall contact must preserve the visible %s rifle (%s samples)" % ["ADS" if aim else "hip",samples])
		print("VISIBLE WALL RIFLE %s: %s changed samples" % ["ADS" if aim else "hip",samples])
	player.weapon.model_root.show()
	main.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: capsule wall blocking, protected local materials, hip and ADS gun visible at wall contact")
	quit(0 if failures.is_empty() else 1)
