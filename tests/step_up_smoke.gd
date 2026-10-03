extends SceneTree
const DT := 1.0/60.0
var failures: Array[String] = []
var player: FirstPersonPlayer
func _init() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)
func solid(at: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	root.add_child(body)
	body.position=at
	return body
func step(direction: Vector2=Vector2.ZERO, jump: bool=false) -> void:
	player._movement_input=direction
	player._jump_requested=jump
	player._jump_held=jump
	player._simulate_movement(DT)
	await physics_frame
func reset() -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(0,.2,0)))
	for i in 20:await step()
func run() -> void:
	solid(Vector3(0,-.5,0),Vector3(30,1,30))
	player=(load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame
	for height in [.05,.26,.34]:
		var ledge := solid(Vector3(3,height/2,0),Vector3(3,height,4))
		await reset()
		var peak := 0.0
		for i in 40:
			await step(Vector2.RIGHT)
			peak=maxf(peak,player.position.y)
		check(player.position.x>2.0 and absf(player.position.y-height)<.02,"Walk over %.2f-unit ledge (%s)" % [height,player.position])
		check(peak<height+.03,"Step must not launch player like a jump")
		ledge.queue_free()
		await process_frame
	var tall := solid(Vector3(3,.18,0),Vector3(3,.36,4))
	await reset()
	for i in 60:await step(Vector2.RIGHT)
	check(player.position.x<1.4 and player.position.y<.02,"Taller obstacles still block walking")
	tall.queue_free()
	await process_frame
	var ledge := solid(Vector3(3,.13,0),Vector3(3,.26,4))
	var ceiling := solid(Vector3(1.3,2.0,0),Vector3(6,.2,4))
	await reset()
	for i in 50:await step(Vector2.RIGHT)
	check(player.position.x<1.4,"Step cannot push capsule into low ceiling")
	ceiling.queue_free()
	ledge.queue_free()
	await process_frame
	# Fall beside a raised obstacle: stepping must not become a midair mantle.
	ledge=solid(Vector3(3,5.13,0),Vector3(3,.26,4))
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(0,5.1,0)))
	await step()
	player.velocity=Vector3(7,-1,0)
	var peak := player.position.y
	for i in 16:
		await step(Vector2.RIGHT)
		peak=maxf(peak,player.position.y)
	check(peak<=5.1 and not player._ledge_jump_available,"Stepping cannot lift a falling player or rearm their jump")
	player.queue_free()
	await process_frame
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: low/near-limit step climbs without jump impulse, tall obstacle blocking, ceiling clearance, airborne safety")
	quit(0 if failures.is_empty() else 1)
