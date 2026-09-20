extends SceneTree

const HEALTH_COMPONENT := preload("res://scenes/combat/health_component.gd")

var _failures: Array[String] = []
var _health_change_count := 0
var _damage_count := 0
var _death_count := 0
var _reset_count := 0
var _last_damage_amount := 0.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var health := HEALTH_COMPONENT.new()
	health.maximum_health = 125.0
	health.current_health = 75.0
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(func() -> void: _death_count += 1)
	health.reset.connect(func() -> void: _reset_count += 1)
	root.add_child(health)
	await process_frame

	_check(health.maximum_health == 125.0, "configured maximum health should be preserved")
	_check(health.current_health == 75.0, "configured current health should be preserved")
	_check(not health.is_dead, "a component with positive health should be alive")
	_check(_health_change_count == 1, "ready should publish initial health")

	_check(not health.apply_damage(0.0), "zero damage should be rejected")
	_check(not health.apply_damage(-5.0), "negative damage should be rejected")
	_check(not health.apply_damage(NAN), "non-finite damage should be rejected")
	_check(_damage_count == 0 and _health_change_count == 1, "rejected damage should not emit signals")

	_check(health.apply_damage(25.0), "positive damage should be accepted while alive")
	_check(health.current_health == 50.0, "damage should reduce current health")
	_check(_damage_count == 1 and _last_damage_amount == 25.0, "damaged should report applied damage")
	_check(_health_change_count == 2, "accepted damage should publish health")

	_check(health.apply_damage(500.0), "lethal damage should be accepted")
	_check(health.current_health == 0.0 and health.is_dead, "lethal damage should clamp health to zero")
	_check(_last_damage_amount == 50.0, "overkill should report only health actually removed")
	_check(_death_count == 1, "lethal damage should emit died exactly once")
	_check(not health.apply_damage(1.0), "damage while dead should be rejected")
	_check(_death_count == 1 and _damage_count == 2, "dead damage should not emit combat signals")

	health.reset_to_full()
	_check(health.current_health == 125.0 and not health.is_dead, "reset should restore full health and revive")
	_check(_reset_count == 1, "reset should emit once")
	_check(_health_change_count == 4, "reset should publish restored health")
	_check(health.apply_damage(1.0), "reset component should accept damage again")

	_finish()


func _on_health_changed(_current_health: float, _maximum_health: float) -> void:
	_health_change_count += 1


func _on_damaged(amount: float) -> void:
	_damage_count += 1
	_last_damage_amount = amount


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: health configuration, damage rejection, death, signals, and reset")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
