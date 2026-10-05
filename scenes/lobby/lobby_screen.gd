extends Control
## Private LAN lobby; the session owns membership and match rules.
signal play_requested
const INK := Color("08162d")
const MUTED := Color("5d6f88")
const CYAN := Color("00cfe8")
const AMBER := Color("ffbf15")
var session: Node
var hero_portrait: TextureRect
var roster_columns: Array[VBoxContainer] = []
var team_buttons: Array[Button] = []
var bot_add_buttons: Array[Button] = []
var bot_remove_buttons: Array[Button] = []
var name_input: LineEdit
var address_input: LineEdit
var status_label: Label
var room_label: Label
var ready_button: Button
var start_button: Button
var host_button: Button
var join_button: Button
var fill_button: Button
var leave_button: Button
var local_ready := false
var design: Control
var connect_panel: PanelContainer
var team_counts: Array[Label] = []
var team_panels: Array[PanelContainer] = []
var auto_fill: CheckButton
var empty_buttons: Array[Button] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	session = get_node_or_null("/root/LanSession")
	if session != null:
		_bind_session()
	else:
		status_label.text = "Preview • private LAN lobby"
		_render_roster([])

func box(color: Color, radius: int = 18) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.content_margin_left = 20
	result.content_margin_right = 20
	result.content_margin_top = 16
	result.content_margin_bottom = 16
	return result

