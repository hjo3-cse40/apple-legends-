extends SceneTree
## Verify real host and replicated actor shot cues use the same spatial gain.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var bot := load("res://scenes/bots/duel_bot.tscn").instantiate() as DuelBot
	world.add_child(bot)
	bot.set_physics_process(false)
	var remote := RemoteActor.new()
	world.add_child(remote)
	await process_frame
	var audio := bot.get_node("CharacterAudio").get("gunfire") as AudioStreamPlayer3D
	assert(is_equal_approx(audio.volume_db, remote._shot_audio.volume_db), "joining clients hear the same shot gain")
	assert(is_equal_approx(audio.unit_size, remote._shot_audio.unit_size), "same distance attenuation on both peers")
	assert(audio.volume_db > -2.0 and audio.unit_size > 12.0, "world gunfire is more audible nearby and at distance")
	remote.show_shot()
	assert(remote._shot_audio.playing, "actual replicated firing plays cue")
	var rifle: Node = load("res://scenes/weapons/rifle.tscn").instantiate()
	world.add_child(rifle)
	await process_frame
	assert(is_equal_approx(rifle.get_node("ShotAudio").volume_db, -6.0), "local rifle gain increased by 3 dB")
	world.queue_free()
	await process_frame
	print("NETWORK_AUDIO_PASS: host/client parity, spatial gain, actual shot, local rifle gain")
	quit()
