extends SceneTree
## Independent native query, arrival-jitter, lifetime and blocker regression.
var failures: Array[String] = []
const History = preload("res://scenes/network/combat_history.gd")
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func run():
	var host = Node3D.new()
	root.add_child(host)
	var human = load("res://scenes/network/remote_actor.gd").new()
	host.add_child(human)
	human.global_position = Vector3(0,200,0)
	var bot = load("res://scenes/bots/duel_bot.tscn").instantiate()
	bot.set_physics_process(false)
	host.add_child(bot)
	bot.global_position = Vector3(10,200,0)
	for actor in [human,bot]:
		var head = CombatHitbox.new()
		head.name = "CombatHead"
		head.actor = actor
		actor.add_child(head)
	await physics_frame
	await physics_frame
	for height in [1.4,1.62,1.72,1.8,1.86]:
		var hits = [0,0]
		for actor_index in 2:
			for sample in 97:
				var x = (sample-48)*.01 + actor_index*10
				var query = PhysicsRayQueryParameters3D.create(Vector3(x,200+height,5), Vector3(x,200+height,-5))
				query.collide_with_areas = true
				if not host.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): hits[actor_index] += 1
		print("FINAL_HEAD_RAYS y=",height," human=",hits[0]," bot=",hits[1]," /97")
		if height>=1.72: check(abs(hits[0]-hits[1])<=2 and hits[0]>0,"upper helmet matching coverage at"+str(height))
	var session = load("res://scenes/network/lan_session.gd").new()
	var virtual_next = 0
	var virtual_now = 0
	var accepted = 0
	for shot in 12:
		if shot>0: virtual_now += 200 if shot%2 else 240
		var before = Time.get_ticks_msec()
		session._shot_times[99] = before + virtual_next - virtual_now
		if session._accept_shot(99): accepted += 1
		virtual_next = session._shot_times[99] - before + virtual_now
	print("FINAL_JITTER_RATE 12shots accepted=",accepted," ammo=",session._magazines[99].ammo)
	check(accepted==12 and session._magazines[99].ammo==0,"20ms jitter preserves all12 accepted shots")
	check(session._accept_shot(7) and not session._accept_shot(7),"fresh instant duplicate rejected")
	var actors = {"human":human,"bot":bot}
	var generations = {"human":0,"bot":0}
	var now = Time.get_ticks_msec()/1000.0
	var history = History.new()
	history.record(actors,generations,now-.2)
	human.global_position.x=3
	history.record(actors,generations,now-.1)
	var origin = Vector3(0,201.62,5)
	var old_view = {"human":{"time":now-.2,"generation":0}}
	check(history.intersect_view(host.get_world_3d(),actors,generations,"bot",origin,Vector3.FORWARD,120,old_view).get("collider")==human,"rewound visible human hit")
	check(history.intersect_view(host.get_world_3d(),actors,generations,"bot",origin,Vector3.FORWARD,120,{"human":{"time":now-.4,"generation":0}}).is_empty(),"stale rewind denied")
	var wall = StaticBody3D.new()
	var wall_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4,4,.2)
	wall_shape.shape=box
	wall.add_child(wall_shape)
	host.add_child(wall)
	wall.global_position=Vector3(0,201.5,2)
	await physics_frame
	await physics_frame
	check(history.intersect_view(host.get_world_3d(),actors,generations,"bot",origin,Vector3.FORWARD,120,old_view).is_empty(),"actual wall blocks rewound helmet/body")
	wall.queue_free()
	await physics_frame
	human.apply_damage(100)
	check(history.intersect_view(host.get_world_3d(),actors,generations,"bot",origin,Vector3.FORWARD,120,old_view).is_empty(),"dead actor denies old living pose")
	human.respawn_at(Transform3D(Basis.IDENTITY,Vector3(3,200,0)))
	generations.human=1
	var spawn_time = now-.05
	history.record(actors,generations,spawn_time)
	check(history.position_at("human",old_view.human,1,now)==null,"old life denies new respawn damage")
	check(history.position_at("human",{"time":spawn_time,"generation":1},1,now)==human.global_position,"exact first respawn snapshot valid")
	check(history.position_at("human",{"time":now-.075,"generation":1},1,now)==null,"interpolation across lifes denied")
	check(history.position_at("human",{"time":INF,"generation":1},1,now)==null,"nonfinite timestamp denied")
	check(history.position_at("human",{"time":{},"generation":1},1,now)==null,"malformed timestamp denied")
	check(history.position_at("human",{"time":spawn_time,"generation":{}},1,now)==null,"malformed generation denied")
	human.global_position=Vector3(0,200,2)
	bot.global_position=Vector3(0,200,-4)
	generations.bot=0
	history.record(actors,generations,now-.02)
	var both_views = {"human":{"time":now-.02,"generation":1},"bot":{"time":now-.02,"generation":0}}
	check(history.intersect_view(host.get_world_3d(),actors,generations,"absent",origin,Vector3.FORWARD,120,both_views).get("collider")==human,"nearest friendly remains blocker")
	both_views.human.generation=999
	check(history.intersect_view(host.get_world_3d(),actors,generations,"absent",origin,Vector3.FORWARD,120,both_views).is_empty(),"invalid friendly view cannot erase blocker")
	human.global_position.x=20
	check(history.intersect_view(host.get_world_3d(),actors,generations,"absent",origin,Vector3.FORWARD,120,both_views).get("collider")==bot,"unrelated off-ray respawn preserves valid target shot")
	check(is_equal_approx(human._shape.shape.radius,0.35) and is_equal_approx(human._shape.shape.height,1.8),"combat head preserves human movement capsule dimensions")
	bot.global_position.x=20
	human.global_position=Vector3(0,200,5)
	for side in [-1,1]:
		var corridor=StaticBody3D.new()
		var corridor_shape=CollisionShape3D.new()
		var corridor_box=BoxShape3D.new()
		corridor_box.size=Vector3(.2,4,14)
		corridor_shape.shape=corridor_box
		corridor.add_child(corridor_shape)
		host.add_child(corridor)
		corridor.global_position=Vector3(side*.5,201.5,0)
	await physics_frame
	await physics_frame
	human.move_authoritative_pose(Vector3(0,200,-5))
	check(human.global_position.distance_to(Vector3(0,200,-5))<.001,"larger combat head does not obstruct original .8m movement corridor")
	session.free()
	host.queue_free()
	for failure in failures: push_error(failure)
	print("COMBAT_HIT_VALIDATION_PASS" if failures.is_empty() else "COMBAT_HIT_VALIDATION_FAIL", ": native helmet/body coverage,12/12 jittered shots,duplicate gate,rewind,cover,dead/respawn/type guards,nearest blocker,unrelated respawn,movement clearance; failures=",failures)
	quit(0 if failures.is_empty() else 1)
