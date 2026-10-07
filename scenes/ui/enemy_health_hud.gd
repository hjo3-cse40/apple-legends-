class_name EnemyHealthHUD
extends CanvasLayer
## Offline opponent uses the same bounded local focus/LOS policy as LAN actors.
const VisibilityPolicy = preload("res://scenes/ui/health_visibility.gd")
@export_range(1.0, 60.0, 1.0) var enemy_health_range := 24.0
@export_range(1.0, 20.0, 1.0) var nearby_health_range := 8.0
@export_range(1.0, 15.0, 0.5) var focus_angle_degrees := 6.0
@export_range(0.0, 2.0, 0.05) var focus_hold_seconds := 0.65
var player: FirstPersonPlayer
var enemy: DuelBot
var panel: VBoxContainer
var readout: Label
var bar: ProgressBar
var visibility_policy = VisibilityPolicy.new()

func _ready() -> void:
	layer = 2
	panel = VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	# Show identity with the bar under the same visibility rules.
	readout = Label.new()
	readout.text = str(enemy.get_meta("display_name", "Enemy"))
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size", 12)
	readout.add_theme_color_override("font_color", Color("ff9298"))
	readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	readout.add_theme_constant_override("shadow_offset_x", 1)
	readout.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_theme_constant_override("separation", 2)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(readout)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(64, 5)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.03, 0.04, 0.9)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff626a")
	bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(bar)
	panel.hide()
	enemy.respawned.connect(visibility_policy.forget_actor.bind(enemy.get_instance_id()))

func _physics_process(delta: float) -> void:
	visibility_policy.advance(delta)
	update_visibility()

func update_visibility() -> void:
	panel.hide()
	visibility_policy.enemy_range = enemy_health_range
	visibility_policy.nearby_range = nearby_health_range
	visibility_policy.focus_angle_degrees = focus_angle_degrees
	visibility_policy.focus_hold_seconds = focus_hold_seconds
	if not visibility_policy.can_show(player, enemy):
		return
	var anchor := enemy.global_position + Vector3.UP * (enemy.eye_height + 0.42)
	var screen := player.camera.unproject_position(anchor)
	panel.custom_minimum_size = Vector2(96, 23)
	panel.size = panel.get_combined_minimum_size()
	var rect := Rect2(screen - Vector2(panel.size.x * 0.5, panel.size.y + 6), panel.size)
	if not visibility_policy.fits_screen(rect, get_viewport().get_visible_rect().size):
		return
	bar.max_value = enemy.maximum_health
	bar.value = enemy.current_health
	panel.position = rect.position
	panel.show()
