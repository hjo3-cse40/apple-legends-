class_name KothHUD
extends CanvasLayer
## Objective presentation observes the manager's snapshot; it never advances time.

const CYAN := Color("64e4ee")
const AMBER := Color("ffc06c")
var clocks: Label
var state: Label
var capture: ProgressBar
var result: Label

func _ready() -> void:
	layer = 3
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -205
	panel.offset_right = 205
	panel.offset_top = 18
	panel.offset_bottom = 120
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.11, 0.9)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)
	clocks = Label.new()
	clocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clocks.add_theme_font_size_override("font_size", 27)
	layout.add_child(clocks)
	state = Label.new()
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 15)
	layout.add_child(state)
	capture = ProgressBar.new()
	capture.custom_minimum_size = Vector2(0, 7)
	capture.max_value = 1.0
	capture.show_percentage = false
	layout.add_child(capture)
	result = Label.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result.offset_left = -280
	result.offset_right = 280
	result.offset_top = -70
	result.offset_bottom = 70
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 32)
	result.add_theme_color_override("font_shadow_color", Color.BLACK)
	result.add_theme_constant_override("shadow_offset_x", 2)
	result.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(result)
	result.hide()

func set_koth_state(snapshot: Dictionary, cyan_count: int, amber_count: int) -> void:
	if clocks == null:
		return
	var times: Dictionary = snapshot["team_seconds_remaining"]
	clocks.text = "CYAN  %s     %s  AMBER" % [_clock(times[1]), _clock(times[2])]
	var owner := int(snapshot["owner_team"])
	var cap_team := int(snapshot["capturing_team"])
	var tint := CYAN if (cap_team if cap_team != 0 else owner) == 1 else AMBER
	capture.value = float(snapshot["capture_progress"])
	capture.modulate = tint if owner != 0 or cap_team != 0 else Color.WHITE
	state.modulate = tint if owner != 0 or cap_team != 0 else Color.WHITE
	if float(snapshot["unlock_remaining"]) > 0.0:
		state.text = "POINT UNLOCKS IN %d" % ceili(float(snapshot["unlock_remaining"]))
	elif bool(snapshot["contested"]):
		state.text = "CONTESTED — CAPTURE & CLOCKS PAUSED"
	elif bool(snapshot["overtime"]):
		state.text = "OVERTIME — CLEAR THE POINT"
	elif cap_team != 0:
		var cap_occupants := cyan_count if cap_team == 1 else amber_count
		state.text = ("%s CAPTURING  %d%%" % [_team(cap_team), roundi(capture.value * 100)]) if cap_occupants > 0 else "CAPTURE FADING  %d%%" % roundi(capture.value * 100)
	elif owner != 0:
		state.text = "%s HOLDS THE POINT" % _team(owner)
	else:
		state.text = "STAND ON THE POINT TO CAPTURE"
	state.tooltip_text = "On point: Cyan %d / Amber %d" % [cyan_count, amber_count]
	result.visible = bool(snapshot["match_over"])
	if result.visible:
		var winner := int(snapshot["winner_team"])
		result.modulate = CYAN if winner == 1 else AMBER
		result.text = "%s WINS\n%s\nEnter to play again" % [_team(winner), "VICTORY" if winner == 1 else "DEFEAT"]

func _team(team: int) -> String:
	return "CYAN" if team == 1 else "AMBER"

func _clock(seconds: float) -> String:
	var rounded := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [rounded / 60, rounded % 60]
