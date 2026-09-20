extends SceneTree

var _failures: Array[String] = []
var _signal_counts := {
	"ammo": 0,
	"fired": 0,
	"hit": 0,
}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var test_world := Node3D.new()
	root.add_child(test_world)

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as FirstPersonPlayer
	test_world.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var weapon := player.weapon
	weapon.enable_fire_sound = false
	weapon.seconds_between_shots = 0.05
	weapon.reload_duration = 0.05
	weapon.ammo_changed.connect(func(_current: int, _capacity: int) -> void: _signal_counts.ammo += 1)
	weapon.fired.connect(func() -> void: _signal_counts.fired += 1)
	weapon.hit_confirmed.connect(func() -> void: _signal_counts.hit += 1)
	for _step in 8:
		await physics_frame

	_check(get_first_node_in_group(&"player_weapon") == weapon, "rifle should be discoverable through player_weapon before HUD lookup")
	_check(weapon.magazine_size == 12 and weapon.ammo_in_magazine == 12, "rifle should start with a full 12-round magazine")
	_check(is_equal_approx(player.camera.fov, player.field_of_view), "rifle should preserve the player's configured hip FOV")
	_check(weapon._player_body == player, "hitscan should identify the player body for exclusion")

	var target_scene := load("res://scenes/targets/target_dummy.tscn") as PackedScene
	var target := target_scene.instantiate() as TargetDummy
	target.position = Vector3(0.0, -0.43, -6.0)
	test_world.add_child(target)
	await physics_frame

	weapon.request_fire()
	await physics_frame
	_check(weapon.ammo_in_magazine == 11, "one fire request should consume exactly one round")
	_check(is_equal_approx(target.current_health, target.maximum_health - weapon.damage), "camera ray should damage a centered target")
	_check(_signal_counts.fired == 1 and _signal_counts.hit == 1, "accepted hit should emit fired and hit_confirmed once")
	_check(weapon._camera_kick_amount > 0.0, "firing should trigger camera feedback")
	_check(weapon._impact_spawn_count == 1, "a surface hit should spawn one bullet impact")

	weapon.request_fire()
	await physics_frame
	_check(weapon.ammo_in_magazine == 11, "cooldown should reject a second immediate fire request")
	for _step in 5:
		await physics_frame
	_check(weapon.ammo_in_magazine == 11, "a single press should not repeat after cooldown")

	var blocker := _make_blocker(Vector3(0.0, 1.62, -3.0))
	test_world.add_child(blocker)
	await physics_frame
	weapon.request_fire()
	await physics_frame
	_check(weapon.ammo_in_magazine == 10, "an occluded shot should still consume one round")
	_check(is_equal_approx(target.current_health, target.maximum_health - weapon.damage), "first collider should occlude the damageable target")
	_check(_signal_counts.hit == 1, "an occluded shot should not confirm a hit")

	blocker.queue_free()
	target.position.x = 4.0
	for _step in 5:
		await physics_frame
	weapon.request_fire()
	await physics_frame
	_check(weapon.ammo_in_magazine == 9, "a miss should consume one round")
	_check(_signal_counts.hit == 1, "a miss should not confirm a hit")

	weapon.request_reload()
	await physics_frame
	_check(weapon.is_reloading, "reload request should enter the reload state")
	var rounds_during_reload := weapon.ammo_in_magazine
	var fired_before_reload_shot := int(_signal_counts.fired)
	weapon.request_fire()
	await physics_frame
	_check(weapon.ammo_in_magazine == rounds_during_reload and _signal_counts.fired == fired_before_reload_shot, "fire requests should be rejected during reload")
	_check(weapon.model_root.position.distance_to(weapon.hip_position) > 0.02, "reload should visibly move the viewmodel")
	for _step in 5:
		await physics_frame
	_check(not weapon.is_reloading and weapon.ammo_in_magazine == weapon.magazine_size, "reload should refill from the infinite practice reserve")

	weapon.ammo_in_magazine = 0
	var fired_before_empty_shot := int(_signal_counts.fired)
	weapon.request_fire()
	await physics_frame
	_check(weapon.ammo_in_magazine == 0 and _signal_counts.fired == fired_before_empty_shot, "an empty magazine should reject fire requests")
	weapon.request_reload()
	await physics_frame
	for _step in 5:
		await physics_frame
	_check(weapon.ammo_in_magazine == weapon.magazine_size, "an empty magazine should reload from the infinite practice reserve")

	weapon.request_fire()
	weapon.set_aiming(true)
	player._release_mouse()
	await physics_frame
	_check(weapon.ammo_in_magazine == weapon.magazine_size, "releasing capture should cancel a queued shot")
	_check(not weapon._aim_requested, "releasing capture should cancel held ADS intent")

	var recapture_click := InputEventMouseButton.new()
	recapture_click.button_index = MOUSE_BUTTON_LEFT
	recapture_click.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	weapon._unhandled_input(recapture_click)
	_check(not weapon._fire_queued, "a visible-cursor click should not queue a shot")
	player._unhandled_input(recapture_click)
	weapon._unhandled_input(recapture_click)
	_check(not weapon._fire_queued, "the recapture click should remain suppressed regardless of input callback order")
	var recapture_release := InputEventMouseButton.new()
	recapture_release.button_index = MOUSE_BUTTON_LEFT
	recapture_release.pressed = false
	weapon._unhandled_input(recapture_release)
	_check(not weapon._fire_suppressed_until_release, "releasing recapture click should arm the next deliberate shot")
	weapon.cancel_pending_input()

	_check(_signal_counts.ammo >= 4, "ammo_changed should report firing and reload changes")
	if _failures.is_empty():
		print("PASS: rifle hit, miss, impact feedback, firing kick, occlusion, cooldown, animated reload lockout, input cancellation, signals, and hip FOV")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _make_blocker(position_value: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 0.5)
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
