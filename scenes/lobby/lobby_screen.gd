extends Control
## Private LAN lobby; the session owns membership and match rules.
signal play_requested
const INK := Color("193743")
const MUTED := Color("637e88")
const CYAN := Color("25b9cf")
const AMBER := Color("e5ab50")
var session: Node
var hero_robot: Node3D
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
	result.add_theme_stylebox_override("normal", box(Color("a8e7ec") if accent else Color("e9f0f2"), 12))
	result.add_theme_stylebox_override("hover", box(Color("83dce6") if accent else Color("d8e9ed"), 12))
	result.add_theme_stylebox_override("pressed", box(Color("58ccd9"), 12))
	result.add_theme_stylebox_override("disabled", box(Color("edf1f2"), 12))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var button_style := result.get_theme_stylebox(state) as StyleBoxFlat
		button_style.content_margin_top = 9
		button_style.content_margin_bottom = 9
	result.pressed.connect(callback)
	return result

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("e8f0f2")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 38)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(text_label("A L  /  APPLE LEGENDS", 15, MUTED))
	identity.add_child(text_label("Your party. Your teams.", 34))
	var badge := text_label("GARDEN CIRCUIT\nPRIVATE LAN  •  UP TO 3v3", 15, MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(badge)
	var connect_panel := PanelContainer.new()
	connect_panel.add_theme_stylebox_override("panel", box(Color("ffffff")))
	layout.add_child(connect_panel)
	var connect_row := HBoxContainer.new()
	connect_row.add_theme_constant_override("separation", 12)
	connect_panel.add_child(connect_row)
	var name_stack := VBoxContainer.new()
	connect_row.add_child(name_stack)
	name_stack.add_child(text_label("PLAYER NAME", 12, MUTED))
	name_input = LineEdit.new()
	name_input.text = "Player"
	name_input.max_length = 20
	name_input.custom_minimum_size = Vector2(180, 42)
	name_stack.add_child(name_input)
	_style_input(name_input)
	var address_stack := VBoxContainer.new()
	address_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_row.add_child(address_stack)
	address_stack.add_child(text_label("HOST ADDRESS", 12, MUTED))
	address_input = LineEdit.new()
	address_input.placeholder_text = "192.168.1.20"
	address_input.custom_minimum_size.y = 42
	address_stack.add_child(address_input)
	_style_input(address_input)
	host_button = button("Create party", _host, true)
	host_button.size_flags_vertical = Control.SIZE_SHRINK_END
	connect_row.add_child(host_button)
	join_button = button("Join party", _join)
	join_button.size_flags_vertical = Control.SIZE_SHRINK_END
	connect_row.add_child(join_button)
	room_label = text_label("Same Wi-Fi • create a party, then share your host address", 14, MUTED)
	layout.add_child(room_label)
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 20)
	teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(teams)
	for team in range(2):
		if team == 1:
			_build_robot_stage(teams)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", box(Color("fcfefe")))
		teams.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		var title_row := HBoxContainer.new()
		column.add_child(title_row)
		var title := text_label("01  /  CYAN" if team == 0 else "02  /  AMBER", 22, CYAN if team == 0 else AMBER)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var choose := button("Join team", func(): _choose_team(team))
		title_row.add_child(choose)
		team_buttons.append(choose)
		var slots := VBoxContainer.new()
		slots.add_theme_constant_override("separation", 8)
		slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(slots)
		roster_columns.append(slots)
		var bots := HBoxContainer.new()
		bots.add_theme_constant_override("separation", 8)
		column.add_child(bots)
		var add := button("+ Add bot", func(): _add_bot(team))
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bots.add_child(add)
		bot_add_buttons.append(add)
		var remove := button("− Remove bot", func(): _remove_bot(team))
		remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bots.add_child(remove)
		bot_remove_buttons.append(remove)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	layout.add_child(bottom)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info)
	status_label = text_label("Create or join a party to begin", 17)
	info.add_child(status_label)
	info.add_child(text_label("1v1, 2v2 or 3v3 • humans and bots • empty slots are allowed", 13, MUTED))
	fill_button = button("Fill to 3v3", _fill)
	bottom.add_child(fill_button)
	ready_button = button("Ready", _toggle_ready)
	bottom.add_child(ready_button)
	start_button = button("Launch match  →", _start, true)
	bottom.add_child(start_button)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	leave_button = button("Leave party", _leave)
	footer.add_child(leave_button)
	var footer_text := text_label("PORCELAIN SHELLS. GARDEN SKIRMISHES.\nMatching game versions required • host controls bots and launch", 12, MUTED)
	footer_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(footer_text)

func _build_robot_stage(parent: HBoxContainer) -> void:
	var stage := VBoxContainer.new()
	stage.custom_minimum_size.x = 180
	stage.add_theme_constant_override("separation", 10)
	parent.add_child(stage)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(spacer)
	var portrait := SubViewportContainer.new()
	portrait.custom_minimum_size = Vector2(180, 210)
	portrait.stretch = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(180, 210)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	portrait.add_child(viewport)
	var robot: Node3D = preload("res://art/calibration/MiniBot.glb").instantiate()
	robot.rotation.y = PI - 0.18
	viewport.add_child(robot)
	hero_robot = robot
	_tint_hero(1)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color(0, 0, 0, 0)
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("eaf7ff")
	world.ambient_light_energy = 0.65
	environment.environment = world
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.6
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.position = Vector3(0.5, 1.25, -4.0)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	var title := text_label("GARDEN CIRCUIT", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(title)
	var subtitle := text_label("KING OF THE HILL
Private party", 12, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(subtitle)
	var bottom_space := Control.new()
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(bottom_space)

func _tint_hero(team: int) -> void:
	if not is_instance_valid(hero_robot):
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = CYAN if team == 1 else AMBER
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.4
	for part in ["Eye", "Eye_001", "ChestIndicator", "BotWeaponPower"]:
		var mesh := hero_robot.find_child(part, true, false) as MeshInstance3D
		if mesh != null:
			mesh.material_override = material

func _render_roster(members: Array) -> void:
	for team in range(2):
		for child in roster_columns[team].get_children():
			child.free()
		var team_members: Array = members.filter(func(member): return int(member.get("team", 0)) == team + 1)
		for slot in range(3):
			var occupied := slot < team_members.size()
			var row := PanelContainer.new()
			row.custom_minimum_size.y = 61
			var slot_style := box(Color("eef7f8") if team == 0 else Color("faf5e9"), 14)
			slot_style.content_margin_top = 8
			slot_style.content_margin_bottom = 8
			row.add_theme_stylebox_override("panel", slot_style)
			roster_columns[team].add_child(row)
			var content := HBoxContainer.new()
			content.add_theme_constant_override("separation", 16)
			row.add_child(content)
			var icon: Control
			if occupied:
				icon = load("res://scenes/lobby/robot_badge.gd").new()
				icon.set("accent", CYAN if team == 0 else AMBER)
			else:
				icon = text_label("+", 26, CYAN if team == 0 else AMBER)
			content.add_child(icon)
			var name := text_label("Open slot", 18, MUTED)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			content.add_child(name)
			var tag := text_label("OPTIONAL", 12, MUTED)
			content.add_child(tag)
			if occupied:
				var member: Dictionary = team_members[slot]
				name.text = str(member.get("name", "Player"))
				name.add_theme_color_override("font_color", INK)
				tag.text = "BOT" if member.get("bot", false) else ("READY" if member.get("ready", false) else "IN PARTY")

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
		session.start_match()
func _leave() -> void:
	if session != null:
		session.leave_lobby()
