class_name PlayerInputBindings
extends RefCounted
## Device-local bindings. Gameplay still samples Godot actions, so LAN intent is unchanged.
const SAVE_PATH := "user://bindings.cfg"
static var save_path := SAVE_PATH
const ACTIONS := [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"fire", &"aim", &"reload"]
const TITLES := ["Forward", "Back", "Left", "Right", "Jump", "Sprint", "Fire", "Aim", "Reload"]

static func defaults(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var configured: Dictionary = ProjectSettings.get_setting("input/" + str(action), {})
	for event in configured.get("events", []):
		result.append(event.duplicate())
	if action == &"jump":
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		result.append(wheel)
	return result

static func load_saved() -> void:
	var config := ConfigFile.new()
	config.load(save_path)
	for action in ACTIONS:
		var events := defaults(action)
		if config.has_section_key("bindings", str(action)):
			var decoded: Array[InputEvent] = []
			for data in config.get_value("bindings", str(action), []):
				if data is Dictionary:
					var event := decode(data)
					if event != null and allowed(action, event): decoded.append(event)
			if not decoded.is_empty(): events = decoded
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event in events: InputMap.action_add_event(action, event)

static func allowed(action: StringName, event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.physical_keycode != 0 and event.physical_keycode not in [KEY_ESCAPE, KEY_F1, KEY_ENTER] and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed)
	if event is InputEventMouseButton:
		return event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] or (action == &"jump" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN])
	return false

static func decode(data: Dictionary) -> InputEvent:
	if data.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = int(data.key)
		return key
	if data.has("mouse"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(data.mouse)
		return mouse
	return null

static func binding_label(event: InputEvent) -> String:
	if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode)
	if event is InputEventMouseButton:
		return {1: "Mouse left", 2: "Mouse right", 3: "Mouse middle", 4: "Wheel up", 5: "Wheel down"}.get(event.button_index, "Mouse")
	return "—"

static func set_slot(action: StringName, slot: int, event: InputEvent) -> String:
	if not allowed(action, event): return "Esc cancels. F1 and Enter are reserved; wheel is for Jump."
	for other in ACTIONS:
		for existing in InputMap.action_get_events(other):
			if existing.is_match(event):
				if other == action: return "Already assigned to " + str(action).replace("_", " ") + "."
				return "Already assigned to " + str(other).replace("_", " ") + ". Rebind that action first."
	var events := InputMap.action_get_events(action)
	if slot < events.size(): events[slot] = event
	else: events.append(event)
	Input.action_release(action)
	InputMap.action_erase_events(action)
	for binding in events: InputMap.action_add_event(action, binding)
	save()
	return ""

static func save() -> void:
	var config := ConfigFile.new()
	for action in ACTIONS:
		var events: Array[Dictionary] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: events.append({"key": event.physical_keycode})
			elif event is InputEventMouseButton: events.append({"mouse": event.button_index})
		config.set_value("bindings", str(action), events)
	var error := config.save(save_path)
	if error != OK: push_warning("Unable to save bindings: " + str(error))

static func reset() -> void:
	for action in ACTIONS:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event in defaults(action): InputMap.action_add_event(action, event)
	save()
