extends SceneTree
const DT := 1.0/60.0
var player: FirstPersonPlayer
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func step(direction: Vector2=Vector2.ZERO,held: bool=false,jump: bool=false) -> void:
	player._movement_input=direction
	player._jump_held=held
	player._jump_requested=jump
	player._simulate_movement(DT)
	await physics_frame
func run() -> void:
	# Fast mode keeps the simulated physics delta at 1/60 while accelerating this static-map fixture.
	if "--fast" in OS.get_cmdline_user_args():
		Engine.physics_ticks_per_second=600
		Engine.time_scale=10.0
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
	player=map.get_node("Player") as FirstPersonPlayer
	map.get_node("DuelBot").set_physics_process(false)
	player.set_physics_process(false)
	var u: float=map.UNITS_PER_METER
	# Three full-length lanes on each middle gallery cross both upper-ramp junctions.
	for side in [-1.0,1.0]:
		for x in [8.3,9.4,10.5]:
			player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(side*x,1.68,6.5)*u))
			for i in 30:await step()
			for i in 365:await step(Vector2(0,-1))
			check(player.position.z/u< -6.2,"Middle gallery lane blocked at side %s x %s: %s" % [side,x,player.position/u])
	# Standing and launching near all four old ramp-side barriers must work.
	var tested := 0
	for side in [-1.0,1.0]:
		for x in [8.3,9.4,10.5,11.15]:
			for z in [-5.7,-4.5,0.0,4.5,5.7]:
				player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(side*x,1.68,z)*u))
				for i in 30:await step()
				check(player.is_on_floor(),"Gallery sample must have valid floor: %s" % (player.position/u))
				var initial := player.position.y/u
				var peak := initial
				var ceiling := false
				await step(Vector2.ZERO,true,true)
				for i in 85:
					await step(Vector2.ZERO,true)
					peak=maxf(peak,player.position.y/u)
					ceiling=ceiling or player.is_on_ceiling()
				check(peak-initial>1.85 and not ceiling,"Gallery jump lacks headroom at %s/%s/%s (rise %s)" % [side,x,z,peak-initial])
				tested+=1
	# Jump from the middle of every upper ramp at actual top height.
	var space := player.get_world_3d().direct_space_state
	for side in [-1.0,1.0]:
		for end in [-1.0,1.0]:
			var at := Vector3(side*12.8,0,end*5.7)*u
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*4*u,at+Vector3.UP*1.6*u,1))
			check(not floor_hit.is_empty(),"Upper ramp must have a solid top")
			player.respawn_at(Transform3D(Basis.IDENTITY,floor_hit.position+Vector3.UP*.03*u))
			for i in 30:await step()
			var initial := player.position.y/u
			var peak := initial
			await step(Vector2.ZERO,true,true)
			for i in 85:
				await step(Vector2.ZERO,true)
				peak=maxf(peak,player.position.y/u)
			check(peak-initial>1.85,"Upper ramp launch blocked: %s/%s" % [side,end])
	# Walk the connected high-tier route around both planter pockets and ramp notches.
	for side in [-1.0,1.0]:
		player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(side*15.35,3.34,5.7)*u))
		for i in 30:await step()
		for target in [Vector3(side*15.35,3.3,4.25),Vector3(side*14.2,3.3,4.25),Vector3(side*14.2,3.3,-4.25),Vector3(side*15.35,3.3,-4.25),Vector3(side*15.35,3.3,-5.7)]:
			var reached := false
			for i in 300:
				var direction: Vector3 = target*u-player.position
				if Vector2(direction.x,direction.z).length()<.2:
					reached=true
					break
				player.rotation.y=atan2(-direction.x,-direction.z)
				await step(Vector2(0,-1))
			check(reached and player.position.y/u>3.25,"High terrace route blocked toward %s: %s" % [target,player.position/u])
		for x in [13.6,14.2]:
			for z in [-4.2,-2.8,0.0,2.8,4.2]:
				player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(side*x,3.34,z)*u))
				for i in 30:await step()
				var initial := player.position.y/u
				var peak := initial
				await step(Vector2.ZERO,true,true)
				for i in 85:
					await step(Vector2.ZERO,true)
					peak=maxf(peak,player.position.y/u)
				check(peak-initial>1.85,"High terrace jump blocked at %s/%s/%s" % [side,x,z])
	# All six center-facing gallery guards must block walking but permit jumping out.
	for side in [-1.0,1.0]:
		for z in [-4.5,0.0,4.5]:
			player.respawn_at(Transform3D(Basis(Vector3.UP,side*PI/2),Vector3(side*8.3,1.68,z)*u))
			for i in 30:await step()
			for i in 30:await step(Vector2(0,-1))
			check(absf(player.position.x/u)>7.7 and player.is_on_floor(),"Visible gallery guard must support a grounded launch")
			await step(Vector2(0,-1),true,true)
			for i in 70:await step(Vector2(0,-1),true)
			check(absf(player.position.x/u)<7.35,"Jump must clear the gallery guard at %s/%s (at %s)" % [side,z,player.position/u])
	main.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: six continuous middle-gallery lanes, %d full-height gallery jumps, four upper-ramp jumps, connected high-tier routes and 20 upper-terrace jumps and six guard-clearance jumps" % tested)
	quit(0 if failures.is_empty() else 1)
