extends SceneTree


class PlayerProbe extends CharacterBody3D:
	var received_damage: float = 0.0
	var is_alive: bool = true
	var last_source_position: Variant = null

	func apply_damage(amount: float, source_position: Variant = null) -> bool:
		if not is_finite(amount) or amount <= 0.0:
			return false
		received_damage += amount
		last_source_position = source_position
		return true


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var bot_scene := load("res://scenes/bots/duel_bot.tscn") as PackedScene
	_check(bot_scene != null, "duel bot scene should load")
	if bot_scene == null:
		_finish()
		return

	var bot: Variant = bot_scene.instantiate()
	var player := PlayerProbe.new()
	var player_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	player_shape.shape = capsule
	player.add_child(player_shape)
	player_shape.position = Vector3(0.0, 0.9, 0.0)
	player.position = Vector3(0.0, 0.0, -6.0)
	player.add_to_group(&"player")
	bot.fire_interval = 0.05
	bot.reaction_delay = 0.08
	bot.aim_duration = 0.06
	bot.hit_chance = 1.0
	bot.damage_per_shot = 20.0
	bot.attack_range = 10.0
	bot.detection_range = 10.0
	root.add_child(bot)
	root.add_child(player)
	await physics_frame

	_check(bot.is_in_group(&"damageable"), "bot should be damageable")
	_check(bot.current_health == bot.maximum_health, "bot should begin at full health")
	_check(bot.is_alive, "bot should begin alive")
	_check(not bot.apply_damage(0.0), "zero damage should be rejected")
	_check(bot.apply_damage(25.0), "positive damage should be accepted")
	_check(bot.current_health == 75.0, "damage should reduce bot health")
	_check(bot.apply_damage(100.0), "lethal damage should be accepted")
	_check(not bot.is_alive, "lethal damage should kill bot")
	_check(not bot.apply_damage(1.0), "dead bot should reject damage")

	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 0.0)))
	_check(bot.is_alive, "respawn should restore life")
	_check(bot.current_health == bot.maximum_health, "respawn should restore health")
	_check(bot.global_position.is_equal_approx(Vector3(2.0, 0.0, 0.0)), "respawn should use the supplied transform")
	await physics_frame

	bot.global_position = Vector3.ZERO
	bot.set_target(player)
	await create_timer(0.06).timeout
	_check(player.received_damage == 0.0, "bot should not deal damage before its reaction and aim delays")
	await create_timer(0.16).timeout
	_check(player.received_damage >= bot.damage_per_shot, "bot should damage a visible target in range")
	_check(player.last_source_position is Vector3 and (player.last_source_position as Vector3).distance_to(bot.global_position) < 0.01, "bot damage should report its world position for HUD direction")
	bot.movement_enabled = true
	bot.respawn_at(Transform3D.IDENTITY)
	await physics_frame
	await physics_frame
	_check(Vector2(bot.velocity.x, bot.velocity.z).length() > 0.01, "enabled movement should produce horizontal velocity")

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: duel bot health, respawn, targeting, and visible-target fire")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
