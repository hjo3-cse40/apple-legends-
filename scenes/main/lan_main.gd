extends Node
var lobby: Control
var arena: Node
func _ready() -> void:
	LanSession.match_started.connect(_start)
	LanSession.lobby_returned.connect(_show_lobby)
	_show_lobby()
func _show_lobby() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(arena):
		arena.queue_free()
		arena = null
	if not is_instance_valid(lobby):
		lobby = preload("res://scenes/lobby/lobby_screen.tscn").instantiate()
		add_child(lobby)
	lobby.show()
func _start(_roster: Array) -> void:
	if is_instance_valid(lobby):
		lobby.hide()
	arena = preload("res://scenes/levels/garden/lan_garden.tscn").instantiate()
	arena.name = "MovementLab"
	add_child(arena)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
