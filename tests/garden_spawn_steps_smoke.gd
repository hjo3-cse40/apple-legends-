extends SceneTree
var failures: Array[String] = []
func _init() -> void:call_deferred("run")
func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	# Isolate geometry/input checks from round clocks and delayed respawns.
	map.get_node("DuelManager").process_mode = Node.PROCESS_MODE_DISABLED
	for timer_name in ["PlayerRespawnTimer", "BotRespawnTimer"]:
		var timer := map.get_node("DuelManager/"+timer_name) as Timer
		timer.stop()
		timer.process_mode = Node.PROCESS_MODE_DISABLED
	var player := map.get_node("Player") as FirstPersonPlayer
	var bot := map.get_node("DuelBot") as CharacterBody3D
	bot.set_physics_process(false)
	# Isolate authored pad collision from the frozen bot occupying Amber spawn 1.
	bot.collision_layer=0
	bot.collision_mask=0
	player.set_physics_process(false)
	var u: float=map.UNITS_PER_METER
	for team in ["CYAN","AMBER"]:
		for index in [1,2,3]:
			var marker := map.arena.find_child(team+"_SPAWN_"+str(index)+"*",true,false) as Node3D
			var from: Vector3=marker.global_position+Vector3(0,.3,2.4)
			player.respawn_at(Transform3D(Basis.IDENTITY,from))
			player._movement_input=Vector2.ZERO
			for i in 30:
				player._simulate_movement(1.0/60.0)
				await physics_frame
			var initial_height := player.position.y
			var climbed := false
			player._movement_input=Vector2(0,-1)
			for i in 75:
				player._simulate_movement(1.0/60.0)
				await physics_frame
				if absf(player.position.z-marker.global_position.z)<.5 and player.is_on_floor() and player.position.y>initial_height+.20:climbed=true
			if not climbed:failures.append("Must walk across %s spawn pad %s without jump (%s)" % [team,index,player.position])
	main.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: walking across all six authored spawn pads without jumping")
	quit(0 if failures.is_empty() else 1)
