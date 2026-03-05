extends Node


var current_room: Node = null

func set_active_room(room):
	print("Switching to room:", room.name)
	if current_room == room:
		return

	if current_room:
		current_room.fade_out()

	current_room = room
	current_room.fade_in()