func text_label(value: String, font_size: int = 18, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next Condensed", "Avenir Next", "Helvetica Neue"] if font_size >= 30 else ["Avenir Next", "Helvetica Neue"])
	font.font_weight = 800 if font_size >= 19 else 500
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func button(value: String, callback: Callable, accent: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 42
	result.add_theme_font_size_override("font_size", 17)
	result.add_theme_color_override("font_color", INK)
	result.add_theme_color_override("font_hover_color", INK)
	result.add_theme_color_override("font_pressed_color", INK)
	result.add_theme_color_override("font_disabled_color", Color("91a3aa"))
	result.add_theme_stylebox_override("normal", box(Color("25e6f2") if accent else Color(1, 1, 1, 0.86), 12))
	result.add_theme_stylebox_override("hover", box(Color("83dce6") if accent else Color("d8e9ed"), 12))
	result.add_theme_stylebox_override("pressed", box(Color("58ccd9"), 12))
	result.add_theme_stylebox_override("disabled", box(Color("edf1f2"), 12))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var button_style := result.get_theme_stylebox(state) as StyleBoxFlat
		button_style.content_margin_top = 9
		button_style.content_margin_bottom = 9
	result.pressed.connect(callback)
	return result

func _place(node: Control, rect: Rect2, parent: Control = null) -> void:
	(parent if parent != null else design).add_child(node)
	node.position = rect.position
	node.size = rect.size

func _glass() -> StyleBoxFlat:
	var style := box(Color(0.98, 0.99, 1.0, 0.91), 22)
	style.border_color = Color(1, 1, 1, 0.9)
	style.set_border_width_all(1)
	style.shadow_color = Color(0.12, 0.25, 0.35, 0.13)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style

func _fit() -> void:
	if design == null: return
	var ratio := minf(size.x / 1280.0, size.y / 720.0)
	design.scale = Vector2.ONE * ratio
	design.position = (size - Vector2(1280, 720) * ratio) * 0.5

func _build() -> void:
	var background := TextureRect.new()
	background.texture = load("res://art/lobby/garden-lobby-backdrop.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.size = Vector2(1280, 720)
	add_child(design)
	resized.connect(_fit)
	_fit()
	var title := text_label("APPLE LEGENDS", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title, Rect2(320, 20, 640, 64))
	var subtitle := text_label("P R I V A T E   L O B B Y", 17)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(subtitle, Rect2(400, 81, 480, 28))
	for x in [280, 944]:
		var line := ColorRect.new()
		line.color = CYAN
		_place(line, Rect2(x, 55, 56, 2))
	connect_panel = PanelContainer.new()
	var connect_style := box(Color(1,1,1,0.94), 14)
	connect_style.content_margin_top = 6
	connect_style.content_margin_bottom = 6
	connect_panel.add_theme_stylebox_override("panel", connect_style)
	_place(connect_panel, Rect2(140, 111, 1000, 54))
	var connect_row := HBoxContainer.new()
	connect_row.add_theme_constant_override("separation", 10)
	connect_panel.add_child(connect_row)
	name_input = LineEdit.new()
	name_input.text = "Player"
	name_input.placeholder_text = "Player name"
	name_input.max_length = 20
	name_input.custom_minimum_size.x = 175
	_style_input(name_input)
	connect_row.add_child(name_input)
	address_input = LineEdit.new()
	address_input.placeholder_text = "Host IP address"
	address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(address_input)
	connect_row.add_child(address_input)
	host_button = button("Create party", _host, true)
	connect_row.add_child(host_button)
	join_button = button("Join party", _join)
	connect_row.add_child(join_button)
	_build_robot_stage()
	for team in range(2):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _glass())
		_place(panel, Rect2(35 if team == 0 else 867, 175, 378, 328))
		team_panels.append(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		panel.add_child(column)
		var title_row := HBoxContainer.new()
		column.add_child(title_row)
		var accent := ColorRect.new()
		accent.color = CYAN if team == 0 else AMBER
		accent.custom_minimum_size = Vector2(7, 30)
		title_row.add_child(accent)
		var team_title := text_label("CYAN TEAM" if team == 0 else "AMBER TEAM", 23)
		team_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(team_title)
		var count := text_label("0 / 3", 19, MUTED)
		title_row.add_child(count)
		team_counts.append(count)
		var slots := VBoxContainer.new()
		slots.add_theme_constant_override("separation", 8)
		slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(slots)
		roster_columns.append(slots)
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 6)
		column.add_child(controls)
		var choose := button("Join team", func(): _choose_team(team))
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose.custom_minimum_size.y = 30
		choose.add_theme_font_size_override("font_size", 13)
		controls.add_child(choose)
		team_buttons.append(choose)
		var add := button("+ Bot", func(): _add_bot(team))
		add.add_theme_font_size_override("font_size", 13)
		add.custom_minimum_size.y = 30
		controls.add_child(add)
		bot_add_buttons.append(add)
		var remove := button("− Bot", func(): _remove_bot(team))
		remove.add_theme_font_size_override("font_size", 13)
		remove.custom_minimum_size.y = 30
		controls.add_child(remove)
		bot_remove_buttons.append(remove)
	var map_card := PanelContainer.new()
	map_card.add_theme_stylebox_override("panel", _glass())
	_place(map_card, Rect2(360, 519, 560, 82))
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 18)
	map_card.add_child(map_row)
	var thumbnail := TextureRect.new()
	thumbnail.texture = background.texture
	thumbnail.custom_minimum_size = Vector2(228, 50)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_row.add_child(thumbnail)
	var map_text := VBoxContainer.new()
	map_row.add_child(map_text)
	map_text.add_child(text_label("GARDEN CIRCUIT", 22))
	map_text.add_child(text_label("KING OF THE HILL", 15, MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_place(actions, Rect2(290, 619, 700, 53))
	auto_fill = CheckButton.new()
	auto_fill.text = "Fill empty slots with bots"
	auto_fill.custom_minimum_size.x = 280
	auto_fill.add_theme_icon_override("checked", load("res://art/lobby/toggle-on.svg"))
	auto_fill.add_theme_icon_override("unchecked", load("res://art/lobby/toggle-off.svg"))
	auto_fill.add_theme_font_size_override("font_size", 15)
	auto_fill.add_theme_color_override("font_color", INK)
	auto_fill.add_theme_color_override("font_disabled_color", MUTED)
	auto_fill.add_theme_stylebox_override("disabled", _glass())
	auto_fill.add_theme_stylebox_override("normal", _glass())
	auto_fill.tooltip_text = "Host fills remaining seats when starting. Leave off for smaller matches."
	actions.add_child(auto_fill)
	fill_button = button("Fill 3v3", _fill)
	fill_button.visible = false
	design.add_child(fill_button)
	ready_button = button("Ready", _toggle_ready)
	actions.add_child(ready_button)
	start_button = button("▶  START MATCH", _start, true)
	start_button.add_theme_font_size_override("font_size", 23)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(start_button)
	room_label = text_label("Same Wi-Fi  •  Up to 3 per team", 12, MUTED)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(room_label, Rect2(245, 687, 790, 23))
	status_label = text_label("Create a private room or join your partner", 13, INK)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(status_label, Rect2(300, 601, 680, 20))
	leave_button = button("Leave party", _leave)
	leave_button.add_theme_font_size_override("font_size", 13)
	_place(leave_button, Rect2(35, 665, 140, 37))

func _build_robot_stage() -> void:
	# Illustrated lobby portrait matches the approved concept; combat uses MiniBot.
	hero_portrait = TextureRect.new()
	hero_portrait.texture = load("res://art/lobby/porcelain-robot-portrait.png")
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 accent_color : source_color = vec4(0.0, 0.82, 0.91, 1.0);
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float cyan = smoothstep(0.22, 0.48, min(pixel.g - pixel.r, pixel.b - pixel.r));
	pixel.rgb = mix(pixel.rgb, accent_color.rgb * max(pixel.g, pixel.b), cyan);
	COLOR = pixel;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	hero_portrait.material = material
	_place(hero_portrait, Rect2(455, 139, 370, 331))
	_tint_hero(1)

func _tint_hero(team: int) -> void:
	if is_instance_valid(hero_portrait):
		(hero_portrait.material as ShaderMaterial).set_shader_parameter("accent_color", CYAN if team == 1 else AMBER)

func _render_roster(members: Array) -> void:
	empty_buttons.clear()
	for team in range(2):
		for child in roster_columns[team].get_children(): child.free()
		var team_members: Array = members.filter(func(member): return int(member.get("team", 0)) == team + 1)
		team_counts[team].text = "%d / 3" % team_members.size()
		for slot in range(3):
			if slot >= team_members.size():
				var add := button("＋    Add bot", func(): _add_bot(team))
				add.custom_minimum_size.y = 62
				add.alignment = HORIZONTAL_ALIGNMENT_LEFT
				add.disabled = session == null or not session.connected or not session.is_host()
				roster_columns[team].add_child(add)
				empty_buttons.append(add)
				continue
			var member: Dictionary = team_members[slot]
			var local: bool = session != null and not member.get("bot", false) and int(member.peer_id) == session.local_peer_id()
			var row := PanelContainer.new()
			row.custom_minimum_size.y = 62
			var style := box(Color(0.88, 0.97, 1, 0.85) if local else Color(1,1,1,0.70), 14)
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			style.border_color = Color(0, 0.82, 0.92, 0.3) if local else Color(1,1,1,0.9)
			style.set_border_width_all(1)
			row.add_theme_stylebox_override("panel", style)
			roster_columns[team].add_child(row)
			var content := HBoxContainer.new()
			content.add_theme_constant_override("separation", 12)
			row.add_child(content)
			var icon: Control = load("res://scenes/lobby/robot_badge.gd").new()
			icon.set("accent", CYAN if team == 0 else AMBER)
			content.add_child(icon)
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.add_child(details)
			var name := text_label(str(member.get("name", "Player")), 19)
			name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			details.add_child(name)
			var tag := "BOT" if member.get("bot", false) else ("● READY" if member.get("ready", false) else "IN PARTY")
			if not member.get("bot", false) and int(member.peer_id) == 1:
				tag = "HOST  •  " + tag
			details.add_child(text_label(tag, 11, Color("13b64c") if member.get("ready", false) and not member.get("bot", false) else MUTED))
			if member.get("bot", false):
				var remove := button("×", func():
					if session != null: session.remove_bot(str(member.id)))
				remove.disabled = session == null or not session.is_host()
				content.add_child(remove)

func _style_input(input: LineEdit) -> void:
	var field := box(Color("eef4f6"), 10)
	field.content_margin_left = 12
	field.content_margin_right = 12
	field.content_margin_top = 8
	field.content_margin_bottom = 8
	input.add_theme_stylebox_override("normal", field)
	input.add_theme_stylebox_override("read_only", field)
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.add_theme_color_override("font_uneditable_color", MUTED)

# Session adapter is deliberately small; gameplay never depends on UI nodes.
func _bind_session() -> void:
	session.roster_changed.connect(_refresh)
	session.status_changed.connect(func(message: String): status_label.text = message)
	session.match_started.connect(func(_roster: Array): play_requested.emit())
	session.lobby_returned.connect(_refresh)
	_refresh()

func _refresh() -> void:
	local_ready = false
	var connected: bool = session.connected
	var hosting: bool = session.is_host()
	_render_roster(session.roster)
	status_label.text = session.status
	host_button.disabled = connected
	join_button.disabled = connected
	name_input.editable = not connected
	address_input.editable = not connected
	leave_button.disabled = not connected
	ready_button.disabled = not connected
	fill_button.disabled = not hosting or not connected
	auto_fill.disabled = not hosting or not connected
	connect_panel.visible = not connected
	for panel in team_panels: panel.position.y = 132 if connected else 175
	start_button.disabled = not hosting or not connected
	for team in range(2):
		team_buttons[team].disabled = not connected
		team_buttons[team].text = "Join team"
		var count := 0
		var has_bot := false
		for member: Dictionary in session.roster:
			if int(member.team) == team + 1:
				count += 1
				has_bot = has_bot or bool(member.bot)
			if int(member.peer_id) == session.local_peer_id() and not member.bot:
				local_ready = bool(member.ready)
				_tint_hero(int(member.team))
				if int(member.team) == team + 1:
					team_buttons[team].text = "Your team"
				else:
					team_buttons[team].text = "Join team"
		bot_add_buttons[team].disabled = not hosting or count >= 3
		bot_remove_buttons[team].disabled = not hosting or not has_bot
	ready_button.text = "Ready ✓" if local_ready else "Ready"
	if connected:
		var addresses: PackedStringArray = []
		for address in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				addresses.append(address)
		room_label.text = "HOST ADDRESS  " + (", ".join(addresses) if hosting else address_input.text) + "  •  " + str(session.get("BUILD_VERSION"))
	else:
		room_label.text = "Same Wi-Fi • create a party, then share your host address"

func _host() -> void:
	if session != null:
		session.host_lobby(name_input.text.strip_edges())
func _join() -> void:
	if session != null:
		session.join_lobby(address_input.text.strip_edges(), name_input.text.strip_edges())
func _choose_team(team: int) -> void:
	if session != null:
		session.choose_team(team + 1)
func _add_bot(team: int) -> void:
	if session != null:
		session.add_bot(team + 1)
func _remove_bot(team: int) -> void:
	if session == null:
		return
	for member: Dictionary in session.roster:
		if member.bot and int(member.team) == team + 1:
			session.remove_bot(str(member.id))
			return
func _fill() -> void:
	if session != null:
		session.fill_bots()
func _toggle_ready() -> void:
	if session != null:
		session.set_ready(not local_ready)
func _start() -> void:
	if session != null:
		if auto_fill.button_pressed and session.is_host():
			session.fill_bots()
		session.start_match()
func _leave() -> void:
	if session != null:
		session.leave_lobby()
