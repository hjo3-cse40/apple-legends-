extends CanvasLayer
## Compact local health cues; teammates retain identity, enemies require engagement.
const VisibilityPolicy = preload("res://scenes/ui/health_visibility.gd")
@export_range(1.0, 60.0, 1.0) var enemy_health_range := 24.0
@export_range(1.0, 20.0, 1.0) var nearby_health_range := 8.0
@export_range(1.0, 80.0, 1.0) var teammate_marker_range := 36.0
@export_range(1.0, 15.0, 0.5) var focus_angle_degrees := 6.0
@export_range(0.0, 2.0, 0.05) var focus_hold_seconds := 0.65
@export_range(1, 3, 1) var maximum_enemy_bars := 2
var player: FirstPersonPlayer
var actors: Array[Node3D] = []
var panels: Dictionary = {}
var visibility_policy = VisibilityPolicy.new()

func _ready() -> void:
	layer = 2
	for actor in actors:
		if actor == player:
			continue
		var panel := VBoxContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("64e4ee"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(64, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.02, 0.03, 0.04, 0.9)
		bar.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("ff626a")
		bar.add_theme_stylebox_override("fill", fill)
		panel.add_child(bar)
		add_child(panel)
		panel.hide()
		panels[actor.get_instance_id()] = panel
		if actor.has_signal("respawned"):
			actor.connect("respawned", visibility_policy.forget_actor.bind(actor.get_instance_id()))

func _physics_process(delta: float) -> void:
	visibility_policy.advance(delta)
	update_visibility()

func update_visibility() -> void:
	visibility_policy.enemy_range = enemy_health_range
	visibility_policy.nearby_range = nearby_health_range
	visibility_policy.teammate_range = teammate_marker_range
	visibility_policy.focus_angle_degrees = focus_angle_degrees
	visibility_policy.focus_hold_seconds = focus_hold_seconds
	var candidates: Array[Dictionary] = []
	for actor in actors:
		if actor == player or not is_instance_valid(actor):
			continue
		var panel: VBoxContainer = panels[actor.get_instance_id()]
		panel.hide()
		var friendly := int(actor.get("team_id")) == player.team_id
		if not visibility_policy.can_show(player, actor, friendly):
			continue
		var anchor := actor.global_position + Vector3.UP * (float(actor.get("eye_height")) + 0.42)
		var screen := player.camera.unproject_position(anchor)
		var label := panel.get_child(0) as Label
		label.visible = true
		label.text = ("+ " if friendly else "") + str(actor.get_meta("display_name", "Teammate" if friendly else "Enemy"))
		label.add_theme_color_override("font_color", Color("64e4ee") if friendly else Color("ff9298"))
		var bar := panel.get_child(1) as ProgressBar
		bar.visible = not friendly
		bar.max_value = float(actor.get("maximum_health"))
		bar.value = float(actor.get("current_health"))
		panel.custom_minimum_size = Vector2(96, 18) if friendly else Vector2(96, 23)
		panel.size = panel.get_combined_minimum_size()
		var rect := Rect2(screen - Vector2(panel.size.x * 0.5, panel.size.y + 6), panel.size)
		if not visibility_policy.fits_screen(rect, get_viewport().get_visible_rect().size):
			continue
		var center := get_viewport().get_visible_rect().size * 0.5
		candidates.append({"panel": panel, "rect": rect, "friendly": friendly, "focus": screen.distance_squared_to(center)})
	# Closest to the aim wins crowded labels; never detach a bar from its actor.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.focus) < float(b.focus))
	var used: Array[Rect2] = []
	var enemy_count := 0
	for candidate in candidates:
		if not bool(candidate.friendly) and enemy_count >= maximum_enemy_bars:
			continue
		var rect: Rect2 = candidate.rect
		var overlaps := false
		for other in used:
			if rect.grow(3).intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		used.append(rect)
		var panel: VBoxContainer = candidate.panel
		panel.position = rect.position
		panel.show()
		if not bool(candidate.friendly):
			enemy_count += 1
