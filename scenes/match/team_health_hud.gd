extends CanvasLayer
## Readable roster health indicators with line-of-sight and crowded-label spacing.
var player: FirstPersonPlayer
var actors: Array[Node3D] = []
var panels: Dictionary = {}
func _ready() -> void:
	layer = 2
	for actor in actors:
		if actor == player:
			continue
		var panel := VBoxContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(145, 30)
		panel.add_theme_constant_override("separation", 3)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.02, 0.03, 0.04, 0.9)
		bar.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("64e4ee") if int(actor.get("team_id")) == player.team_id else Color("ff626a")
		bar.add_theme_stylebox_override("fill", fill)
		panel.add_child(bar)
		add_child(panel)
		panels[actor.get_instance_id()] = panel
func _physics_process(_delta: float) -> void:
	var used: Array[Rect2] = []
	for actor in actors:
		if actor == player or not is_instance_valid(actor):
			continue
		var panel: VBoxContainer = panels[actor.get_instance_id()]
		panel.hide()
		if not player.is_alive or not bool(actor.get("is_alive")) or not actor.visible:
			continue
		var anchor := actor.global_position + Vector3.UP * 2.2
		if player.camera.is_position_behind(anchor):
			continue
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, actor.global_position + Vector3.UP * 1.45)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider") != actor:
			continue
		var screen := player.camera.unproject_position(anchor)
		var viewport := get_viewport().get_visible_rect().size
		if screen.x < 80 or screen.x > viewport.x - 80 or screen.y < 155 or screen.y > viewport.y - 40:
			continue
		var friendly := int(actor.get("team_id")) == player.team_id
		var label := panel.get_child(0) as Label
		label.text = "%s%s  %d" % ["+ " if friendly else "", actor.get_meta("display_name", "Robot"), ceili(float(actor.get("current_health")))]
		label.modulate = Color("64e4ee") if friendly else Color("ffae4f")
		var bar := panel.get_child(1) as ProgressBar
		bar.max_value = float(actor.get("maximum_health"))
		bar.value = float(actor.get("current_health"))
		panel.size = Vector2(145, 30)
		var rect := Rect2(screen - Vector2(72.5, 34), Vector2(145, 30))
		for attempt in range(6):
			var overlaps := false
			for other in used:
				if rect.grow(2).intersects(other):
					overlaps = true
					break
			if not overlaps:
				break
			rect.position.y -= 34
		if rect.position.y < 155:
			continue
		used.append(rect)
		panel.position = rect.position
		panel.show()
