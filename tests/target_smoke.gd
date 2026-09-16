extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var target_scene := load("res://scenes/targets/target_dummy.tscn") as PackedScene
	_check(target_scene != null, "target scene should load")
	if target_scene == null:
		_finish()
		return

	var target: Variant = target_scene.instantiate()
	target.reset_delay_seconds = 0.1
	root.add_child(target)
	await process_frame

	_check(target.is_in_group(&"damageable"), "target collider should be in the damageable group")
	_check(target.current_health == 100.0, "target should begin at 100 health")
	_check(target.is_active, "target should begin active")
	_check(not target.apply_damage(0.0), "zero damage should be rejected")
	_check(not target.apply_damage(-5.0), "negative damage should be rejected")
	_check(target.apply_damage(25.0), "positive damage should be accepted")
	_check(target.current_health == 75.0, "accepted damage should reduce health")
	_check(target.apply_damage(100.0), "lethal damage should be accepted")
	_check(target.current_health == 0.0, "lethal damage should clamp health to zero")
	_check(not target.is_active, "lethal damage should deactivate the target")
	_check(not target.apply_damage(1.0), "inactive target should reject damage")

	await create_timer(0.2).timeout
	_check(target.is_active, "target should reactivate when its reset timer expires")
	_check(target.current_health == 100.0, "reset should restore full health")
	_check(target.apply_damage(1.0), "reset target should accept damage again")

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: target damage contract, health, elimination, and reset")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
