extends SceneTree
var failures: Array[String] = []
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	var player := map.get_node("Player") as FirstPersonPlayer
	var bot := map.get_node("DuelBot") as CharacterBody3D
	bot.set_physics_process(false)
	bot.collision_layer=0
	player.set_physics_process(false)
	var u: float=map.UNITS_PER_METER
	var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/maps/garden_circuit/obstacle-audit.json"))
	var seat: Dictionary={}
	for o in audit.obstacles:
		if o.source=="CYAN human bench • Seat":seat=o
	check(not seat.is_empty(),"Oversized bench must export solid seat")
	if not seat.is_empty():
		check(float(seat.bounds.min[2])>1.18,"Bench underside must tower above .55 m robot")
		check(float(seat.bounds.max[0])-float(seat.bounds.min[0])>4.4,"Bench width must exceed eight robot heights")
	# Walk through the center between the legs, under the full solid seat.
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(4.65,.03,7.5)*u))
	player._movement_input=Vector2.ZERO
	for i in 20:
		player._simulate_movement(1.0/60.0)
		await physics_frame
	player._movement_input=Vector2(0,-1)
	for i in 90:
		player._simulate_movement(1.0/60.0)
		await physics_frame
	check(player.position.z/u<4.8,"Player must walk beneath the giant bench without blocking")
	check(player.position.y/u<.04,"Walking under bench stays on paving")
	main.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: oversized bench proportions, solid seat, actual player walking beneath bench")
	quit(0 if failures.is_empty() else 1)
