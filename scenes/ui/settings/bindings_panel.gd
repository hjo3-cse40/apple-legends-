class_name BindingsPanel
extends Control
signal closed
var status: Label
var rows: VBoxContainer
var waiting_action: StringName = &""
var waiting_slot := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.05, 0.08, 0.8)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -320
	panel.offset_bottom = 320
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("edf4f7")
	skin.set_corner_radius_all(18)
	skin.content_margin_left = 20
	skin.content_margin_right = 20
	skin.content_margin_top = 18
	skin.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", skin)
	var theme := Theme.new()
	theme.set_color("font_color", "Label", Color("203345"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color("203345"))
	panel.theme = theme
	var button_skin := StyleBoxFlat.new()
	button_skin.bg_color = Color("dcebf0")
	button_skin.set_corner_radius_all(6)
	theme.set_stylebox("normal", "Button", button_skin)
	var hover_skin := button_skin.duplicate() as StyleBoxFlat
	hover_skin.bg_color = Color("c6e2eb")
	theme.set_stylebox("hover", "Button", hover_skin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Keyboard & mouse bindings"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	status = Label.new()
	status.text = "Click a slot, then press a key or mouse button. Esc cancels."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var hint := Label.new()
	hint.text = "Space: variable jump height. Wheel: full-height jump per notch.\nTwo bindings per action. Saved automatically on this device."
	column.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	_refresh_rows()
	var reset := Button.new()
	reset.text = "Restore default bindings"
	reset.pressed.connect(func():
		waiting_action = &""
		PlayerInputBindings.reset()
		_refresh_rows()
		status.text = "Default bindings restored.")
	column.add_child(reset)
	var back := Button.new()
	back.text = "Back to settings  /  Esc"
	back.pressed.connect(close_panel)
	column.add_child(back)
	hide()

func _refresh_rows() -> void:
	for child in rows.get_children(): child.free()
	for index in PlayerInputBindings.ACTIONS.size():
		var action: StringName = PlayerInputBindings.ACTIONS[index]
		var row := HBoxContainer.new()
		rows.add_child(row)
		var title := Label.new()
		title.text = PlayerInputBindings.TITLES[index]
		title.custom_minimum_size.x = 130
		row.add_child(title)
		var events := InputMap.action_get_events(action)
		for slot in 2:
			var button := Button.new()
			button.text = PlayerInputBindings.binding_label(events[slot]) if slot < events.size() else "Add binding"
			button.custom_minimum_size = Vector2(150, 36)
			button.pressed.connect(func():
				waiting_action = action
				waiting_slot = slot
				status.text = "Press a key or mouse button for " + title.text + ". Esc cancels.")
			row.add_child(button)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		if waiting_action != &"":
			waiting_action = &""
			status.text = "Binding cancelled."
		else: close_panel()
		get_viewport().set_input_as_handled()
		return
	if waiting_action == &"" or not event.is_pressed() or event.is_echo(): return
	if not (event is InputEventKey or event is InputEventMouseButton): return
	var binding := event.duplicate() as InputEvent
	if binding is InputEventKey:
		if binding.physical_keycode == 0: binding.physical_keycode = binding.keycode
		binding.pressed = false
		binding.keycode = 0
	elif binding is InputEventMouseButton: binding.pressed = false
	var error := PlayerInputBindings.set_slot(waiting_action, waiting_slot, binding)
	if error.is_empty():
		waiting_action = &""
		status.text = "Binding saved."
		_refresh_rows()
	else: status.text = error
	get_viewport().set_input_as_handled()

func open_panel() -> void:
	waiting_action = &""
	_refresh_rows()
	show()

func close_panel() -> void:
	waiting_action = &""
	hide()
	closed.emit()
