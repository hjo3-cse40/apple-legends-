extends RefCounted
## Local presentation only. Focus never overrides distance, occlusion or life state.
var enemy_range := 24.0
var nearby_range := 8.0
var teammate_range := 36.0
var focus_angle_degrees := 6.0
var focus_hold_seconds := 0.65
var _focus_remaining: Dictionary = {}

func forget_actor(id: int) -> void:
	_focus_remaining.erase(id)

func advance(delta: float) -> void:
	for id in _focus_remaining.keys():
		_focus_remaining[id] = maxf(0.0, float(_focus_remaining[id]) - delta)
		if float(_focus_remaining[id]) <= 0.0:
			_focus_remaining.erase(id)

func can_show(player: FirstPersonPlayer, actor: Node3D, friendly: bool = false) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(actor):
		return false
	var id := actor.get_instance_id()
	if not player.is_alive or not bool(actor.get("is_alive")) or not actor.is_visible_in_tree():
		_focus_remaining.erase(id)
		return false
	var target := actor.global_position + Vector3.UP * float(actor.get("eye_height"))
	var offset := target - player.camera.global_position
	var distance := offset.length()
	if distance > (teammate_range if friendly else enemy_range) or player.camera.is_position_behind(target):
		_focus_remaining.erase(id)
		return false
	# Detailed artwork on layer 2 must occlude health, just as it occludes bullets.
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, target, 3)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.get("collider") != actor:
		_focus_remaining.erase(id)
		return false
	if friendly:
		return true
	var alignment := (-player.camera.global_basis.z).dot(offset.normalized())
	if alignment >= cos(deg_to_rad(focus_angle_degrees)):
		_focus_remaining[id] = focus_hold_seconds
	return distance <= nearby_range or float(_focus_remaining.get(id, 0.0)) > 0.0

func fits_screen(rect: Rect2, viewport_size: Vector2) -> bool:
	if not Rect2(Vector2(8, 8), viewport_size - Vector2(16, 56)).encloses(rect):
		return false
	# Reserve the clock and callouts without hiding the whole skyline.
	return not rect.intersects(Rect2(Vector2(viewport_size.x * 0.5 - 220, 8), Vector2(440, 150)))
