extends Node

@export var death_dialogue: DialogueResource = preload("res://dialogue/respawns.dialogue")
@export var death_dialogue_boss: DialogueResource = preload("res://dialogue/respawns.dialogue")
@export var death_start_node_normal := "respawn"
@export var death_start_node_boss := "boss"

var respawn_position: Vector2 = Vector2.ZERO

# Track what kind of death happened
var last_death_was_boss := false
var in_boss_room := false  # set true when entering boss room, false when leaving/resetting

var current_room: Node = null
var current_room_id: StringName = &""

var completed_rooms := {} # room_id → true

func set_respawn(pos: Vector2) -> void:
	respawn_position = pos

func enter_room(room: Node, room_id: StringName) -> void:
	current_room = room
	current_room_id = room_id

func leave_room(room: Node) -> void:
	if current_room == room:
		current_room = null
		current_room_id = &""

func mark_room_completed(room_id: StringName) -> void:
	completed_rooms[room_id] = true

func is_room_completed(room_id: StringName) -> bool:
	return completed_rooms.has(room_id)

func set_last_death_boss(value: bool) -> void:
	last_death_was_boss = value
func _get_fader() -> Node:
	return get_tree().get_first_node_in_group("screen_fader")
func respawn_player(player: Node) -> void:
	# Freeze player control while we do the sequence
	if "player_can_move" in State:
		State.player_can_move = false

	var fader := _get_fader()
	if fader and fader.has_method("fade_out"):
		await fader.fade_out(0.45)

	# ----------------------------
	# While screen is black: RESET
	# ----------------------------

	# Reset room if not completed
	if is_instance_valid(current_room) and current_room_id != &"":
		if not is_room_completed(current_room_id):
			if current_room.has_method("reset_room"):
				current_room.reset_room()

	# Hide boss UI globally (safe even if not in boss room)
	var boss_ui := get_tree().get_first_node_in_group("boss_ui")
	if boss_ui:
		if boss_ui.has_method("hide_boss"):
			boss_ui.hide_boss()
		elif boss_ui is CanvasItem:
			(boss_ui as CanvasItem).visible = false

	# Re-open all arena gates
	for g in get_tree().get_nodes_in_group("arena_gate"):
		if is_instance_valid(g) and g.has_method("open_gate"):
			g.open_gate()

	# Teleport player
	if player is Node2D:
		var p := player as Node2D
		p.global_position = respawn_position

		# Unlock camera AFTER teleport
		var cam := p.find_child("Camera2D", true, false)
		if cam and cam.has_method("unlock_room"):
			cam.unlock_room()

		# Optional snap
		if cam and cam is Camera2D:
			(cam as Camera2D).global_position = p.global_position

	# Reset anything that wants reset_on_respawn()
	for n in get_tree().get_nodes_in_group("respawn_reset"):
		if is_instance_valid(n) and n.has_method("reset_on_respawn"):
			n.reset_on_respawn()

	# Boss should not move until you re-enter / re-trigger
	if "boss_can_move" in State:
		State.boss_can_move = false

	# Let player restore collision/health/etc
	if player and player.has_method("on_respawned"):
		player.on_respawned()

	# ----------------------------
	# Fade back in, THEN dialogue
	# ----------------------------
	if fader and fader.has_method("fade_in"):
		await fader.fade_in(0.45)

	# Now allow player input again (after fade-in feels best)
	if "player_can_move" in State:
		State.player_can_move = true

	# Death dialogue after respawn
	if last_death_was_boss:
		if death_dialogue_boss:
			DialogueManager.show_dialogue_balloon(death_dialogue_boss, death_start_node_boss)
	else:
		if death_dialogue:
			DialogueManager.show_dialogue_balloon(death_dialogue, death_start_node_normal)

	last_death_was_boss = false
