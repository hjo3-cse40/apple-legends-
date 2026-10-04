class_name EnemyHealthHUD
extends CanvasLayer
## Screen-space health anchored to the visible opponent; world collision gates visibility.

var player: FirstPersonPlayer
var enemy: DuelBot
var panel: VBoxContainer
var readout: Label
var bar: ProgressBar

func _ready() -> void:
	layer = 2
	panel = VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 3)
	add_child(panel)
	readout = Label.new()
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size", 15)
	readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	readout.add_theme_constant_override("shadow_offset_x", 1)
	readout.add_theme_constant_override("shadow_offset_y", 1)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(readout)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 8)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.02, 0.02, 0.95)
	background.set_border_width_all(1)
	background.border_color = Color(0.9, 0.8, 0.8, 0.8)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff626a")
	bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(bar)
	panel.hide()

func _physics_process(_delta: float) -> void:
	update_visibility()

func update_visibility() -> void:
	panel.hide()
	if not is_instance_valid(player) or not is_instance_valid(enemy) or not player.is_alive or not enemy.is_alive:
		return
	var camera := player.camera
	var anchor := enemy.global_position + Vector3.UP * (enemy.eye_height + 0.65)
	if camera.is_position_behind(anchor):
		return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, enemy.global_position + Vector3.UP * enemy.eye_height)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.get("collider") != enemy:
		return
	var screen := camera.unproject_position(anchor)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen.x < 70.0 or screen.x > viewport_size.x - 70.0 or screen.y < 155.0 or screen.y > viewport_size.y - 40.0:
		return
	bar.max_value = enemy.maximum_health
	bar.value = enemy.current_health
	readout.text = "ENEMY  %d / %d" % [ceili(enemy.current_health), ceili(enemy.maximum_health)]
	panel.size = Vector2(140, 32)
	panel.position = screen - Vector2(70, 32)
	panel.show()
