extends SceneTree
const DT := 1.0/60.0
var player: FirstPersonPlayer
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message)
func step(direction: Vector2=Vector2.ZERO,held: bool=false,jump: bool=false) -> void:
	player._movement_input=direction; player._jump_held=held; player._jump_requested=jump
	player._simulate_movement(DT)
	await physics_frame
func run() -> void:
	Engine.physics_ticks_per_second=600; Engine.time_scale=10.0
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main); await process_frame
	var map := main.get_node("MovementLab")
	# Isolate geometry/input checks from round clocks and delayed respawns.
	map.get_node("DuelManager").process_mode = Node.PROCESS_MODE_DISABLED
	for timer_name in ["PlayerRespawnTimer", "BotRespawnTimer"]:
		var timer := map.get_node("DuelManager/"+timer_name) as Timer
		timer.stop()
		timer.process_mode = Node.PROCESS_MODE_DISABLED
	player=map.get_node("Player") as FirstPersonPlayer
	map.get_node("DuelBot").set_physics_process(false); player.set_physics_process(false)
	var u: float=map.UNITS_PER_METER
	for side in [-1.0,1.0]:
		for z in [-6.0,-3.0,0.0,3.0,6.0]:
			player.respawn_at(Transform3D(Basis(Vector3.UP,side*PI/2),Vector3(side*6.8,.05,z)*u))
			for i in 30: await step()
			for i in 40: await step(Vector2(0,1))
			check(absf(player.position.x/u)<7.5,"Visible skirt must stop walking beneath slab: %s" % (player.position/u))
			var peak := player.position.y/u
			var reached_gallery := false
			for i in 130:
				await step(Vector2(0,1),true,i==0)
				peak=maxf(peak,player.position.y/u)
				if absf(player.position.x/u)>8.1 and player.is_on_floor() and player.position.y/u>1.6: reached_gallery=true
			if z==0.0:
				check(peak>1.85,"Guarded edge must permit a full jump")
				for i in 60: await step(Vector2(0,-1))
				check(absf(player.position.x/u)<7.0 and player.is_on_floor() and player.position.y/u<.1,"Guarded edge must permit retreat without trapping capsule")
			else: check(peak>1.9 and reached_gallery,"Pressed-wall held jump must mount gallery: side %s z %s peak %s end %s" % [side,z,peak,player.position/u])
		for z in [-1.5,1.5]:
			player.respawn_at(Transform3D(Basis(Vector3.UP,side*PI/2),Vector3(side*6.5,.05,z)*u))
			for i in 30: await step()
			for i in 190: await step(Vector2(0,1))
			check(absf(player.position.x/u)>12.5 and player.position.y/u<.1,"Mirrored ground portal blocked: %s" % (player.position/u))
	main.queue_free(); await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: ten lower-edge wall approaches, eight gallery mounts, two guarded-edge retreats; four mirrored underpass crossings")
	quit(0 if failures.is_empty() else 1)
