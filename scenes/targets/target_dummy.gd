class_name TargetDummy
extends StaticBody3D

signal health_changed(current_health: float, maximum_health: float)
signal eliminated
signal reset

@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.01, 1.0, 0.01) var damage_flash_seconds: float = 0.10
@export_range(0.1, 10.0, 0.1) var reset_delay_seconds: float = 2.0

var current_health: float = 100.0
var is_active: bool = true

@onready var _apple: MeshInstance3D = $Visuals/Apple
@onready var _health_label: Label3D = $HealthLabel
@onready var _flash_timer: Timer = $FlashTimer
@onready var _reset_timer: Timer = $ResetTimer

var _normal_material: Material


func _ready() -> void:
	_normal_material = _apple.material_override
	_flash_timer.wait_time = damage_flash_seconds
	_reset_timer.wait_time = reset_delay_seconds
	_restore_target()


func apply_damage(amount: float) -> bool:
	if not is_active or not is_finite(amount) or amount <= 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, maximum_health)
	_update_health_label()

	if current_health <= 0.0:
		_eliminate()
	else:
		_show_damage_flash()
	return true


func _show_damage_flash() -> void:
	_apple.material_override = _make_material(Color(1.0, 0.92, 0.55), 1.7)
	_flash_timer.start(damage_flash_seconds)


func _eliminate() -> void:
	is_active = false
	_flash_timer.stop()
	_apple.material_override = _make_material(Color(0.16, 0.17, 0.16), 0.0)
	_health_label.text = "ELIMINATED\nRESETTING"
	eliminated.emit()
	_reset_timer.start(reset_delay_seconds)


func _restore_target() -> void:
	current_health = maximum_health
	is_active = true
	_apple.material_override = _normal_material
	_update_health_label()
	health_changed.emit(current_health, maximum_health)
	reset.emit()


func _update_health_label() -> void:
	_health_label.text = "%d / %d" % [roundi(current_health), roundi(maximum_health)]


func _make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material


func _on_flash_timer_timeout() -> void:
	if is_active:
		_apple.material_override = _normal_material


func _on_reset_timer_timeout() -> void:
	_restore_target()
