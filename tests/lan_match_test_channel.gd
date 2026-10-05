extends Node
signal command_received(command: String, arguments: Dictionary)
signal acknowledgement_received(command: String, result: Dictionary)
@rpc("authority", "call_remote", "reliable")
func command(command_name: String, arguments: Dictionary) -> void:
	command_received.emit(command_name, arguments)
@rpc("any_peer", "call_remote", "reliable")
func acknowledge(command_name: String, result: Dictionary) -> void:
	if multiplayer.is_server():
		acknowledgement_received.emit(command_name, result)
