extends SceneTree

var failures: Array[String] = []
var shots: int = 0
var sounded_shots: int = 0

func _init() -> void:
	call_deferred(&"run")

func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var bay := main.get_node("MovementLab")
	var player := bay.get_node("Player") as FirstPersonPlayer
	var bot := bay.get_node("DuelBot") as DuelBot
	var bot_audio: Node = bot.get_node("CharacterAudio")
	var player_audio: Node = player.get_node("CharacterAudio")
	bot.set_physics_process(false)
	for i in 12: await physics_frame
	player.position = Vector3(0, 0, 6)
	bot.position = Vector3(0, 0, 0)
	bot.movement_enabled = false
	bot.hit_chance = 0.0
	bot.reaction_delay = 0.05
	bot.aim_duration = 0.05
	bot.fire_interval = 0.3
	bot.set_target(player)
	bot.shot_fired.connect(func(_target: Node3D):
		shots += 1
		if bot_audio.gunfire.playing: sounded_shots += 1)
	var health_before := player.current_health
	bot.set_physics_process(true)
	await create_timer(0.85).timeout
	check(shots > 0 and sounded_shots == shots, "every real bot shot, including misses, plays audio")
	check(player.current_health == health_before, "missed shots remain non-damaging")
	check(bot_audio.gunfire is AudioStreamPlayer3D and bot_audio.footsteps is AudioStreamPlayer3D, "bot cues are spatial")
	check(bot_audio.gunfire.max_distance > bot.attack_range, "shots reach beyond combat range with falloff")

	# Observe actual bot movement rather than manually triggering step callbacks.
	bot.attack_range = 0.0
	bot.movement_enabled = true
	var heard_step := false
	for i in 90:
		await physics_frame
		heard_step = heard_step or bot_audio.footsteps.playing
	check(heard_step, "walking bot produces mechanical footsteps")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.pressed = true
	bay._unhandled_input(event)
	for i in 3: await physics_frame
	check(not bot_audio.footsteps.playing and not bot_audio.gunfire.playing, "F1 stops bot sounds")
	bay._unhandled_input(event)
	bot.apply_damage(1000.0)
	check(not bot_audio.footsteps.playing and not bot_audio.gunfire.playing, "death immediately stops bot sounds")
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	bot.set_physics_process(false)
	check(not bot_audio.footsteps.playing, "respawn does not generate a teleport step")

	player.position = Vector3(0, 0, 6)
	# Headless cannot capture the mouse; drive the real movement simulation directly.
	var local_step := false
	for i in 90:
		player.velocity.z = -player.walk_speed
		player._movement_input = Vector2(0, -1)
		player._simulate_movement(1.0 / 60.0)
		await physics_frame
		local_step = local_step or player_audio.footsteps.playing
	player._movement_input = Vector2.ZERO
	check(local_step, "local player walking produces footsteps")
	check(player_audio.footsteps.volume_db < bot_audio.footsteps.volume_db, "local footsteps leave room for opponent cues")
	await create_timer(0.4).timeout
	check(not player_audio.footsteps.playing, "idle player remains silent")
	player.apply_damage(10.0)
	check(player_audio.hit_feedback.playing, "incoming damage plays local hit feedback")
	player._jump_requested = true
	player._simulate_movement(1.0 / 60.0)
	player._jump_requested = false
	await physics_frame
	await create_timer(0.2).timeout
	check(not player.is_on_floor() and not player_audio.footsteps.playing, "airborne player does not keep stepping")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: spatial bot shots/misses, walking, pause/death/respawn, local steps/idle/airborne, damage audio")
		quit(0)
	else:
		for failure in failures: push_error("FAIL: " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
