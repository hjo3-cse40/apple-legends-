extends SceneTree
## Native captures use the real LAN garden, bot models, and remote-human actor type.
const TeamHUD = preload("res://scenes/match/team_health_hud.gd")
var failures: Array[String] = []
var arena: Node3D
var player: FirstPersonPlayer
var manager: TeamMatchManager
var hud: CanvasLayer
var enemy: Node3D
var enemy_bot: Node3D
var third_enemy: Node3D
var teammate: Node3D

func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func panel(actor: Node3D) -> VBoxContainer:
	return hud.panels[actor.get_instance_id()]
func place(actor: Node3D, point: Vector3) -> void:
	actor.call("respawn_at", Transform3D(Basis.IDENTITY, point))
	actor.show()
func settle() -> void:
	await physics_frame
	await physics_frame
	hud.update_visibility()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 8: await process_frame
	hud.update_visibility()
	await RenderingServer.frame_post_draw
	var size := root.get_texture().get_size()
	var path := "res://work/health-%s-%dx%d.png" % [label, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	print("HEALTH_CAPTURE: " + ProjectSettings.globalize_path(path))
	print("HEALTH_WINDOW: size=%s scale=%s design=%s" % [root.size, root.content_scale_factor, root.content_scale_size])

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
			root.content_scale_factor = 1.0
			root.content_scale_size = root.size
	var session: Node = root.get_node("LanSession")
	session.leave_lobby()
	session.connected = true
	session.in_match = true
	session.roster = [{"id":"human_1", "peer_id":1, "name":"Sam", "team":1, "bot":false, "ready":true}]
	# Synthetic roster membership exercises the exact human presentation component;
	# connection/shot authority is covered independently by the LAN process fixtures.
	session.roster.append({"id":"human_2", "peer_id":2, "name":"Teammate", "team":1, "bot":false, "ready":true})
	session.roster.append({"id":"human_3", "peer_id":3, "name":"Opponent", "team":2, "bot":false, "ready":true})
	session.roster.append({"id":"bot_1", "peer_id":0, "name":"Robot 1", "team":1, "bot":true, "ready":true})
	session.roster.append({"id":"bot_2", "peer_id":0, "name":"Robot 2", "team":2, "bot":true, "ready":true})
	session.roster.append({"id":"bot_3", "peer_id":0, "name":"Robot 3", "team":2, "bot":true, "ready":true})
	arena = (load("res://scenes/levels/garden/lan_garden.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await process_frame
	manager = arena.get_node("DuelManager")
	player = arena.get_node("Player")
	manager.set_physics_process(false)
	player.set_physics_process(false)
	player.weapon.set_physics_process(false)
	for child in manager.get_children():
		if child.get_script() == TeamHUD: hud = child
	check(hud != null, "LAN roster HUD exists")
	hud.set_physics_process(false)
	enemy = manager.actors["human_3"]
	teammate = manager.actors["human_2"]
	var enemies: Array[Node3D] = []
	for id in manager.actors:
		var actor: Node3D = manager.actors[id]
		actor.set_physics_process(false)
		if actor is DuelBot and actor.team_id == 2: enemies.append(actor)
		if actor != player: place(actor, Vector3(100, 200, -12))
	enemy_bot = enemies[0]
	third_enemy = enemies[1]
	place(player, Vector3(0, 200, 0))
	player.camera_pivot.rotation = Vector3.ZERO
	place(enemy, Vector3(0, 200, -12))
	await settle()
	check(panel(enemy).visible, "focused remote human at 12 units shows compact health")
	check(not (panel(enemy).get_child(0) as Label).visible, "enemies have no name or numeric-health clutter")
	enemy.call("apply_damage", 44.0)
	hud.update_visibility()
	check(is_equal_approx((panel(enemy).get_child(1) as ProgressBar).value, 56), "bar follows actual remote-human health")
	place(enemy_bot, Vector3(0, 200, -12))
	place(enemy, Vector3(100, 200, -12))
	await settle()
	check(panel(enemy_bot).visible, "host bot has the same focus rule")
	place(enemy_bot, Vector3(100, 200, -12))
	place(enemy, Vector3(0, 200, -25))
	await settle()
	check(not panel(enemy).visible, "even focused target beyond 24-unit range hides")
	place(enemy, Vector3(7, 200, -12))
	await settle()
	check(not panel(enemy).visible, "off-axis middle-distance enemy hides")
	place(enemy, Vector3(4, 200, -5))
	await settle()
	check(panel(enemy).visible, "nearby off-axis enemy within 8 units shows")
	place(enemy, Vector3(0, 200, -12))
	await settle()
	enemy.position.x = 2.5
	await settle()
	check(panel(enemy).visible, "brief focus grace avoids aim-edge flicker")
	hud.visibility_policy.advance(0.7)
	hud.update_visibility()
	check(not panel(enemy).visible, "focus grace expires after 0.65 seconds")
	place(enemy, Vector3(0, 200, -12))
	await settle()
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 5, 1)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(0, 201.5, -6)
	arena.add_child(blocker)
	await settle()
	check(not panel(enemy).visible, "layer-2 artwork immediately hides focused/recently focused enemy")
	blocker.queue_free()
	await settle()
	check(panel(enemy).visible, "health returns only when visible again")
	enemy.call("apply_damage", 100.0)
	hud.update_visibility()
	check(not panel(enemy).visible, "dead enemy hides")
	place(enemy, Vector3(7, 200, -12))
	await settle()
	check(not panel(enemy).visible, "respawn clears previous-life focus")
	place(teammate, Vector3(-4, 200, -16))
	await settle()
	check(panel(teammate).visible, "visible teammate remains identifiable off-axis")
	check((panel(teammate).get_child(0) as Label).visible and not (panel(teammate).get_child(1) as ProgressBar).visible, "teammate gets identity without redundant health")
	place(teammate, Vector3(0, 200, -37))
	await settle()
	check(not panel(teammate).visible, "teammate marker has bounded 36-unit range")
	place(enemy, Vector3(0, 200, -5))
	place(enemy_bot, Vector3(1.5, 200, -5))
	place(third_enemy, Vector3(-1.5, 200, -5))
	await settle()
	var visible_enemies := 0
	for actor in [enemy, enemy_bot, third_enemy]:
		if panel(actor).visible: visible_enemies += 1
	check(visible_enemies == 2, "three nearby enemies capped to two anchored bars")
	player.apply_damage(74)
	var own_hud := arena.get_node("DebugHUD") as DebugHUD
	own_hud._process(0)
	check(own_hud.health_readout.text == "26 HP" and is_equal_approx(own_hud.health_bar.value, 26), "own compact number and bar follow damage")
	check(own_hud.health_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "new bar cannot consume wheel or aiming input")
	player.apply_damage(100)
	hud.update_visibility()
	check(not panel(enemy).visible and not panel(teammate).visible, "dead viewer sees no actor cues")
	# Actual garden view: focused damaged human, nearby bot crowd, cyan teammate.
	place(player, Vector3(0, 0.3, 18))
	place(enemy, Vector3(0, 0.3, 6))
	enemy.call("apply_damage", 44.0)
	place(enemy_bot, Vector3(1.5, 0.3, 12))
	place(third_enemy, Vector3(-1.5, 0.3, 12))
	place(teammate, Vector3(-3.5, 0.3, 7))
	for actor in manager.actors.values():
		if actor != player and actor != teammate and actor != enemy and actor != enemy_bot and actor != third_enemy:
			place(actor, Vector3(3.5, 0.3, 7))
	await settle()
	check(panel(enemy).visible, "native garden focused human is visible")
	await capture("focused-crowd")
	# No enemy overlays when the crowd is distant/off-axis or occluded by artwork.
	place(enemy, Vector3(0, 0.3, -12))
	place(enemy_bot, Vector3(7, 0.3, 6))
	place(third_enemy, Vector3(-7, 0.3, 6))
	hud.visibility_policy.advance(1.0)
	await settle()
	check(not panel(enemy).visible and not panel(enemy_bot).visible and not panel(third_enemy).visible, "garden far/off-axis crowd hides health")
	await capture("off-axis-far")
	place(enemy, Vector3(0, 0.3, 6))
	var cover := StaticBody3D.new()
	cover.collision_layer = 2
	var collision := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(3, 3, 0.5)
	collision.shape = cover_box
	cover.add_child(collision)
	var mesh := MeshInstance3D.new()
	var art_box := BoxMesh.new()
	art_box.size = cover_box.size
	mesh.mesh = art_box
	cover.add_child(mesh)
	cover.position = Vector3(0, 1.5, 12)
	arena.add_child(cover)
	await settle()
	check(not panel(enemy).visible, "garden cover hides enemy health")
	await capture("occluded")
	cover.queue_free()
	session.leave_lobby()
	arena.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("TEAM_HEALTH_PASS: shared human/bot focus, bounded distance, nearby reveal, grace/respawn, layer-2 occlusion, crowd cap, teammate identity, own HP and native garden")
	quit(0 if failures.is_empty() else 1)
