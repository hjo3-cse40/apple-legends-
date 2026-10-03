extends SceneTree
const DT := 1.0/60.0
var player: FirstPersonPlayer
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func step(direction: Vector2=Vector2.ZERO, held: bool=false, jump: bool=false) -> void:
	player._movement_input=direction
	player._jump_held=held
	player._jump_requested=jump
	player._simulate_movement(DT)
	await physics_frame
func solid(at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	root.add_child(body)
	body.position=at
func grounded() -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(0,3.2,0)))
	for i in 20: await step()
	check(player.is_on_floor(),"Fixture starts on ledge")
func run() -> void:
	solid(Vector3(0,-3.5,0),Vector3(60,1,60))
	solid(Vector3(0,2.5,0),Vector3(4,1,4))
	player=(load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame
	await grounded()
	for i in 100:
		await step(Vector2.RIGHT)
		if not player.is_on_floor():break
	check(not player.is_on_floor() and player._ledge_jump_available,"Walking off ledge preserves one recovery jump")
	for i in 20: await step(Vector2.RIGHT)
	check(player.velocity.y < -3,"Fall builds downward momentum before recovery")
	var height_before := player.position.y
	await step(Vector2.LEFT,true,true)
	check(player.velocity.y>10 and not player._ledge_jump_available,"Jump during a sustained fall reverses descent and consumes recovery")
	var launch_speed := player.velocity.y
	await step(Vector2.LEFT,true,true)
	check(player.velocity.y<launch_speed,"Recovery cannot be used twice")
	var landed := false
	var peak := player.position.y
	for i in 180:
		await step(Vector2.LEFT,true)
		peak=maxf(peak,player.position.y)
		if player.is_on_floor():
			landed=absf(player.position.y-3)<.05
			break
	check(landed and peak>height_before+5,"Air strafe and recovery jump return onto the real ledge")
	check(player._ledge_jump_available,"Landing rearms jump")
	await grounded()
	await step(Vector2.ZERO,true,true)
	for i in 85: await step(Vector2.ZERO,true)
	check(not player.is_on_floor() and player.velocity.y<0,"Normal jump is falling before retry")
	var descending := player.velocity.y
	await step(Vector2.ZERO,true,true)
	check(player.velocity.y<descending,"Normal jump cannot grant another launch during descent")
	# Real airborne simulation retains takeoff momentum while adding side velocity.
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(0,20,10)))
	await step()
	player.velocity=Vector3(0,-1,-7)
	await step(Vector2.RIGHT)
	check(player.velocity.x>.5 and absf(player.velocity.z+7)<.001,"Strafing adds sideways speed without erasing forward momentum")
	var carry := Vector2(player.velocity.x,player.velocity.z)
	for i in 4: await step()
	check(Vector2(player.velocity.x,player.velocity.z).is_equal_approx(carry),"Releasing movement preserves air momentum")
	for i in 30:
		player.rotation.y-=.03
		await step(Vector2.RIGHT)
	check(Vector2(player.velocity.x,player.velocity.z).length()>8,"A/D with mouse yaw can build strafe speed")
	player.velocity=Vector3(0,-1,-7)
	player.rotation.y=0
	for i in 10: await step(Vector2(0,-1))
	check(absf(player.velocity.z+7)<.001,"Holding forward cannot continuously accelerate past the wish projection cap")
	var falling := player.velocity.y
	for i in 12: await step()
	check(absf(player.velocity.y-falling+13.2*.2)<.001,"Slightly reduced gravity still accelerates falling momentum")
	player._release_mouse()
	check(not player._ledge_jump_available,"Capture release clears recovery state")
	player.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: sustained ledge-fall recovery onto platform, one-use/reset safety, Source-style momentum/strafe gain/projection cap, gravity 13.2")
	quit(0 if failures.is_empty() else 1)
