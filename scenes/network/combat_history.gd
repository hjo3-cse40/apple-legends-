extends RefCounted
## Rewind only combat geometry; live bodies and movement never change.
const MAX_REWIND := 0.35
const RETAIN_SECONDS := 0.60
var samples: Array[Dictionary] = []

func record(actors: Dictionary, generations: Dictionary, time: float) -> void:
	var states: Dictionary = {}
	for id in actors:
		var actor: CollisionObject3D = actors[id]
		states[id] = {"position": actor.global_position, "generation": int(generations[id]), "alive": bool(actor.get("is_alive")) and bool(actor.get_meta("combat_enabled", true))}
	if not samples.is_empty() and time <= float(samples[-1].time):
		return
	samples.append({"time": time, "states": states})
	while samples.size() > 2 and float(samples[1].time) < time - RETAIN_SECONDS:
		samples.pop_front()

func position_at(id: String, view: Dictionary, generation: int, now: float) -> Variant:
	if not (view.get("time") is float or view.get("time") is int) or not view.get("generation") is int:
		return null
	var time := float(view.time)
	if not is_finite(time) or time > now + 0.01 or now - time > MAX_REWIND or int(view.get("generation", -1)) != generation or samples.is_empty():
		return null
	if time < float(samples[0].time) - 0.001 or time > float(samples[-1].time) + 0.001:
		return null
	for index in range(samples.size()):
		var right: Dictionary = samples[index]
		if float(right.time) + 0.001 < time:
			continue
		var left: Dictionary = samples[maxi(0, index - 1)]
		if not left.states.has(id) or not right.states.has(id): return null
		var a: Dictionary = left.states[id]
		var b: Dictionary = right.states[id]
		if absf(time - float(right.time)) < 0.001:
			return b.position if int(b.generation) == generation and bool(b.alive) else null
		if int(a.generation) != generation or int(b.generation) != generation or not bool(a.alive) or not bool(b.alive): return null
		var weight := clampf((time - float(left.time)) / maxf(0.001, float(right.time) - float(left.time)), 0.0, 1.0)
		return (a.position as Vector3).lerp(b.position, weight)
	return null

func intersect_view(world: World3D, actors: Dictionary, generations: Dictionary, shooter_id: String, origin: Vector3, direction: Vector3, maximum_range: float, views: Dictionary) -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var exclude: Array[RID] = []
	for actor in actors.values():
		exclude.append(actor.get_rid())
		var head := actor.get_node_or_null("CombatHead") as CollisionObject3D
		if head != null: exclude.append(head.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * maximum_range)
	query.exclude = exclude
	query.collide_with_areas = true
	var world_hit := world.direct_space_state.intersect_ray(query)
	var closest := origin.distance_to(world_hit.position) if not world_hit.is_empty() else maximum_range
	var result: Dictionary = {}
	for id in actors:
		if id == shooter_id: continue
		var actor: CollisionObject3D = actors[id]
		if not bool(actor.get("is_alive")) or not bool(actor.get_meta("combat_enabled", true)): continue
		var position := actor.global_position
		var damage_allowed := true
		if views.has(id):
			var historical: Variant = position_at(id, views[id], int(generations[id]), now) if views[id] is Dictionary else null
			# Invalid/stale geometry can only block at its current authoritative pose.
			# An unrelated respawn must not invalidate a shot at another enemy.
			if historical is Vector3:
				position = historical
			else:
				damage_allowed = false
		var shape_node := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node == null and actor is RemoteActor: shape_node = actor._shape
		if shape_node == null or not shape_node.shape is CapsuleShape3D: continue
		var capsule := shape_node.shape as CapsuleShape3D
		var distance := ray_capsule(origin, direction, position + shape_node.position, capsule.radius, capsule.height)
		if actor.has_node("CombatHead"):
			distance = minf(distance, ray_sphere(origin, direction, position + Vector3.UP * CombatHitbox.HEAD_CENTER, CombatHitbox.HEAD_RADIUS))
		if distance >= 0.0 and distance < closest:
			closest = distance
			result = {"collider": actor, "position": origin + direction * distance} if damage_allowed else {}
	return result

static func ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> float:
	var offset := origin - center
	var b := offset.dot(direction)
	var c := offset.length_squared() - radius * radius
	if c <= 0.0: return 0.0
	var discriminant := b * b - c
	if discriminant < 0.0: return INF
	var distance := -b - sqrt(discriminant)
	return distance if distance >= 0.0 else INF

static func ray_capsule(origin: Vector3, direction: Vector3, center: Vector3, radius: float, height: float) -> float:
	var half_segment := maxf(0.0, height * 0.5 - radius)
	var offset := origin - center
	var result := minf(ray_sphere(origin, direction, center + Vector3.UP * half_segment, radius), ray_sphere(origin, direction, center - Vector3.UP * half_segment, radius))
	var a := direction.x * direction.x + direction.z * direction.z
	var b := offset.x * direction.x + offset.z * direction.z
	var c := offset.x * offset.x + offset.z * offset.z - radius * radius
	if absf(offset.y) <= half_segment and c <= 0.0: return 0.0
	var discriminant := b * b - a * c
	if a > 0.000001 and discriminant >= 0.0:
		var distance := (-b - sqrt(discriminant)) / a
		if distance >= 0.0 and absf(offset.y + direction.y * distance) <= half_segment:
			result = minf(result, distance)
	return result
