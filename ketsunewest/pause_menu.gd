extends CanvasLayer

@export var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var panel: Control = $Panel
@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeButton
@onready var exit_btn: Button = $Panel/VBoxContainer/ExitButton

var _is_open := false

func _ready() -> void:
	visible = false
	panel.visible = true

	# Connect buttons
	if is_instance_valid(resume_btn):
		resume_btn.pressed.connect(_on_resume_pressed)
	else:
		push_error("PauseMenu: ResumeButton not found at $Panel/VBoxContainer/ResumeButton")

	if is_instance_valid(exit_btn):
		exit_btn.pressed.connect(_on_exit_pressed)
	else:
		push_error("PauseMenu: ExitButton not found at $Panel/VBoxContainer/ExitButton")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		# Block pause while dialogue active
		if _dialogue_is_active():
			return

		# Block pause if inventory is open
		var inv := get_tree().get_first_node_in_group("inventory_menu")
		if inv and inv.has_method("is_open") and inv.is_open():
			return

		# Toggle pause menu
		if _is_open:
			close_menu()
		else:
			open_menu()

func is_open() -> bool:
	return _is_open

func open_menu() -> void:
	_is_open = true
	visible = true
	panel.visible = true

	get_tree().paused = true

	# focus resume for keyboard/controller
	if is_instance_valid(resume_btn):
		resume_btn.grab_focus()

func close_menu() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false

func _on_resume_pressed() -> void:
	close_menu()

func _on_exit_pressed() -> void:
	# Unpause BEFORE changing scenes
	get_tree().paused = false
	_is_open = false
	visible = false
	get_tree().change_scene_to_file(main_menu_scene)

func _dialogue_is_active() -> bool:
	# If you lock player movement during dialogue/cutscenes
	if "player_can_move" in State and State.player_can_move == false:
		return true

	# Optional: if DialogueManager exposes a method (depends on your setup)
	if Engine.has_singleton("DialogueManager"):
		var dm = Engine.get_singleton("DialogueManager")
		if dm and dm.has_method("is_dialogue_active"):
			return dm.is_dialogue_active()

	return false
