extends CanvasLayer
## UI keeps processing while the gameplay tree is paused.
const DEFAULT_SENSITIVITY := 0.0018
const SAVE_PATH := "user://controls.cfg"
var player: FirstPersonPlayer
var overlay: Control
var slider: HSlider
var value_label: Label
var freeze_button: CheckButton
var arena: Node
var is_open := false
var variant := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	arena = get_parent()
	player = arena.get_node("Player") as FirstPersonPlayer
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		player.mouse_sensitivity = clampf(float(config.get_value("controls", "sensitivity", DEFAULT_SENSITIVITY)), 0.00036, 0.0054)
	build_menu()

func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box

func label(text: String, size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	return item

func build_menu() -> void:
	if is_instance_valid(overlay):
		overlay.free()
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.05, 0.08, 0.6)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	if variant == 0:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		panel.position = Vector2(800, 35)
		panel.size = Vector2(440, 650)
	elif variant == 1:
		panel.position = Vector2(350, 90)
		panel.size = Vector2(580, 540)
	else:
		panel.position = Vector2(70, 100)
		panel.size = Vector2(540, 540)
	var light := variant != 1
	var ink := Color("203345") if light else Color("e7f4ff")
	var muted := Color("526a7d") if light else Color("9bb4c9")
	panel.add_theme_stylebox_override("panel", style(Color("edf4f7") if light else Color("122536"), 18))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(label("A1   /   APPLE LEGENDS", 16, muted))
	column.add_child(label("SYSTEM SETTINGS" if variant == 2 else "Settings", 34, ink))
	column.add_child(label("GARDEN CIRCUIT  •  PAUSED", 16, Color("058bad")))
	column.add_child(HSeparator.new())
	column.add_child(label("CONTROLS", 14, muted))
	var row := HBoxContainer.new()
	column.add_child(row)
	var title := label("Mouse sensitivity", 21, ink)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	value_label = label("", 21, Color("058bad"))
	row.add_child(value_label)
	slider = HSlider.new()
	slider.custom_minimum_size.y = 32
	slider.min_value = 0.2
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = player.mouse_sensitivity / DEFAULT_SENSITIVITY
	var track := style(Color("b5c9d4"), 4)
	track.content_margin_left = 0
	track.content_margin_right = 0
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color("0ab5da")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	column.add_child(slider)
	slider.value_changed.connect(_sensitivity_changed)
	_refresh_value()
	column.add_child(label("0.20×   Precise                         Fast   3.00×", 14, muted))
	column.add_child(label("Saved automatically on this device", 14, muted))
	column.add_child(HSeparator.new())
	column.add_child(label("PRACTICE", 14, muted))
	freeze_button = CheckButton.new()
	freeze_button.text = "Freeze test bot  /  F1"
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		freeze_button.add_theme_color_override(state, ink)
	freeze_button.add_theme_font_size_override("font_size", 19)
	freeze_button.button_pressed = arena.opponent_paused
	freeze_button.toggled.connect(_freeze_changed)
	column.add_child(freeze_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var resume := Button.new()
	resume.text = "Resume game    /    Esc"
	resume.custom_minimum_size.y = 52
	resume.add_theme_font_size_override("font_size", 20)
	resume.add_theme_color_override("font_color", Color("072b3b"))
	resume.add_theme_stylebox_override("normal", style(Color("42c9e8")))
	resume.add_theme_stylebox_override("hover", style(Color("7dddf1")))
	resume.add_theme_stylebox_override("pressed", style(Color("15acca")))
	resume.pressed.connect(close_menu)
	column.add_child(resume)
	var reset := Button.new()
	reset.text = "Reset sensitivity to 1.00×"
	reset.add_theme_color_override("font_color", muted)
	reset.add_theme_color_override("font_hover_color", ink)
	reset.add_theme_stylebox_override("normal", style(Color(0, 0, 0, 0), 6))
	reset.add_theme_stylebox_override("hover", style(Color(0.1, 0.5, 0.6, 0.12), 6))
	reset.pressed.connect(func(): slider.value = 1.0)
	column.add_child(reset)
	overlay.visible = is_open

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if is_open:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	player._release_mouse()
	freeze_button.set_pressed_no_signal(arena.opponent_paused)
	overlay.show()
	get_tree().paused = true
	slider.grab_focus()

func close_menu() -> void:
	is_open = false
	overlay.hide()
	get_tree().paused = false
	player.weapon.cancel_pending_input()
	player._capture_mouse()

func _sensitivity_changed(value: float) -> void:
	player.mouse_sensitivity = DEFAULT_SENSITIVITY * value
	_refresh_value()
	var config := ConfigFile.new()
	config.set_value("controls", "sensitivity", player.mouse_sensitivity)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save sensitivity: " + str(error))

func _refresh_value() -> void:
	value_label.text = "%.2f×" % slider.value

func _freeze_changed(frozen: bool) -> void:
	arena.opponent_paused = frozen
	var bot := arena.get_node("DuelBot") as CharacterBody3D
	bot.set_physics_process(not frozen)
	bot.velocity = Vector3.ZERO
	bot.get_node("Visuals/MuzzleFlash").hide()
	arena._update_status()
