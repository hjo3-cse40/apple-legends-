class_name CombatHitbox
extends Area3D
## Shared visible MiniBot helmet target, independent of movement clearance.
const HEAD_CENTER := 1.42
const HEAD_RADIUS := 0.49
var actor: Node3D
var team_id: int:
	get: return int(actor.get("team_id"))

func _ready() -> void:
	add_to_group(&"damageable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = false
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HEAD_RADIUS
	collision.shape = sphere
	collision.position.y = HEAD_CENTER
	add_child(collision)
	actor.health_changed.connect(func(_current: float, _maximum: float): _update_enabled())
	_update_enabled()

func _physics_process(_delta: float) -> void:
	_update_enabled()

func _update_enabled() -> void:
	collision_layer = 1 if bool(actor.get("is_alive")) and bool(actor.get_meta("combat_enabled", true)) else 0

func apply_damage(amount: float, source: Variant = null) -> bool:
	return bool(actor.call("apply_damage", amount, source))
