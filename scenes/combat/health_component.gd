class_name HealthComponent
extends Node

signal health_changed(current_health: float, maximum_health: float)
signal damaged(amount: float)
signal died
signal reset

@export_range(1.0, 10000.0, 1.0, "or_greater") var maximum_health: float = 100.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var current_health: float = 100.0

var is_dead: bool:
	get:
		return current_health <= 0.0


func _ready() -> void:
	maximum_health = _sanitized_maximum_health(maximum_health)
	current_health = clampf(current_health, 0.0, maximum_health)
	health_changed.emit(current_health, maximum_health)


func apply_damage(amount: float) -> bool:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return false

	var previous_health := current_health
	current_health = maxf(0.0, current_health - amount)
	var applied_amount := previous_health - current_health
	if applied_amount <= 0.0:
		return false

	damaged.emit(applied_amount)
	health_changed.emit(current_health, maximum_health)
	if is_dead:
		died.emit()
	return true


func reset_to_full() -> void:
	maximum_health = _sanitized_maximum_health(maximum_health)
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)
	reset.emit()


func _sanitized_maximum_health(value: float) -> float:
	if not is_finite(value) or value <= 0.0:
		return 1.0
	return value
