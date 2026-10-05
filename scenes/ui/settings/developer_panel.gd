class_name DeveloperPanel
extends CanvasLayer
## Host-controlled match tools. No gameplay state is owned by this panel.
signal action_requested(action: String, team: int)
signal closed
var overlay: Control
var authority_buttons: Array[Button] = []
var frozen := false
var bots_enabled := true
var difficulty_slider: HSlider
var difficulty_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.08, 0.1, 0.75)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 600
	var style := StyleBoxFlat.new()
	style.bg_color = Color("edf5f7")
	style.set_corner_radius_all(22)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_label(column, "APPLE LEGENDS  /  DEVELOPER TOOLS", 15)
	_label(column, "Match laboratory", 30)
	_label(column, "Host controls affect the whole match. Max 3 players per team.", 15)
	var restart := _button(column, "Restart round", func(): action_requested.emit("restart", 0))
	authority_buttons.append(restart)
	var freeze := _button(column, "Freeze bots", func():
		frozen = not frozen
		action_requested.emit("freeze" if frozen else "unfreeze", 0))
	freeze.pressed.connect(func(): freeze.text = "Resume bots" if frozen else "Freeze bots")
	authority_buttons.append(freeze)
	var activity := _button(column, "Disable bots", func():
		bots_enabled = not bots_enabled
		action_requested.emit("bots_on" if bots_enabled else "bots_off", 0))
	activity.pressed.connect(func(): activity.text = "Disable bots" if bots_enabled else "Enable bots")
	authority_buttons.append(activity)
	difficulty_label = Label.new()
	difficulty_label.add_theme_color_override("font_color", Color("193743"))
	column.add_child(difficulty_label)
	difficulty_slider = HSlider.new()
	difficulty_slider.min_value = 0
	difficulty_slider.max_value = 2
	difficulty_slider.step = 1
	difficulty_slider.value = 1
	difficulty_slider.value_changed.connect(func(value: float):
		_update_difficulty_label(int(value))
		action_requested.emit("bot_difficulty", int(value)))
	column.add_child(difficulty_slider)
	_update_difficulty_label(1)
	for team in [1, 2]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var title := Label.new()
		title.text = "Cyan" if team == 1 else "Amber"
		title.custom_minimum_size.x = 100
		title.add_theme_color_override("font_color", Color("193743"))
		row.add_child(title)
		var add := _button(row, "+ Add bot", func(): action_requested.emit("add_bot", team))
		var remove := _button(row, "− Remove bot", func(): action_requested.emit("remove_bot", team))
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		authority_buttons.append(add)
		authority_buttons.append(remove)
	_label(column, "Adding or removing bots returns the party to the lobby.", 14)
	_button(column, "Return to lobby", func(): action_requested.emit("return_lobby", 0))
	_button(column, "Back to settings", close_panel)
	overlay.hide()

func _label(parent: Node, value: String, size: int) -> void:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color("193743"))
	parent.add_child(item)

func _button(parent: Node, value: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 42
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", Color("193743"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color("dcebef") if state == "normal" else (Color("c2e5eb") if state in ["hover", "pressed"] else Color("e5edef"))
		surface.set_corner_radius_all(10)
		surface.content_margin_top = 9
		surface.content_margin_bottom = 9
		item.add_theme_stylebox_override(state, surface)
	item.add_theme_color_override("font_hover_color", Color("193743"))
	item.add_theme_color_override("font_pressed_color", Color("193743"))
	item.add_theme_color_override("font_disabled_color", Color("81979f"))
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func open_panel(host_authority: bool = true) -> void:
	for item in authority_buttons:
		item.disabled = not host_authority
	difficulty_slider.editable = host_authority
	overlay.show()

func close_panel() -> void:
	overlay.hide()
	closed.emit()


func _update_difficulty_label(value: int) -> void:
	difficulty_label.text = ["Bots: Simple — walk to point, slow reactions", "Bots: Normal — sprint, dodge, use cover", "Bots: Expert — fast reactions, aggressive tactics"][clampi(value, 0, 2)]


func set_bot_difficulty(value: int) -> void:
	if not is_instance_valid(difficulty_slider):
		return
	difficulty_slider.set_value_no_signal(clampi(value, 0, 2))
	_update_difficulty_label(value)
